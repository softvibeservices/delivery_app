// lib/core/services/navigation_service.dart
// Bridges notification taps to UI reactions (e.g. refresh + scroll to order).
// Any widget can listen to onNotificationTap and react without needing a
// BuildContext at the point the tap fires.

import 'dart:async';
// ignore: depend_on_referenced_packages
import 'package:flutter/foundation.dart' show debugPrint;

class NavigationService {
  // ─── Singleton ────────────────────────────────────────────────────────────
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();
  static NavigationService get instance => _instance;

  // ─── Pending orders / notification tap stream ─────────────────────────────
  // Broadcasts the tapped orderId (or null if unavailable) to all listeners.
  final StreamController<String?> _notificationTap =
      StreamController<String?>.broadcast();

  Stream<String?> get onNotificationTap => _notificationTap.stream;

  /// Call this whenever a notification is tapped, passing the orderId payload.
  void handleNotificationTap(String? orderId) {
    debugPrint('🧭 NavigationService: notification tap → orderId=$orderId');
    _notificationTap.add(orderId);
  }

  // ─── Delivered orders refresh stream ──────────────────────────────────────
  // FIX (Bug 5): Broadcasts a signal whenever a delivery is completed so that
  // DeliveredOrdersScreen can auto-reload without the user pulling to refresh.
  final StreamController<void> _deliveredRefresh =
      StreamController<void>.broadcast();

  Stream<void> get onDeliveredOrdersRefresh => _deliveredRefresh.stream;

  /// Call this whenever an order transitions to "Delivered":
  ///   - from OrderDetailsScreen._updateStatus()
  ///   - from PendingOrdersScreen._updateStatus()
  ///   - from FCMService._handleForeground() for order_status_update messages
  void triggerDeliveredOrdersRefresh() {
    debugPrint('🧭 NavigationService: triggering delivered orders refresh');
    _deliveredRefresh.add(null);
  }

  void dispose() {
    _notificationTap.close();
    _deliveredRefresh.close();
  }
}