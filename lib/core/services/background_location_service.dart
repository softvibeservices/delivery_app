// lib/core/services/background_location_service.dart
// UPDATED - NO NOTIFICATIONS + Silent Background Tracking

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackgroundLocationService {
  // ========= INITIALIZE SERVICE (NO NOTIFICATION CHANNEL NEEDED) =========

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // Configure service - NO notification setup
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: false, // ✅ Changed to FALSE - silent background mode
        // ❌ Removed all notification-related parameters
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    debugPrint('✅ Background service initialized (SILENT MODE)');
  }

  // ========= SERVICE ENTRY POINT =========

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    debugPrint('🎯 Background service STARTED (SILENT)');

    Position? lastPosition;
    Timer? locationTimer;
    int updateCount = 0;

    // ❌ REMOVED: All notification code

    // Get and send location
    Future<void> updateLocation() async {
      try {
        debugPrint('📍 [BACKGROUND] Getting location...');

        // Get token
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');

        if (token == null || token.isEmpty) {
          debugPrint('❌ [BACKGROUND] No token, stopping');
          service.stopSelf();
          return;
        }

        // ✅ Get location with BEST ACCURACY
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
          timeLimit: const Duration(seconds: 15),
        );

        debugPrint('📍 [BACKGROUND] Got location: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}');
        debugPrint('📊 [BACKGROUND] Accuracy: ${position.accuracy.toStringAsFixed(1)}m');

        // Check distance filter (skip if moved less than 5m)
        if (lastPosition != null) {
          final distance = Geolocator.distanceBetween(
            lastPosition!.latitude,
            lastPosition!.longitude,
            position.latitude,
            position.longitude,
          );

          if (distance < 5) {
            debugPrint('⏭️ [BACKGROUND] Skipped: Only ${distance.toStringAsFixed(1)}m');
            return;
          }
        }

        lastPosition = position;
        updateCount++;

        // Get battery
        final battery = Battery();
        final batteryLevel = await battery.batteryLevel;

        // Send to backend
        final dio = Dio(BaseOptions(
          baseUrl: 'https://ice-inventory.vercel.app',
          connectTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ));

        final response = await dio.post(
          '/api/delivery/update-location',
          data: {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'accuracy': position.accuracy,
            'speed': position.speed,
            'batteryLevel': batteryLevel,
            'timestamp': position.timestamp.toIso8601String(),
          },
        );

        if (response.statusCode == 200) {
          debugPrint('✅ [BACKGROUND] Location sent (#$updateCount) - Battery: $batteryLevel%');
        } else {
          debugPrint('❌ [BACKGROUND] Failed: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('❌ [BACKGROUND] Error: $e');
      }
    }

    // ✅ Start periodic updates (30 seconds)
    locationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      debugPrint('⏰ [BACKGROUND] Timer tick #${timer.tick}');
      updateLocation();
    });

    // Initial update
    updateLocation();

    // Listen for stop command
    service.on('stopService').listen((event) {
      debugPrint('🛑 [BACKGROUND] Stop command received');
      locationTimer?.cancel();
      service.stopSelf();
    });
  }

  // iOS background handler
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  // ========= PUBLIC METHODS =========

  /// Start background tracking (SILENT - NO NOTIFICATIONS)
  static Future<void> startTracking() async {
    try {
      final service = FlutterBackgroundService();
      
      final isRunning = await service.isRunning();
      if (isRunning) {
        debugPrint('⚠️ Service already running, restarting...');
        service.invoke('stopService');
        await Future.delayed(const Duration(seconds: 2));
      }

      await service.startService();
      debugPrint('✅ Background service STARTED (SILENT MODE)');
    } catch (e) {
      debugPrint('❌ Error starting service: $e');
    }
  }

  /// Stop background tracking
  static Future<void> stopTracking() async {
    try {
      final service = FlutterBackgroundService();
      service.invoke('stopService');
      await Future.delayed(const Duration(seconds: 1));
      debugPrint('🛑 Background service STOPPED');
    } catch (e) {
      debugPrint('❌ Error stopping service: $e');
    }
  }

  /// Check if service is running
  static Future<bool> isRunning() async {
    try {
      final service = FlutterBackgroundService();
      return await service.isRunning();
    } catch (e) {
      return false;
    }
  }
}