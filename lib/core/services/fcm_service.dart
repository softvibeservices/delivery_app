// lib/core/services/fcm_service.dart
// Handles all Firebase Cloud Messaging logic:
//  - Device token registration + refresh
//  - Foreground message display (via NotificationService)
//  - Background message handler (top-level @pragma function)
//  - Notification tap → NavigationService (triggers orders page refresh)

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'navigation_service.dart';
import 'notification_service.dart';
import 'storage_service.dart';
import '../../config/api_endpoints.dart';

// ─── Background message handler ───────────────────────────────────────────────
// MUST be a top-level function — cannot be inside a class.
// Called when FCM delivers a message with the app killed or in background.
// Flutter/FCM automatically shows the system notification from the payload's
// `notification` block, so we only need to handle data-only messages here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  debugPrint(
    '📨 [BG] FCM message received: ${message.messageId} '
    'type=${message.data['type']}',
  );

  // For data-only messages (no notification block), show a local notification.
  // Messages that already have a notification block are shown by FCM
  // automatically on Android when the app is in the background.
  if (message.notification == null && message.data['type'] == 'new_order') {
    await NotificationService.instance.init();
    await NotificationService.instance.showNewOrderNotification(
      orderId: message.data['orderId'] ?? '',
      customerName: message.data['customerName'] ?? 'Customer',
      shopName: message.data['shopName'] ?? '',
    );
  }
}

// ─── FCMService ───────────────────────────────────────────────────────────────

class FCMService {
  // ─── Singleton ──────────────────────────────────────────────────────────
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();
  static FCMService get instance => _instance;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  StreamSubscription? _foregroundSub;
  bool _initialized = false;

  // ─── INIT ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;

    // 1. Request permission (required on iOS, optional prompt on Android 13+).
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('📱 FCM permission: ${settings.authorizationStatus}');

    // 2. Register the background handler.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 3. Get current token and conditionally send to backend.
    //    _registerToken() guards against sending when no auth token exists,
    //    so it is safe to call on cold start before the user logs in.
    await _registerToken();

