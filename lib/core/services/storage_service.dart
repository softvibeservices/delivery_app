// lib/core/services/storage_service.dart
// Groups 1-4 + Group 8 + Group 9 combined.
// Group 8: removed 'promotional_notifications' key, added clearLocationQueue()
//          and clearRecentSearches() as public methods.
// Group 9: auth token moved from SharedPreferences to FlutterSecureStorage
//          (Android Keystore / iOS Keychain). All other keys stay in prefs.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  StorageService._();

  // ─── Cached SharedPreferences instance ────────────────────────────────────
  static SharedPreferences? _prefs;

  // ─── Secure storage for auth token only ───────────────────────────────────
  // Group 9: token lives in Android Keystore / iOS Keychain, not plain prefs.
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Call once in main() after WidgetsFlutterBinding.ensureInitialized().
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    debugPrint('✅ StorageService initialised');
  }

  // ─── Key constants ─────────────────────────────────────────────────────────
  // Group 9: _tokenKey is now used only by FlutterSecureStorage, not prefs.
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user';
  static const String _partnerIdKey = 'partner_id';
  static const String _partnerStatusKey = 'partner_status';
  static const String _fcmTokenKey = 'fcm_token';
  static const String _locationQueueKey = 'location_queue';
  static const String _recentSearchesKey = 'recent_customer_searches';

  // Notification settings keys (read by NotificationService).
  // Group 8: 'promotional_notifications' key removed entirely.
  static const String keyNotificationsEnabled = 'notifications_enabled';
  static const String keyOrderNotifications = 'order_notifications';
  static const String keyDeliveryUpdates = 'delivery_updates';
  static const String keySoundEnabled = 'sound_enabled';
  static const String keyVibrationEnabled = 'vibration_enabled';

  // ─── TOKEN — Group 9: FlutterSecureStorage ─────────────────────────────────

  static Future<void> saveToken(String token) async {
    await _secure.write(key: _tokenKey, value: token);
    debugPrint('✅ Token saved to secure storage');
  }

  /// Returns null if no token is stored.
  static Future<String?> getToken() async {
    return _secure.read(key: _tokenKey);
  }

  static Future<void> _deleteToken() async {
    await _secure.delete(key: _tokenKey);
    debugPrint('🗑️ Token deleted from secure storage');
  }

  // ─── USER ──────────────────────────────────────────────────────────────────

  static Future<void> saveUser(Map<String, dynamic> user) async {
    await _prefs!.setString(_userKey, json.encode(user));
    debugPrint('✅ User data saved');
  }

  static Map<String, dynamic>? getUser() {
    try {
      final raw = _prefs!.getString(_userKey);
      if (raw == null) return null;
      return json.decode(raw) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ Error getting user: $e');
      return null;
    }
  }

  // ─── PARTNER ID ───────────────────────────────────────────────────────────

  static Future<void> savePartnerId(String partnerId) async {
    await _prefs!.setString(_partnerIdKey, partnerId);
    debugPrint('✅ Partner ID saved: $partnerId');
  }

  static String? getPartnerId() => _prefs!.getString(_partnerIdKey);

  // ─── PARTNER STATUS ───────────────────────────────────────────────────────

  static Future<void> savePartnerStatus(String status) async {
    await _prefs!.setString(_partnerStatusKey, status);
    debugPrint('✅ Partner status saved: $status');
  }

  static String? getPartnerStatus() => _prefs!.getString(_partnerStatusKey);

  // ─── BATCH AUTH READ ──────────────────────────────────────────────────────
  // Token is async (secure storage); status and partnerId are sync (prefs).

  static Future<({String? token, String? status, String? partnerId})>
      getAuthData() async {
    final token = await getToken();
    final status = _prefs!.getString(_partnerStatusKey);
    final partnerId = _prefs!.getString(_partnerIdKey);
    return (token: token, status: status, partnerId: partnerId);
  }

  // ─── CONVENIENCE GETTERS ──────────────────────────────────────────────────

  static String? getPartnerName() => getUser()?['name']?.toString();
  static String? getPartnerEmail() => getUser()?['email']?.toString();

  static String? getUserId() {
    final user = getUser();
    if (user == null) return null;
    final id = user['createdByUser']?.toString();
    if (id != null && id.isNotEmpty) return id;
    return user['_id']?.toString();
  }

  static String? getOwnPartnerId() => getUser()?['_id']?.toString();

  // ─── FCM TOKEN ────────────────────────────────────────────────────────────

  static Future<void> saveFcmToken(String token) async {
    await _prefs!.setString(_fcmTokenKey, token);
  }

  static String? getFcmToken() => _prefs!.getString(_fcmTokenKey);

  // ─── LOCATION QUEUE ───────────────────────────────────────────────────────

  static Future<void> saveLocationQueue(
      List<Map<String, dynamic>> queue) async {
    await _prefs!.setString(_locationQueueKey, json.encode(queue));
  }

  static List<Map<String, dynamic>> getLocationQueue() {
    try {
      final raw = _prefs!.getString(_locationQueueKey);
      if (raw == null) return [];
      return (json.decode(raw) as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('❌ Error loading location queue: $e');
      return [];
    }
  }

  /// Group 8: public — called by AppSettingsScreen "Clear Cache".
  static Future<void> clearLocationQueue() async {
    await _prefs!.remove(_locationQueueKey);
    debugPrint('🗑️ Location queue cleared');
  }

  // ─── RECENT SEARCHES ──────────────────────────────────────────────────────

  static Future<void> saveRecentSearches(String jsonEncoded) async {
    await _prefs!.setString(_recentSearchesKey, jsonEncoded);
  }

  static String? getRecentSearches() =>
      _prefs!.getString(_recentSearchesKey);

  /// Group 8: public — called by AppSettingsScreen "Clear Cache".
  static Future<void> clearRecentSearches() async {
    await _prefs!.remove(_recentSearchesKey);
    debugPrint('🗑️ Recent searches cleared');
  }

  // ─── NOTIFICATION SETTINGS ────────────────────────────────────────────────
  // Group 8: promotional field removed from the record type.

  static ({
    bool enabled,
    bool orderNotifs,
    bool deliveryUpdates,
    bool sound,
    bool vibration,
  }) getNotificationSettings() {
    return (
      enabled: _prefs!.getBool(keyNotificationsEnabled) ?? true,
      orderNotifs: _prefs!.getBool(keyOrderNotifications) ?? true,
      deliveryUpdates: _prefs!.getBool(keyDeliveryUpdates) ?? true,
      sound: _prefs!.getBool(keySoundEnabled) ?? true,
      vibration: _prefs!.getBool(keyVibrationEnabled) ?? true,
    );
  }

  // ─── CLEAR AUTH KEYS (logout) ─────────────────────────────────────────────
  // Group 9: token is now deleted from secure storage, not prefs.
  // Notification settings, queue, and recent searches survive logout.

  static Future<void> clearAuthKeys() async {
    await _deleteToken(); // secure storage
    await _prefs!.remove(_userKey);
    await _prefs!.remove(_partnerIdKey);
    await _prefs!.remove(_partnerStatusKey);
    debugPrint('🗑️ Auth keys cleared');
  }

  // ─── FULL WIPE (testing / factory reset) ──────────────────────────────────

  static Future<void> clearAll() async {
    await _secure.deleteAll(); // wipes secure storage
    await _prefs!.clear(); // wipes all prefs
    debugPrint('🗑️ All storage cleared');
  }

  // ─── DEBUG ────────────────────────────────────────────────────────────────

  static Future<void> printAllData() async {
    final token = await getToken();
    final user = getUser();
    final partnerId = getPartnerId();
    final status = getPartnerStatus();
    debugPrint('=========== STORAGE DATA ===========');
    debugPrint('Token: ${token != null ? 'EXISTS (secure storage)' : 'NULL'}');
    debugPrint('Partner ID: $partnerId');
    debugPrint('Partner Status: $status');
    debugPrint('User Data: $user');
    debugPrint('====================================');
  }
}