// lib/features/auth/providers/auth_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/session_service.dart';
import '../../../config/api_endpoints.dart';
import '../../../core/services/fcm_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated, pending, rejected }

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();

  AuthStatus _status = AuthStatus.unknown;
  AuthStatus get status => _status;

  String? _partnerId;
  String? get partnerId => _partnerId;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool get isLocationTracking => _locationService.isTracking;

  // ── In-memory login credentials for OTP resend (Option A) ────────────────
  // Stored only in RAM — never persisted to disk.
  String? _loginEmail;
  String? _loginPassword;

  // ─── Session force-logout listener ────────────────────────────────────────
  StreamSubscription<void>? _forceLogoutSub;

  // ─── INITIALIZE ───────────────────────────────────────────────────────────

  Future<void> initialize() async {
    final auth = await StorageService.getAuthData();

    _partnerId = auth.partnerId;

    if (auth.token == null || auth.status == null) {
      _status = AuthStatus.unauthenticated;
    } else {
      switch (auth.status) {
        case 'approved':
          _status = AuthStatus.authenticated;
          _startLocationTracking();
          break;
        case 'pending':
          _status = AuthStatus.pending;
          break;
        case 'rejected':
          _status = AuthStatus.rejected;
          break;
        default:
          _status = AuthStatus.unauthenticated;
      }
    }

    // Listen for global 401 / 403-account-gone force-logout signal from
    // ApiService interceptor.
    _forceLogoutSub?.cancel();
    _forceLogoutSub = SessionService.instance.forceLogout.listen((_) async {
      debugPrint('🔐 Force logout triggered by session service');
      await logout();
    });

    notifyListeners();
  }

  // ─── CHECK ACCOUNT STATUS ─────────────────────────────────────────────────
  //
  // Called on app cold-start (SplashScreen) AND on every app-resume
  // (MainShell's WidgetsBindingObserver).

  Future<void> checkAccountStatus() async {
    try {
      _isLoading = true;
      notifyListeners();

      _partnerId ??= StorageService.getPartnerId();

      if (_partnerId == null) {
        debugPrint('❌ No partnerId found');
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      debugPrint('🔄 Checking account status for: $_partnerId');

      final response = await _apiService.dio.post(
        ApiEndpoints.checkStatus,
        data: {'partnerId': _partnerId},
      );

      final partner = response.data['partner'];
      if (partner != null) {
        final backendStatus = partner['status'] as String;
        debugPrint('✅ Backend status: $backendStatus');

        if (backendStatus == 'deleted' || backendStatus == 'deactivated') {
          debugPrint('🔐 Account deleted/deactivated on backend — forcing logout');
          await _forceLogoutDeleted();
          return;
        }

        await StorageService.savePartnerStatus(backendStatus);

        switch (backendStatus) {
          case 'approved':
            _status = AuthStatus.authenticated;
            break;
          case 'pending':
            _status = AuthStatus.pending;
            break;
          case 'rejected':
            _status = AuthStatus.rejected;
            break;
          default:
            _status = AuthStatus.unauthenticated;
        }
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;

      if (statusCode == 404 || statusCode == 403) {
        debugPrint(
          '🔐 checkAccountStatus: $statusCode — account not found / forbidden. Forcing logout.',
        );
        await _forceLogoutDeleted();
        return;
      }

      debugPrint('⚠️ checkAccountStatus error (non-fatal): ${e.type} ${e.message}');
    } catch (e) {
      debugPrint('⚠️ checkAccountStatus unexpected error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── FORCE LOGOUT (deleted account) ──────────────────────────────────────

  Future<void> _forceLogoutDeleted() async {
    await _stopLocationTracking();
    await FCMService.instance.clearToken(sessionToken: await StorageService.getToken() ?? '');
    await StorageService.clearAuthKeys();
    _status = AuthStatus.unauthenticated;
    _partnerId = null;
    _loginEmail = null;
    _loginPassword = null;
    _isLoading = false;
    notifyListeners();
    SessionService.instance.triggerForceLogout();
  }

  // ─── LOGIN (REQUEST OTP) ──────────────────────────────────────────────────

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      debugPrint('🔐 Attempting login for: $email');

      final response = await _apiService.dio.post(
        ApiEndpoints.loginOtp,
        data: {'email': email, 'password': password},
      );

      debugPrint('✅ Login response: ${response.data}');

      // ── Store credentials in-memory for OTP resend (Option A) ────────────
      // Only held in RAM — cleared on logout or force-logout.
      _loginEmail = email;
      _loginPassword = password;

      _partnerId = response.data['partnerId'];
      await StorageService.savePartnerId(_partnerId!);

      final partnerStatus = response.data['status'] as String?;
      if (partnerStatus != null) {
        await StorageService.savePartnerStatus(partnerStatus);
        if (partnerStatus == 'pending') {
          _status = AuthStatus.pending;
          notifyListeners();
          return 'PENDING';
        } else if (partnerStatus == 'rejected') {
          _status = AuthStatus.rejected;
          notifyListeners();
          return 'REJECTED';
        }
      }

      debugPrint('✅ Login successful, OTP sent');
      return null;
    } catch (e) {
      debugPrint('❌ Login Error: $e');
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        final errorMessage = e.response?.data['error'] as String?;
        if (statusCode == 404) return 'Account not found';
        if (statusCode == 403) return errorMessage ?? 'Invalid password';
      }
      return 'Login failed. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── RESEND OTP ───────────────────────────────────────────────────────────
  //
  // FIX: The original code called loginOtp with only partnerId, but that
  // endpoint requires email + password. We now re-send the full credentials
  // that were captured in-memory during login().
  //
  // If a dedicated /auth/resend-otp endpoint becomes available on the backend,
  // switch to ApiEndpoints.resendOtp and send only partnerId (Option B).

  Future<String?> resendOtp() async {
    try {
      _isLoading = true;
      notifyListeners();

      if (_partnerId == null) {
        return 'Session expired. Please login again.';
      }

      if (_loginEmail == null || _loginPassword == null) {
        // Credentials were cleared — guard against edge cases.
        return 'Session expired. Please login again.';
      }

      debugPrint('🔄 Resending OTP for partner: $_partnerId');

      // Option A: re-post full login credentials to get a fresh OTP.
      await _apiService.dio.post(
        ApiEndpoints.loginOtp,
        data: {
          'email': _loginEmail,
          'password': _loginPassword,
        },
      );

      debugPrint('✅ OTP resent successfully');
      return null;
    } catch (e) {
      debugPrint('❌ Resend OTP error: $e');
      if (e is DioException) {
        return e.response?.data['error'] ?? 'Failed to resend OTP';
      }
      return 'Failed to resend OTP. Try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── VERIFY OTP ───────────────────────────────────────────────────────────

  Future<String?> verifyOtp({required String otp}) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _apiService.dio.post(
        ApiEndpoints.verifyOtp,
        data: {'partnerId': _partnerId, 'otp': otp},
      );

      final token = response.data['token'];
      final partner = response.data['partner'];

      if (token == null) return 'No token received from server';

      // ✅ Save auth token first — FCMService.sendTokenAfterLogin() needs it.
      await StorageService.saveToken(token);

      if (partner != null) {
        final backendStatus = partner['status'] as String;
        await StorageService.savePartnerStatus(backendStatus);
        await StorageService.saveUser(partner);

        switch (backendStatus) {
          case 'approved':
            _status = AuthStatus.authenticated;
            _startLocationTracking();
            unawaited(FCMService.instance.sendTokenAfterLogin());
            break;
          case 'pending':
            _status = AuthStatus.pending;
            break;
          case 'rejected':
            _status = AuthStatus.rejected;
            break;
          default:
            _status = AuthStatus.unauthenticated;
        }
      } else {
        await StorageService.savePartnerStatus('approved');
        _status = AuthStatus.authenticated;
        _startLocationTracking();
        unawaited(FCMService.instance.sendTokenAfterLogin());
      }

      // Clear in-memory credentials after successful login — no longer needed.
      _loginEmail = null;
      _loginPassword = null;

      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('❌ OTP Verification Error: $e');
      if (e is DioException) {
        return e.response?.data['error'] ?? 'Invalid or expired OTP';
      }
      return 'Invalid or expired OTP';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── FORGOT PASSWORD ──────────────────────────────────────────────────────

  Future<String?> forgotPassword({required String email}) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _apiService.dio.post(
        ApiEndpoints.forgotPassword,
        data: {'email': email},
      );

      return null;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404) return 'No account found with that email';
      return e.response?.data['error'] ?? 'Failed to send reset email';
    } catch (_) {
      return 'Something went wrong. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── LOGOUT ───────────────────────────────────────────────────────────────

  Future<void> logout() async {
    final sessionToken = await StorageService.getToken();
    await _stopLocationTracking();
    await FCMService.instance.clearToken(sessionToken: sessionToken ?? '');
    await StorageService.clearAuthKeys();
    _status = AuthStatus.unauthenticated;
    _partnerId = null;
    _loginEmail = null;
    _loginPassword = null;
    notifyListeners();
  }

  // ─── REGISTER ─────────────────────────────────────────────────────────────

  Future<String?> register({
    required String name,
    required String email,
    required String phone,
    required String adminEmail,
    required String password,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _apiService.dio.post(
        ApiEndpoints.register,
        data: {
          'name': name,
          'email': email,
          'phone': phone,
          'adminEmail': adminEmail,
          'password': password,
        },
      );

      _partnerId = response.data['partnerId'];
      await StorageService.savePartnerId(_partnerId!);
      await StorageService.savePartnerStatus('pending');

      _status = AuthStatus.pending;
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('❌ Registration Error: $e');
      return 'Registration failed. Please check details.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── LOCATION TRACKING ────────────────────────────────────────────────────

  void _startLocationTracking() {
    _locationService.startTracking().then((started) {
      debugPrint(
        started
            ? '✅ Location tracking started'
            : '❌ Location tracking failed to start',
      );
      notifyListeners();
    }).catchError((e) {
      debugPrint('❌ Error starting location tracking: $e');
    });
  }

  Future<void> _stopLocationTracking() async {
    try {
      await _locationService.stopTracking();
      debugPrint('✅ Location tracking stopped');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error stopping location tracking: $e');
    }
  }

  Future<void> toggleLocationTracking() async {
    if (_locationService.isTracking) {
      await _stopLocationTracking();
    } else {
      _startLocationTracking();
    }
  }

  // ─── DISPOSE ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _forceLogoutSub?.cancel();
    super.dispose();
  }
}