// lib/core/services/api_service.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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

  // Endpoints that should NOT trigger a force-logout on 401.
  // These are fire-and-forget calls that can legitimately fail when the user
  // is not yet logged in (e.g. FCM token registration on cold start).
  static const _skipLogoutPaths = [
    '/api/delivery/update-fcm-token',
  ];

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
            final requestPath = error.requestOptions.path;

            // Some endpoints (e.g. FCM token registration) can legitimately
            // return 401 before the user has logged in. Triggering a
            // force-logout in those cases creates an infinite loop:
            //   401 → force-logout → clearToken call → 401 → repeat
            // Skip force-logout for whitelisted paths.
            final shouldSkip =
                _skipLogoutPaths.any((p) => requestPath.contains(p));

            if (shouldSkip) {
              debugPrint(
                '⚠️ 401 on $requestPath — skipping force logout (whitelisted)',
              );
            } else {
              debugPrint('🔐 401 detected — clearing auth and forcing logout');
              await StorageService.clearAuthKeys();
              SessionService.instance.triggerForceLogout();
            }
          }

          handler.next(error);
        },
      ),
    );
  }
}