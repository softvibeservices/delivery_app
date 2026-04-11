// lib/core/services/session_service.dart

import 'dart:async';

/// Singleton that broadcasts a force-logout event whenever the API layer
/// detects a 401. AuthProvider listens to [forceLogout] and calls logout()
/// so the app navigates back to the login screen automatically.
class SessionService {
  // ─── Singleton ────────────────────────────────────────────────────────────
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();
  static SessionService get instance => _instance;

  // Broadcast so multiple listeners (e.g. AuthProvider + any future service)
  // can subscribe without interfering with each other.
  final _forceLogoutController = StreamController<void>.broadcast();

  Stream<void> get forceLogout => _forceLogoutController.stream;

  /// Called by [ApiService] on every 401 response.
  void triggerForceLogout() {
    if (!_forceLogoutController.isClosed) {
      _forceLogoutController.add(null);
    }
  }

  void dispose() {
    _forceLogoutController.close();
  }
}