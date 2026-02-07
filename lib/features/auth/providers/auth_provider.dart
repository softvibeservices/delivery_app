// lib/features/auth/providers/auth_provider.dart

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
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

  void setContext(BuildContext context) {
    _context = context;
  }

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

  // ✅ CHECK ACTUAL STATUS FROM BACKEND (NO TOKEN REQUIRED)
  Future<void> checkAccountStatus() async {
    try {
      _isLoading = true;
      notifyListeners();

      if (_partnerId == null) {
        _partnerId = await StorageService.getPartnerId();
      }

      if (_partnerId == null) {
        debugPrint('❌ No partnerId found');
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      debugPrint('🔄 Checking account status for partner: $_partnerId');

      // ✅ Use NEW check-status endpoint (POST with partnerId, NO TOKEN)
      final response = await _apiService.dio.post(
        ApiEndpoints.checkStatus,
        data: {'partnerId': _partnerId},
      );

      debugPrint('✅ Check status response: ${response.data}');

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
      if (e is DioException) {
        debugPrint('❌ DioException type: ${e.type}');
        debugPrint('❌ Response: ${e.response?.data}');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 🔐 LOGIN (REQUEST OTP)
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
      
      // ✅ Check status from backend response
      final partnerStatus = response.data['status'] as String?;
      
      if (partnerStatus != null) {
        debugPrint('📊 Partner status: $partnerStatus');
        await StorageService.savePartnerStatus(partnerStatus);
        
        if (partnerStatus == 'pending') {
          _status = AuthStatus.pending;
          notifyListeners();
          return 'PENDING'; // ✅ Return marker, not full message
        } else if (partnerStatus == 'rejected') {
          _status = AuthStatus.rejected;
          notifyListeners();
          return 'REJECTED'; // ✅ Return marker, not full message
        }
      }
      
      // Success for approved users
      debugPrint('✅ Login successful, OTP sent');
      return null;
      
    } catch (e) {
      debugPrint('❌ Login Error: $e');
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        final errorMessage = e.response?.data['error'] as String?;
        
        debugPrint('❌ Status code: $statusCode');
        debugPrint('❌ Error message: $errorMessage');
        
        if (statusCode == 404) {
          return 'Account not found';
        } else if (statusCode == 403) {
          return errorMessage ?? 'Invalid password';
        }
      }
      return 'Login failed. Please try again.';
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

      if (token == null) {
        return 'No token received from server';
      }

      await StorageService.saveToken(token);
      
      if (partner != null) {
        final backendStatus = partner['status'] as String;
        await StorageService.savePartnerStatus(backendStatus);
        await StorageService.saveUser(partner);
        
        debugPrint('✅ User data saved: $partner');
        
        switch (backendStatus) {
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
      } else {
        debugPrint('⚠️ No partner data in response');
        await StorageService.savePartnerStatus('approved');
        _status = AuthStatus.authenticated;
        await _startLocationTracking();
      }

      notifyListeners();
      return null;
      
    } catch (e) {
      debugPrint('❌ OTP Verification Error: $e');
      if (e is DioException) {
        final errorMessage = e.response?.data['error'] as String?;
        return errorMessage ?? 'Invalid or expired OTP';
      }
      return 'Invalid or expired OTP';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _stopLocationTracking();
    await StorageService.clearAll();
    _status = AuthStatus.unauthenticated;
    _partnerId = null;
    notifyListeners();
  }

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

  Future<void> _startLocationTracking() async {
    try {
      debugPrint('🎯 Attempting to start location tracking...');

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

      if (!await _locationService.hasAlwaysPermission()) {
        debugPrint('⚠️ Need "Always Allow" permission');
        
        if (_context != null && _context!.mounted) {
          final userAgreed = await PermissionHelper.showLocationPermissionDialog(_context!);
          if (!userAgreed) {
            debugPrint('❌ User declined permission request');
            return;
          }
        }

        final granted = await _locationService.requestAlwaysPermission();
        
        if (!granted) {
          debugPrint('❌ Permission denied');
          if (_context != null && _context!.mounted) {
            await PermissionHelper.showPermissionDeniedDialog(_context!);
          }
          return;
        }
      }

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
      await _startLocationTracking();
    }
  }
}