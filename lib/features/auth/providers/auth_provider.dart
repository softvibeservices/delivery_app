//lib\features\auth\providers\auth_provider.dart

import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../config/api_endpoints.dart';

enum AuthStatus { unknown, authenticated, unauthenticated, pending, rejected }

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  AuthStatus _status = AuthStatus.unknown;
  AuthStatus get status => _status;

  String? _partnerId;
  String? get partnerId => _partnerId;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

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

      // ✅ Backend already ensures "approved"
      await StorageService.saveToken(token);
      await StorageService.savePartnerStatus('approved');

      _status = AuthStatus.authenticated;

      notifyListeners();
      return null;
    } catch (e) {
      return 'Invalid or expired OTP';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 🚪 LOGOUT
  Future<void> logout() async {
    await StorageService.clearAll();
    _status = AuthStatus.unauthenticated;
    _partnerId = null;
    notifyListeners();
  }

  // 📝 REGISTER (UNCHANGED)
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
}
