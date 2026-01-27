// lib/core/services/background_location_service.dart
// FIXED - Compatible with Geolocator 11.0.0

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackgroundLocationService {
  static const notificationChannelId = 'location_tracking_channel';
  static const notificationId = 888;

  // ========= INITIALIZE SERVICE =========

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // Create notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'Location Tracking',
      description: 'Tracks delivery partner location in background',
      importance: Importance.low,
      playSound: false,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Configure service
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'Ice Cream Delivery',
        initialNotificationContent: 'Initializing location tracking...',
        foregroundServiceNotificationId: notificationId,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    debugPrint('✅ Background service initialized');
  }

  // ========= SERVICE ENTRY POINT =========

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    debugPrint('🎯 Background service STARTED');

    Position? lastPosition;
    Timer? locationTimer;
    int updateCount = 0;

    // Notification plugin
    final FlutterLocalNotificationsPlugin notifications =
        FlutterLocalNotificationsPlugin();

    void updateNotification(String content) {
      notifications.show(
        notificationId,
        '🚚 Ice Cream Delivery',
        content,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            notificationChannelId,
            'Location Tracking',
            icon: 'ic_launcher',
            ongoing: true,
            priority: Priority.low,
            importance: Importance.low,
            playSound: false,
            enableVibration: false,
          ),
        ),
      );
    }

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

        // Check distance filter
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
          debugPrint('✅ [BACKGROUND] Location sent (#$updateCount)');
          
          final now = DateTime.now();
          final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
          
          updateNotification(
            '📍 Active • Last: $timeStr • Battery: $batteryLevel% • Acc: ${position.accuracy.toStringAsFixed(0)}m',
          );
        } else {
          debugPrint('❌ [BACKGROUND] Failed: ${response.statusCode}');
          updateNotification('⚠️ Tracking (waiting for network)');
        }
      } catch (e) {
        debugPrint('❌ [BACKGROUND] Error: $e');
        updateNotification('⚠️ Tracking (GPS error)');
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

    // Bring to foreground
    service.invoke('update');
  }

  // iOS background handler
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  // ========= PUBLIC METHODS =========

  /// Start background tracking
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
      debugPrint('✅ Background service STARTED');
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