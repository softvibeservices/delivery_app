// lib/core/services/storage_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user';
  static const String _partnerIdKey = 'partner_id';
  static const String _partnerStatusKey = 'partner_status'; // ✅ ADDED

  // ========= TOKEN METHODS =========
  
  /// Save authentication token
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    debugPrint('✅ Token saved');
  }

  /// Get authentication token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Remove authentication token
  static Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    debugPrint('🗑️ Token removed');
  }

  // ========= USER METHODS =========

  /// Save user data (delivery partner data)
  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, json.encode(user));
    debugPrint('✅ User data saved');
  }

  /// Get user data
  static Future<Map<String, dynamic>?> getUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        return json.decode(userJson) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting user: $e');
      return null;
    }
  }

  /// Remove user data
  static Future<void> removeUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    debugPrint('🗑️ User data removed');
  }

  // ========= PARTNER ID METHODS =========

  /// Save partner ID
  static Future<void> savePartnerId(String partnerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_partnerIdKey, partnerId);
    debugPrint('✅ Partner ID saved: $partnerId');
  }

  /// Get partner ID
  static Future<String?> getPartnerId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_partnerIdKey);
  }

  /// Remove partner ID
  static Future<void> removePartnerId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_partnerIdKey);
    debugPrint('🗑️ Partner ID removed');
  }

  // ========= PARTNER STATUS METHODS (✅ ADDED - REQUIRED BY AUTH) =========

  /// Save partner status (approved, pending, rejected)
  static Future<void> savePartnerStatus(String status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_partnerStatusKey, status);
    debugPrint('✅ Partner status saved: $status');
  }

  /// Get partner status
  static Future<String?> getPartnerStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_partnerStatusKey);
  }

  /// Remove partner status
  static Future<void> removePartnerStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_partnerStatusKey);
    debugPrint('🗑️ Partner status removed');
  }

  // ========= USER ID METHODS (✅ FOR STICKY NOTES) =========

  /// Get manager's user ID from stored delivery partner data
  /// This is critical for sticky notes feature
  /// Returns the manager's ID (createdByUser) who created this delivery partner
  static Future<String?> getUserId() async {
    try {
      final user = await getUser();
      if (user == null) {
        debugPrint('⚠️ No user data found');
        return null;
      }

      // First, try to get the manager's ID (createdByUser)
      // This is the userId needed for sticky notes
      String? userId = user['createdByUser']?.toString();
      
      if (userId != null && userId.isNotEmpty) {
        debugPrint('✅ Got manager userId: $userId');
        return userId;
      }

      // Fallback: If createdByUser is not available, use the partner's own ID
      // This should rarely happen in production
      userId = user['_id']?.toString();
      
      if (userId != null && userId.isNotEmpty) {
        debugPrint('⚠️ Using partner ID as fallback: $userId');
        return userId;
      }

      debugPrint('❌ No userId found in user data');
      return null;
    } catch (e) {
      debugPrint('❌ Error getting userId: $e');
      return null;
    }
  }

  /// Get partner's own ID (_id field)
  static Future<String?> getOwnPartnerId() async {
    try {
      final user = await getUser();
      if (user == null) return null;
      
      final partnerId = user['_id']?.toString();
      if (partnerId != null) {
        debugPrint('✅ Got own partner ID: $partnerId');
        return partnerId;
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Error getting own partner ID: $e');
      return null;
    }
  }

  /// Get partner's name
  static Future<String?> getPartnerName() async {
    try {
      final user = await getUser();
      if (user == null) return null;
      return user['name']?.toString();
    } catch (e) {
      debugPrint('❌ Error getting partner name: $e');
      return null;
    }
  }

  /// Get partner's email
  static Future<String?> getPartnerEmail() async {
    try {
      final user = await getUser();
      if (user == null) return null;
      return user['email']?.toString();
    } catch (e) {
      debugPrint('❌ Error getting partner email: $e');
      return null;
    }
  }

  // ========= CLEAR ALL DATA =========

  /// Clear all stored data (logout)
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    debugPrint('🗑️ All data cleared');
  }

  // ========= DEBUG METHODS =========

  /// Print all stored data (for debugging)
  static Future<void> printAllData() async {
    try {
      final token = await getToken();
      final user = await getUser();
      final partnerId = await getPartnerId();
      final userId = await getUserId();
      final status = await getPartnerStatus();
      
      debugPrint('==================== STORAGE DATA ====================');
      debugPrint('Token: ${token != null ? 'EXISTS' : 'NULL'}');
      debugPrint('Partner ID (key): $partnerId');
      debugPrint('Partner Status: $status');
      debugPrint('User Data: $user');
      debugPrint('Manager User ID: $userId');
      debugPrint('====================================================');
    } catch (e) {
      debugPrint('❌ Error printing storage data: $e');
    }
  }
}