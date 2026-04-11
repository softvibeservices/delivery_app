// lib/core/services/notification_service.dart
// Wires flutter_local_notifications to the settings toggles
// already saved by AppSettingsScreen in SharedPreferences.
// FCMService calls this for foreground message display.
// BackgroundLocationService calls this for new-order polling alerts.

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'storage_service.dart';

class NotificationService {
  // ─── Singleton ────────────────────────────────────────────────────────────
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();
  static NotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ─── Channel IDs ──────────────────────────────────────────────────────────
  static const String _orderChannelId = 'new_orders';
  static const String _orderChannelName = 'New Orders';
  static const String _orderChannelDesc =
      'Notifications for new delivery assignments';

  static const String _updateChannelId = 'delivery_updates';
  static const String _updateChannelName = 'Delivery Updates';
  static const String _updateChannelDesc =
      'Notifications for order status changes';

  // ─── INIT ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create Android notification channels (Android 8+).
    await _createChannel(
      id: _orderChannelId,
      name: _orderChannelName,
      description: _orderChannelDesc,
      importance: Importance.high,
    );

    await _createChannel(
      id: _updateChannelId,
      name: _updateChannelName,
      description: _updateChannelDesc,
      importance: Importance.defaultImportance,
    );

    // Request permission on Android 13+.
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
    debugPrint('✅ NotificationService initialised');
  }

  Future<void> _createChannel({
    required String id,
    required String name,
    required String description,
    required Importance importance,
  }) async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      AndroidNotificationChannel(
        id,
        name,
        description: description,
        importance: importance,
      ),
    );
  }

  // ─── NOTIFICATION TAP HANDLER ─────────────────────────────────────────────

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: payload=${response.payload}');
    // payload is the orderId string.
    // Deep-link navigation will be wired in FCMService.
  }

  // ─── PUBLIC SHOW METHODS ──────────────────────────────────────────────────

  /// Show a new-order notification, respecting user settings.
  Future<void> showNewOrderNotification({
    required String orderId,
    required String customerName,
    String shopName = '',
  }) async {
    if (!_initialized) await init();

    final settings = StorageService.getNotificationSettings();

    if (!settings.enabled) {
      debugPrint('🔕 Notifications disabled by user');
      return;
    }
    if (!settings.orderNotifs) {
      debugPrint('🔕 Order notifications disabled by user');
      return;
    }

    final body = shopName.isNotEmpty
        ? 'Order for $shopName assigned to you'
        : 'New order for $customerName assigned to you';

    await _show(
      id: orderId.hashCode,
      title: 'New Order Assigned',
      body: body,
      channelId: _orderChannelId,
      payload: orderId,
      sound: settings.sound,
      vibration: settings.vibration,
    );
  }

  /// Show a delivery-update notification, respecting user settings.
  Future<void> showOrderStatusNotification({
    required String orderId,
    required String status,
    required String customerName,
  }) async {
    if (!_initialized) await init();

    final settings = StorageService.getNotificationSettings();

    if (!settings.enabled || !settings.deliveryUpdates) {
      debugPrint('🔕 Delivery update notifications disabled');
      return;
    }

    await _show(
      id: '${orderId}_status'.hashCode,
      title: 'Order Status Updated',
      body: 'Order for $customerName is now "$status"',
      channelId: _updateChannelId,
      payload: orderId,
      sound: settings.sound,
      vibration: settings.vibration,
    );
  }

  // ─── INTERNAL ─────────────────────────────────────────────────────────────

  Future<void> _show({
    required int id,
    required String title,
    required String body,
    required String channelId,
    String? payload,
    required bool sound,
    required bool vibration,
  }) async {
    final isOrderChannel = channelId == _orderChannelId;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      isOrderChannel ? _orderChannelName : _updateChannelName,
      channelDescription:
          isOrderChannel ? _orderChannelDesc : _updateChannelDesc,
      importance:
          isOrderChannel ? Importance.high : Importance.defaultImportance,
      priority: isOrderChannel ? Priority.high : Priority.defaultPriority,
      playSound: sound,
      enableVibration: vibration,
      icon: '@mipmap/ic_launcher',
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
    );

    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: darwinDetails),
      payload: payload,
    );

    debugPrint('🔔 Notification shown: "$title" — $body');
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}