    // 4. Listen for token refresh (device reinstall, token rotation, etc.).
    _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('🔄 FCM token refreshed');
      await StorageService.saveFcmToken(newToken);
      // StorageService.getToken() is async (FlutterSecureStorage).
      final authToken = await StorageService.getToken();
      if (authToken != null && authToken.isNotEmpty) {
        await _sendTokenToBackend(newToken, authToken);
      } else {
        debugPrint(
            '⚠️ FCM token refreshed but user not logged in — saved locally only');
      }
    });

    // 5. Handle foreground messages (app is open and active).
    _foregroundSub = FirebaseMessaging.onMessage.listen(_handleForeground);

    // 6. Handle notification tap when app was in background (not killed).
    //    The app is already running — NavigationService can signal immediately.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpened);

    // 7. Handle notification tap that launched the app from a killed state.
    //    Delay slightly to let the widget tree mount before we signal navigation.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('🚀 App launched from FCM notification');
      // Small delay ensures the orders page listener is subscribed before
      // the navigation signal fires.
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleMessageOpened(initialMessage);
      });
    }

    _initialized = true;
    debugPrint('✅ FCMService initialised');
  }

  // ─── TOKEN MANAGEMENT ─────────────────────────────────────────────────────

  /// Fetches the FCM device token from Firebase.
  /// Always saves it locally via StorageService.
  /// Only calls the backend if the user already has a valid auth token —
  /// this prevents the 401 → force-logout → infinite loop on cold start.
  Future<void> _registerToken() async {
    try {
      final fcmToken = await _messaging.getToken();
      if (fcmToken == null) {
        debugPrint('⚠️ FCM token is null — skipping registration');
        return;
      }

      debugPrint('🔑 FCM token: ${fcmToken.substring(0, 20)}...');

      // Always persist locally so sendTokenAfterLogin() can read it.
      await StorageService.saveFcmToken(fcmToken);

      // StorageService.getToken() reads from FlutterSecureStorage (async).
      final authToken = await StorageService.getToken();
      if (authToken == null || authToken.isEmpty) {
        debugPrint(
          '⚠️ FCM: No auth token — token saved locally, will be sent after login',
        );
        return;
      }

      await _sendTokenToBackend(fcmToken, authToken);
    } catch (e) {
      debugPrint('❌ FCM token registration error: $e');
    }
  }

  /// Call this immediately after a successful login / OTP verification.
  /// Reads the locally-saved FCM token and pushes it to the backend now
  /// that a valid auth token is in secure storage.
  Future<void> sendTokenAfterLogin() async {
    try {
      // getFcmToken() is synchronous (SharedPreferences).
      final fcmToken = StorageService.getFcmToken();
      // getToken() is asynchronous (FlutterSecureStorage).
      final authToken = await StorageService.getToken();

      if (authToken == null || authToken.isEmpty) {
        debugPrint('⚠️ sendTokenAfterLogin: no auth token yet — aborting');
        return;
      }

      if (fcmToken != null && fcmToken.isNotEmpty) {
        debugPrint('📤 Sending stored FCM token to backend after login...');
        await _sendTokenToBackend(fcmToken, authToken);
      } else {
        // No locally-stored FCM token yet — fetch fresh from Firebase.
        debugPrint(
            '📤 No stored FCM token — fetching fresh token after login...');
        await _registerToken();
      }
    } catch (e) {
      debugPrint('❌ sendTokenAfterLogin error: $e');
    }
  }

  /// Sends the FCM token to the backend.
  /// Uses a plain Dio (not ApiService.dio) to avoid interceptor side-effects.
  Future<void> _sendTokenToBackend(String fcmToken, String authToken) async {
    try {
      final dio = _buildAuthenticatedDio(authToken);
      await dio.patch(
        ApiEndpoints.updateFcmToken,
        data: {'fcmToken': fcmToken},
      );
      debugPrint('✅ FCM token sent to backend');
    } catch (e) {
      // Non-fatal — token will be re-sent on next login or token refresh.
      debugPrint('⚠️ Failed to send FCM token to backend: $e');
    }
  }

  /// Call this on logout to disassociate this device from the partner.
  /// Pass the session token BEFORE it gets wiped from storage.
  Future<void> clearToken({required String sessionToken}) async {
    try {
      if (sessionToken.isEmpty) {
        debugPrint('⚠️ clearToken: empty sessionToken — skipping backend call');
        return;
      }

      // Use a plain Dio instance — bypass ApiService interceptors entirely.
      // ApiService.dio would re-read the (already-cleared) auth token,
      // send an unauthenticated request, get 401, and trigger force-logout
      // again — causing an infinite loop.
      final dio = _buildAuthenticatedDio(sessionToken);
      await dio.patch(
        ApiEndpoints.updateFcmToken,
        data: {'fcmToken': null},
      );
      debugPrint('✅ FCM token cleared on backend');
    } catch (e) {
      // Non-fatal — token rotation or next login will overwrite it anyway.
      debugPrint('⚠️ Failed to clear FCM token on backend: $e');
    } finally {
      await StorageService.saveFcmToken('');
    }
  }

  /// Builds a plain Dio with a hardcoded Bearer token and no interceptors.
  /// Used for all FCM backend calls to avoid auth interceptor side-effects.
  Dio _buildAuthenticatedDio(String bearerToken) {
    return Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.productionBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $bearerToken',
        },
      ),
    );
  }

  // ─── MESSAGE HANDLERS ─────────────────────────────────────────────────────

  void _handleForeground(RemoteMessage message) {
    debugPrint(
      '📨 [FG] FCM message: ${message.messageId} type=${message.data['type']}',
    );

    // FCM does NOT show a system notification when the app is in the foreground.
    // We show one manually via NotificationService.
    final type = message.data['type'];

    if (type == 'new_order') {
      NotificationService.instance.showNewOrderNotification(
        orderId: message.data['orderId'] ?? '',
        // Use data['customerName'], not notification?.body.
        // notification?.body is the full display string like
        // "New order for Shop X — check the app", not just the name.
        customerName: message.data['customerName'] ?? 'Customer',
        shopName: message.data['shopName'] ?? '',
      );
      // Also refresh the orders list immediately while app is open —
      // the user sees the new order appear without tapping anything.
      NavigationService.instance.handleNotificationTap(
        message.data['orderId'],
      );
    } else if (type == 'order_status_update') {
      NotificationService.instance.showOrderStatusNotification(
        orderId: message.data['orderId'] ?? '',
        status: message.data['status'] ?? '',
        customerName: message.data['customerName'] ?? 'Customer',
      );

      // FIX (Bug 1B): Trigger pending orders list refresh for external status
      // updates, the same way new_order messages do.
      NavigationService.instance.handleNotificationTap(
        message.data['orderId'],
      );

      // FIX (Bug 5): If the external update marks an order as Delivered,
      // also signal the delivered orders screen to reload.
      if (message.data['status'] == 'Delivered') {
        NavigationService.instance.triggerDeliveredOrdersRefresh();
      }
    }
  }

  void _handleMessageOpened(RemoteMessage message) {
    debugPrint(
      '👆 FCM notification tapped: type=${message.data['type']}',
    );
    // Signal the orders page to refresh. The page listener calls fetchOrders()
    // and the new order appears without requiring a manual pull-to-refresh.
    NavigationService.instance.handleNotificationTap(
      message.data['orderId'],
    );
  }

  // ─── DISPOSE ──────────────────────────────────────────────────────────────

  void dispose() {
    _foregroundSub?.cancel();
  }
}