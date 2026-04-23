// lib/core/services/background_location_service.dart
//
// Changes from previous version:
//  - Token now read from FlutterSecureStorage (same as StorageService) instead
//    of SharedPreferences — fixes the 401 / 400 errors in the background isolate.
//  - checkForNewOrders() removed entirely — FCM handles new-order notifications
//    reliably. Keeping a polling fallback caused duplicate notifications and
//    the 400 errors visible in logs.
//  - Service now only does one thing in the background: send location updates.

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:dio/dio.dart';
import '../../config/api_endpoints.dart';

// Must match the key used by StorageService._tokenKey
const _secureTokenKey = 'auth_token';

// Secure storage config must match StorageService._secure exactly.
const _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

@pragma('vm:entry-point')
class BackgroundLocationService {
  // ─── INITIALIZE ───────────────────────────────────────────────────────────

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: false,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    debugPrint('✅ Background service initialised (location tracking only)');
  }

  // ─── SERVICE ENTRY POINT (separate Dart isolate) ──────────────────────────

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    debugPrint('🎯 Background service started');

    Position? lastPosition;
    Timer? locationTimer;
    int updateCount = 0;

    // ── Build a fresh Dio for this isolate ────────────────────────────────
    Dio buildDio(String token) => Dio(
          BaseOptions(
            baseUrl: ApiEndpoints.productionBaseUrl,
            connectTimeout: const Duration(seconds: 30),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          ),
        );

    // ── Location update ───────────────────────────────────────────────────
    Future<void> updateLocation(Dio dio) async {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
          timeLimit: const Duration(seconds: 15),
        );

        if (lastPosition != null) {
          final distance = Geolocator.distanceBetween(
            lastPosition!.latitude,
            lastPosition!.longitude,
            position.latitude,
            position.longitude,
          );
          if (distance < 5) {
            debugPrint(
                '⏭️ [BG] Skipped: ${distance.toStringAsFixed(1)}m moved');
            return;
          }
        }

        lastPosition = position;
        updateCount++;

        final batteryLevel = await Battery().batteryLevel;

        final response = await dio.post(
          ApiEndpoints.updateLocation,
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
          debugPrint(
              '✅ [BG] Location sent (#$updateCount) battery: $batteryLevel%');
        }
      } catch (e) {
        debugPrint('❌ [BG] Location error: $e');
      }
    }

    // ── Single tick: read token → send location ───────────────────────────
    Future<void> tick() async {
      // Read from FlutterSecureStorage — this is where StorageService stores
      // the auth token. SharedPreferences does NOT have the token.
      final token = await _secureStorage.read(key: _secureTokenKey);

      if (token == null || token.isEmpty) {
        debugPrint('❌ [BG] No token — stopping service');
        locationTimer?.cancel();
        service.stopSelf();
        return;
      }

      final dio = buildDio(token);
      await updateLocation(dio);
    }

    // Initial run immediately on service start.
    await tick();

    // Then every 30 seconds.
    locationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => tick(),
    );

    service.on('stopService').listen((event) {
      debugPrint('🛑 [BG] Stop command received');
      locationTimer?.cancel();
      service.stopSelf();
    });
  }

  // ─── iOS BACKGROUND ───────────────────────────────────────────────────────

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  // ─── PUBLIC CONTROLS ──────────────────────────────────────────────────────

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
      debugPrint('✅ Background service started');
    } catch (e) {
      debugPrint('❌ Error starting service: $e');
    }
  }

  static Future<void> stopTracking() async {
    try {
      final service = FlutterBackgroundService();
      service.invoke('stopService');
      await Future.delayed(const Duration(seconds: 1));
      debugPrint('🛑 Background service stopped');
    } catch (e) {
      debugPrint('❌ Error stopping service: $e');
    }
  }

  static Future<bool> isRunning() async {
    try {
      return await FlutterBackgroundService().isRunning();
    } catch (e) {
      return false;
    }
  }
}