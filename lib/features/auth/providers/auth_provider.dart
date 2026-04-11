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
  // ApiService is a singleton — just call the factory constructor.
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
    // Single batched async call — token is in secure storage (async),
    // status and partnerId are in cached SharedPreferences (sync inside).
    final auth = await StorageService.getAuthData();

    _partnerId = auth.partnerId;

    if (auth.token == null || auth.status == null) {
      _status = AuthStatus.unauthenticated;
    } else {
      switch (auth.status) {
        case 'approved':
          _status = AuthStatus.authenticated;
          // Start location silently — no UI needed here; tracking starts
          // in the background. Permission dialogs are handled in OtpScreen.
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

    // Listen for global 401 force-logout signal from ApiService interceptor.
    _forceLogoutSub?.cancel();
    _forceLogoutSub = SessionService.instance.forceLogout.listen((_) async {
      debugPrint('🔐 Force logout triggered by 401');
      await logout();
    });

    notifyListeners();
  }

  // ─── CHECK ACCOUNT STATUS ─────────────────────────────────────────────────

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
    } catch (e) {
      debugPrint('❌ Error checking account status: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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

  /// Re-triggers an OTP send using the stored partnerId.
  /// Returns null on success, or an error string on failure.
  Future<String?> resendOtp() async {
    try {
      _isLoading = true;
      notifyListeners();

      if (_partnerId == null) {
        return 'Session expired. Please login again.';
      }

      debugPrint('🔄 Resending OTP for partner: $_partnerId');

      // Re-call the same OTP endpoint the backend uses to dispatch a new OTP.
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

      await StorageService.saveToken(token);

      if (partner != null) {
        final backendStatus = partner['status'] as String;
        await StorageService.savePartnerStatus(backendStatus);
        await StorageService.saveUser(partner);

        switch (backendStatus) {
          case 'approved':
            _status = AuthStatus.authenticated;
            _startLocationTracking();
            // Register FCM token now that we have an authenticated partner.
            // unawaited so it doesn't block the login completion.
            unawaited(FCMService.instance.init());
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
            unawaited(FCMService.instance.init());
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
    final sessionToken = await StorageService.getToken();
    await _stopLocationTracking();
    // Clear FCM token from backend so no more push notifications are sent
    // to this device after logout. Fire-and-forget — non-blocking.
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
  // These are fire-and-forget — permission dialogs must be shown by the UI
  // layer (OtpScreen / SplashScreen) before tracking is started.

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