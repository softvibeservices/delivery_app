// lib/core/services/api_service.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // provides debugPrint
import '../../config/api_endpoints.dart';
import 'storage_service.dart';
import 'session_service.dart';

class ApiService {
  // ─── Singleton ────────────────────────────────────────────────────────────
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal() {
    _initDio();
  }

  late final Dio dio;

  void _initDio() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.productionBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await StorageService.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          // Log method + path only — never log headers (they contain the token)
          debugPrint('🌐 ${options.method} ${options.baseUrl}${options.path}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint(
            '✅ ${response.statusCode} ${response.requestOptions.path}',
          );
          handler.next(response);
        },
        onError: (error, handler) async {
          debugPrint('❌ API Error: ${error.type}');
          debugPrint(
            '❌ URL: ${error.requestOptions.baseUrl}${error.requestOptions.path}',
          );
          debugPrint('❌ Message: ${error.message}');
          if (error.response != null) {
            debugPrint('❌ Response: ${error.response?.data}');
          }

          // ─── Global 401 handler ──────────────────────────────────────────
          if (error.response?.statusCode == 401) {
            debugPrint('🔐 401 detected — clearing auth and forcing logout');
            await StorageService.clearAuthKeys();
            SessionService.instance.triggerForceLogout();
          }

          handler.next(error);
        },
      ),
    );
  }
}