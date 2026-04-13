// lib/core/services/background_location_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_endpoints.dart';

const _tokenKey = 'auth_token';
const _lastOrderIdsKey = 'bg_last_order_ids';

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

    debugPrint('✅ Background service initialised (silent + order polling)');
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

    // ── Show a local notification from inside the background isolate ──────
    // Declared BEFORE the functions that call it.
    Future<void> showLocalNotification({
      required int id,
      required String title,
      required String body,
    }) async {
      try {
        final plugin = FlutterLocalNotificationsPlugin();

        const androidInit =
            AndroidInitializationSettings('@mipmap/ic_launcher');
        await plugin.initialize(
          const InitializationSettings(android: androidInit),
        );

        await plugin.show(
          id,
          title,
          body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'new_orders',
              'New Orders',
              channelDescription:
                  'Notifications for new delivery assignments',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
        debugPrint('🔔 [BG] Notification shown: $title');
      } catch (e) {
        debugPrint('❌ [BG] Failed to show notification: $e');
      }
    }

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

    // ── Order polling ─────────────────────────────────────────────────────
    Future<void> checkForNewOrders(
        SharedPreferences prefs, Dio dio) async {
      try {
        debugPrint('📦 [BG] Checking for new orders...');

        final response = await dio.get(
          ApiEndpoints.pendingOrders,
          queryParameters: {'onlyUnsettled': 'true'},
        );

        if (response.statusCode != 200) return;

        final List<dynamic> rawData = response.data is List
            ? response.data as List<dynamic>
            : (response.data['orders'] as List<dynamic>? ?? []);

        final currentIds =
            rawData.map((o) => o['_id']?.toString() ?? '').toSet();

        final lastIdsJson = prefs.getString(_lastOrderIdsKey);
        final Set<String> lastIds = lastIdsJson != null
            ? Set<String>.from(json.decode(lastIdsJson) as List)
            : {};

        final newIds = currentIds.difference(lastIds);

        if (newIds.isNotEmpty) {
          debugPrint('🆕 [BG] ${newIds.length} new order(s) detected');

          for (final orderId in newIds) {
            final orderData = rawData.firstWhere(
              (o) => o['_id']?.toString() == orderId,
              orElse: () => <String, dynamic>{},
            );

            final customerName =
                (orderData as Map<String, dynamic>)['customerName']
                        ?.toString() ??
                    'Customer';
            final shopName =
                orderData['shopName']?.toString() ?? '';

            await showLocalNotification(
              id: orderId.hashCode,
              title: 'New Order Available',
              body: shopName.isNotEmpty
                  ? 'New order for $shopName — check the app'
                  : 'New order for $customerName — check the app',
            );
          }
        } else {
          debugPrint('✅ [BG] No new orders');
        }

        await prefs.setString(
            _lastOrderIdsKey, json.encode(currentIds.toList()));
      } catch (e) {
        debugPrint('❌ [BG] Order check error: $e');
      }
    }

    // ── Run immediately on service start ──────────────────────────────────
    Future<void> tick() async {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);

      if (token == null || token.isEmpty) {
        debugPrint('❌ [BG] No token — stopping service');
        locationTimer?.cancel();
        service.stopSelf();
        return;
      }

      final dio = buildDio(token);

      await Future.wait([
        updateLocation(dio),
        checkForNewOrders(prefs, dio),
      ]);
    }

    // Initial run.
    await tick();

    // Periodic timer every 30 seconds.
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