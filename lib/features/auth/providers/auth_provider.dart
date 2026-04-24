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
  //
  // FIX: Previously the catch block only printed errors.
  //   • 404 → partner record no longer exists → force logout
  //   • 403 → partner forbidden / account flagged → force logout
  //   • backend status == 'deleted' → force logout
  //   All three now call _forceLogoutDeleted() which clears storage,
  //   stops tracking, and fires the SessionService event so MainShell
  //   navigates the user to the welcome screen.

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

        // A backend-side deletion may surface as status == 'deleted' rather
        // than a 404 if the record is soft-deleted.
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

      // ── FIX: 404 = partner record gone; 403 = account-level block ─────────
      // Both mean the user should no longer have app access.
      if (statusCode == 404 || statusCode == 403) {
        debugPrint(
          '🔐 checkAccountStatus: $statusCode — account not found / forbidden. Forcing logout.',
        );
        await _forceLogoutDeleted();
        return;
      }

      // Any other network error (timeout, no internet) → don't logout;
      // the user may just be offline.
      debugPrint('⚠️ checkAccountStatus error (non-fatal): ${e.type} ${e.message}');
    } catch (e) {
      debugPrint('⚠️ checkAccountStatus unexpected error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── FORCE LOGOUT (deleted account) ──────────────────────────────────────
  //
  // Shared helper used by checkAccountStatus() and potentially any future
  // place that detects a non-recoverable account state.
  // Fires SessionService so MainShell's listener triggers navigation.

  Future<void> _forceLogoutDeleted() async {
    await _stopLocationTracking();
    await FCMService.instance.clearToken(sessionToken: await StorageService.getToken() ?? '');
    await StorageService.clearAuthKeys();
    _status = AuthStatus.unauthenticated;
    _partnerId = null;
    _isLoading = false;
    notifyListeners();
    // Fires the stream → MainShell listener → navigates to /welcome
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

  Future<String?> resendOtp() async {
    try {
      _isLoading = true;
      notifyListeners();

      if (_partnerId == null) {
        return 'Session expired. Please login again.';
      }

      debugPrint('🔄 Resending OTP for partner: $_partnerId');

      await _apiService.dio.post(
        ApiEndpoints.loginOtp,
        data: {'partnerId': _partnerId},
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

  // ─── LOGOUT ───────────────────────────────────────────────────────────────

  Future<void> logout() async {
    // Capture the token BEFORE clearing storage — clearToken() needs it.
    final sessionToken = await StorageService.getToken();
    await _stopLocationTracking();
    // Clear FCM token on backend so no more pushes arrive after logout.
    await FCMService.instance.clearToken(sessionToken: sessionToken ?? '');
    await StorageService.clearAuthKeys();
    _status = AuthStatus.unauthenticated;
    _partnerId = null;
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