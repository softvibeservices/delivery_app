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

  // Keywords in a 403 response body that signal the account itself has been
  // removed / blocked — not just a permission issue on a single resource.
  static const _accountDeletedKeywords = [
    'deleted',
    'deactivated',
    'suspended',
    'banned',
    'not found',
    'does not exist',
    'no longer exists',
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

          final requestPath = error.requestOptions.path;
          final shouldSkip =
              _skipLogoutPaths.any((p) => requestPath.contains(p));

          // ─── 401: token invalid / expired ────────────────────────────────
          if (error.response?.statusCode == 401) {
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

          // ─── 403: account deleted / deactivated / suspended ──────────────
          //
          // FIX: Previously only 401 triggered force-logout. But a deleted
          // partner whose token hasn't been server-side invalidated yet will
          // get a 403 from account-guarded endpoints rather than a 401.
          // We inspect the error message and only act when the error text
          // clearly indicates the account itself is gone — not just a
          // per-resource permission denial.
          else if (error.response?.statusCode == 403 && !shouldSkip) {
            final data = error.response?.data;
            final errorMsg = (data is Map
                    ? (data['error'] ?? data['message'])?.toString()
                    : data?.toString())
                ?.toLowerCase() ?? '';

            final isAccountGone = _accountDeletedKeywords
                .any((kw) => errorMsg.contains(kw));

            if (isAccountGone) {
              debugPrint(
                '🔐 403 account-gone ($errorMsg) — clearing auth and forcing logout',
              );
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