// lib/core/services/fcm_service.dart
// Handles all Firebase Cloud Messaging logic:
//  - Device token registration + refresh
//  - Foreground message display (via NotificationService)
//  - Background message handler (top-level @pragma function)
//  - Notification tap → navigation

import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'notification_service.dart';
import 'storage_service.dart';
import '../../config/api_endpoints.dart';
import 'package:dio/dio.dart'; // for Options

// ─── Background message handler ───────────────────────────────────────────────
// MUST be a top-level function — cannot be inside a class.
// Called when FCM delivers a message with the app killed or in background.
// Flutter/FCM automatically shows the system notification from the payload's
// `notification` block, so we only need to handle data-only messages here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialised in the background isolate.
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
    debugPrint(
      '📱 FCM permission: ${settings.authorizationStatus}',
    );

    // 2. Register the background handler.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 3. Get current token and send to backend.
    await _registerToken();

    // 4. Listen for token refresh (device reinstall, token rotation, etc.).
    _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('🔄 FCM token refreshed');
      await StorageService.saveFcmToken(newToken);
      await _sendTokenToBackend(newToken);
    });

    // 5. Handle foreground messages (app is open and active).
    _foregroundSub = FirebaseMessaging.onMessage.listen(_handleForeground);

    // 6. Handle notification tap when app was in background (not killed).
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpened);

    // 7. Handle notification tap that launched the app from killed state.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('🚀 App launched from FCM notification');
      _handleMessageOpened(initialMessage);
    }

    _initialized = true;
    debugPrint('✅ FCMService initialised');
  }

  // ─── TOKEN MANAGEMENT ─────────────────────────────────────────────────────

  Future<void> _registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) {
        debugPrint('⚠️ FCM token is null — skipping registration');
        return;
      }
      debugPrint('🔑 FCM token: ${token.substring(0, 20)}...');
      await StorageService.saveFcmToken(token);
      await _sendTokenToBackend(token);
    } catch (e) {
      debugPrint('❌ FCM token registration error: $e');
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      await ApiService().dio.patch(
        ApiEndpoints.updateFcmToken,
        data: {'fcmToken': token},
      );
      debugPrint('✅ FCM token sent to backend');
    } catch (e) {
      // Non-fatal — token will be re-sent on next login or refresh.
      debugPrint('⚠️ Failed to send FCM token to backend: $e');
    }
  }

    /// Call this on logout to disassociate this device from the partner.
  /// Pass the session token BEFORE it gets wiped from storage.
  Future<void> clearToken({required String sessionToken}) async {
    try {
      // Use a plain Dio instance — bypass the auth interceptor entirely.
      // We pass the token manually because storage may already be cleared
      // by the time this call fires.
      final dio = ApiService().dio;
      await dio.patch(
        ApiEndpoints.updateFcmToken,
        data: {'fcmToken': null},
        options: Options(
          headers: {'Authorization': 'Bearer $sessionToken'},
        ),
      );
      debugPrint('✅ FCM token cleared on backend');
    } catch (e) {
      // Non-fatal — token rotation or next login will overwrite it anyway.
      debugPrint('⚠️ Failed to clear FCM token on backend: $e');
    } finally {
      await StorageService.saveFcmToken('');
    }
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
        customerName: message.notification?.body ?? 'Customer',
        shopName: message.data['shopName'] ?? '',
      );
    } else if (type == 'order_status_update') {
      NotificationService.instance.showOrderStatusNotification(
        orderId: message.data['orderId'] ?? '',
        status: message.data['status'] ?? '',
        customerName: message.data['customerName'] ?? 'Customer',
      );
    }
  }

  void _handleMessageOpened(RemoteMessage message) {
    debugPrint(
      '👆 FCM notification tapped: type=${message.data['type']}',
    );
    // Navigation from notification tap is intentionally left simple here.
    // The app opens to the main shell. If you want deep-link to a specific
    // order, store the orderId and navigate in your router after app is ready.
    // Example: store message.data['orderId'] in a pending navigation queue.
  }

  // ─── DISPOSE ──────────────────────────────────────────────────────────────

  void dispose() {
    _foregroundSub?.cancel();
  }
}