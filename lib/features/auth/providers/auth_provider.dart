// lib/features/auth/providers/auth_provider.dart

import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/permission_helper.dart';
import '../../../config/api_endpoints.dart';

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

  BuildContext? _context;

  // ✅ Set context for permission dialogs
  void setContext(BuildContext context) {
    _context = context;
  }

  // 🔁 Called on app launch (Splash)
  Future<void> initialize() async {
    final token = await StorageService.getToken();
    final status = await StorageService.getPartnerStatus();
    _partnerId = await StorageService.getPartnerId();

    if (token == null || status == null) {
      _status = AuthStatus.unauthenticated;
    } else {
      switch (status) {
        case 'approved':
          _status = AuthStatus.authenticated;
          await _startLocationTracking();
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

    notifyListeners();
  }

  // 🔐 LOGIN (REQUEST OTP)
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _apiService.dio.post(
        ApiEndpoints.loginOtp,
        data: {'email': email, 'password': password},
      );

      _partnerId = response.data['partnerId'];
      await StorageService.savePartnerId(_partnerId!);

      return null;
    } catch (e) {
      return 'Invalid credentials or account not approved';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 🔑 VERIFY OTP (FINAL LOGIN)
  Future<String?> verifyOtp({required String otp}) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _apiService.dio.post(
        ApiEndpoints.verifyOtp,
        data: {
          'partnerId': _partnerId,
          'otp': otp,
        },
      );

      final token = response.data['token'];
      final partner = response.data['partner'];

      await StorageService.saveToken(token);
      await StorageService.savePartnerStatus('approved');

      if (partner != null) {
        await StorageService.saveUser(partner);
        debugPrint('✅ User data saved: $partner');
      } else {
        debugPrint('⚠️ No partner data in response');
      }

      _status = AuthStatus.authenticated;

      await _startLocationTracking();

      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('❌ OTP Verification Error: $e');
      return 'Invalid or expired OTP';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 🚪 LOGOUT
  Future<void> logout() async {
    await _stopLocationTracking();
    await StorageService.clearAll();
    _status = AuthStatus.unauthenticated;
    _partnerId = null;
    notifyListeners();
  }

  // 📝 REGISTER
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
      return 'Registration failed. Please check details.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ========= LOCATION TRACKING =========

  /// Start location tracking with proper permission handling
  Future<void> _startLocationTracking() async {
    try {
      debugPrint('🎯 Attempting to start location tracking...');

      // Check GPS first
      if (!await _locationService.isGpsEnabled()) {
        debugPrint('⚠️ GPS is disabled');
        if (_context != null && _context!.mounted) {
          final shouldOpen = await PermissionHelper.showGpsDisabledDialog(_context!);
          if (shouldOpen) {
            await _locationService.openLocationSettings();
          }
        }
        return;
      }

      // Check if we have "Always Allow" permission
      if (!await _locationService.hasAlwaysPermission()) {
        debugPrint('⚠️ Need "Always Allow" permission');
        
        // Show explanation dialog
        if (_context != null && _context!.mounted) {
          final userAgreed = await PermissionHelper.showLocationPermissionDialog(_context!);
          if (!userAgreed) {
            debugPrint('❌ User declined permission request');
            return;
          }
        }

        // Request permission
        final granted = await _locationService.requestAlwaysPermission();
        
        if (!granted) {
          debugPrint('❌ Permission denied');
          if (_context != null && _context!.mounted) {
            await PermissionHelper.showPermissionDeniedDialog(_context!);
          }
          return;
        }
      }

      // Start tracking
      final started = await _locationService.startTracking();
      
      if (started) {
        debugPrint('✅ Location tracking started successfully');
      } else {
        debugPrint('❌ Failed to start location tracking');
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error starting location tracking: $e');
    }
  }

  /// Stop location tracking
  Future<void> _stopLocationTracking() async {
    try {
      await _locationService.stopTracking();
      debugPrint('✅ Location tracking stopped');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error stopping location tracking: $e');
    }
  }

  /// Manually toggle tracking (for debug/testing)
  Future<void> toggleLocationTracking() async {
    if (_locationService.isTracking) {
      await _stopLocationTracking();
    } else {
      await _startLocationTracking();
    }
  }
}