// lib/core/services/location_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:battery_plus/battery_plus.dart';
import 'storage_service.dart';
import 'api_service.dart';
import 'background_location_service.dart';
import '../../config/api_endpoints.dart';

class LocationService {
  // ─── Singleton ────────────────────────────────────────────────────────────
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Timer? _locationTimer;
  Position? _lastPosition;
  bool _isTracking = false;
  final int _updateInterval = 30; // seconds
  final Battery _battery = Battery();
  final List<Map<String, dynamic>> _offlineQueue = [];

  bool get isTracking => _isTracking;
  int get queueSize => _offlineQueue.length;

  // ─── PERMISSIONS ──────────────────────────────────────────────────────────

  Future<bool> hasAlwaysPermission() async {
    final status = await Permission.locationAlways.status;
    debugPrint('📍 Always permission: $status');
    return status.isGranted;
  }

  Future<bool> requestAlwaysPermission() async {
    debugPrint('📍 Requesting ALWAYS location permission...');

    var status = await Permission.location.request();
    if (!status.isGranted) {
      debugPrint('❌ While-using permission denied');
      return false;
    }

    status = await Permission.locationAlways.request();

    if (status.isGranted) {
      debugPrint('✅ ALWAYS permission granted');
      return true;
    } else if (status.isPermanentlyDenied) {
      debugPrint('❌ ALWAYS permission permanently denied');
      await openAppSettings();
      return false;
    }

    return false;
  }

  Future<bool> isGpsEnabled() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    debugPrint('📍 GPS enabled: $enabled');
    return enabled;
  }

  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  // ─── TRACKING ─────────────────────────────────────────────────────────────

  Future<bool> startTracking() async {
    if (_isTracking) {
      debugPrint('⚠️ Already tracking');
      return true;
    }

    if (!await isGpsEnabled()) {
      debugPrint('❌ GPS is disabled');
      return false;
    }

    if (!await hasAlwaysPermission()) {
      debugPrint('❌ Need ALWAYS permission');
      final granted = await requestAlwaysPermission();
      if (!granted) return false;
    }

    _isTracking = true;
    debugPrint('🎯 Started location tracking');

    _loadOfflineQueue();

    _locationTimer = Timer.periodic(
      Duration(seconds: _updateInterval),
      (_) => _updateLocation(),
    );

    await BackgroundLocationService.startTracking();

    // Fire an immediate update.
    _updateLocation();

    return true;
  }

  Future<void> stopTracking() async {
    if (!_isTracking) return;

    _locationTimer?.cancel();
    _locationTimer = null;

    await BackgroundLocationService.stopTracking();

    _isTracking = false;
    _lastPosition = null;

    debugPrint('🛑 Stopped location tracking');
  }

  Future<void> _updateLocation() async {
    try {
      debugPrint('📍 [FG] Getting location...');

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 15),
      );

      if (_lastPosition != null) {
        final distance = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        if (distance < 5) {
          debugPrint(
            '⏭️ [FG] Skipped: only ${distance.toStringAsFixed(1)}m moved',
          );
          return;
        }
      }

      _lastPosition = position;

      final batteryLevel = await _battery.batteryLevel;

      final locationData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'batteryLevel': batteryLevel,
        'timestamp': position.timestamp.toIso8601String(),
      };

      debugPrint(
        '✅ [FG] ${position.latitude.toStringAsFixed(6)}, '
        '${position.longitude.toStringAsFixed(6)} | '
        'accuracy: ${position.accuracy.toStringAsFixed(1)}m | '
        'battery: $batteryLevel%',
      );

      await _sendLocationToBackend(locationData);
    } catch (e) {
      debugPrint('❌ [FG] Error: $e');
    }
  }

  Future<void> _sendLocationToBackend(
    Map<String, dynamic> locationData,
  ) async {
    try {
      // Use the shared ApiService singleton — interceptor adds auth header.
      final response = await ApiService().dio.post(
        ApiEndpoints.updateLocation,
        data: locationData,
      );

      if (response.statusCode == 200) {
        debugPrint('✅ [FG] Location sent');
        if (_offlineQueue.isNotEmpty) await _sendQueuedLocations();
      }
    } catch (e) {
      debugPrint('❌ [FG] Send failed, queuing: $e');
      _addToOfflineQueue(locationData);
    }
  }

  // ─── OFFLINE QUEUE (via StorageService — no direct SharedPreferences) ─────

  void _addToOfflineQueue(Map<String, dynamic> locationData) {
    if (_offlineQueue.length >= 100) _offlineQueue.removeAt(0);
    _offlineQueue.add(locationData);
    _saveOfflineQueue();
    debugPrint('📥 Location queued (${_offlineQueue.length} pending)');
  }

  Future<void> _sendQueuedLocations() async {
    if (_offlineQueue.isEmpty) return;
    debugPrint('📤 Sending ${_offlineQueue.length} queued locations...');

    final toSend = List<Map<String, dynamic>>.from(_offlineQueue);

    for (final data in toSend) {
      try {
        final response = await ApiService().dio.post(
          ApiEndpoints.updateLocation,
          data: data,
        );
        if (response.statusCode == 200) {
          _offlineQueue.remove(data);
        }
      } catch (e) {
        debugPrint('❌ Failed to send queued location, stopping flush');
        break;
      }
    }

    _saveOfflineQueue();
    debugPrint('📊 Queue remaining: ${_offlineQueue.length}');
  }

  void _saveOfflineQueue() {
    // StorageService.saveLocationQueue is async but we fire-and-forget here
    // since queuing is best-effort and we don't want to block the timer.
    StorageService.saveLocationQueue(_offlineQueue);
  }

  void _loadOfflineQueue() {
    // getLocationQueue() is synchronous after StorageService.init().
    final saved = StorageService.getLocationQueue();
    _offlineQueue
      ..clear()
      ..addAll(saved);
    debugPrint('📥 Loaded ${_offlineQueue.length} queued locations');
  }

  Future<void> clearOfflineQueue() async {
    _offlineQueue.clear();
    await StorageService.clearLocationQueue();
    debugPrint('🗑️ Offline queue cleared');
  }

  // ─── ONE-SHOT (for testing) ───────────────────────────────────────────────

  Future<Position?> getLocationOnce() async {
    try {
      if (!await hasAlwaysPermission()) await requestAlwaysPermission();

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      debugPrint(
        '📍 Test: ${position.latitude}, ${position.longitude} '
        '(±${position.accuracy.toStringAsFixed(0)}m)',
      );
      return position;
    } catch (e) {
      debugPrint('❌ getLocationOnce error: $e');
      return null;
    }
  }
}