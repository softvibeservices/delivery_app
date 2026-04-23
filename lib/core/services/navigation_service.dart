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

  // Broadcasts the tapped orderId (or null if unavailable) to all listeners.
  final StreamController<String?> _notificationTap =
      StreamController<String?>.broadcast();

  Stream<String?> get onNotificationTap => _notificationTap.stream;

  /// Call this whenever a notification is tapped, passing the orderId payload.
  void handleNotificationTap(String? orderId) {
    debugPrint('🧭 NavigationService: notification tap → orderId=$orderId');
    _notificationTap.add(orderId);
  }

  void dispose() {
    _notificationTap.close();
  }
}

