// lib/core/services/location_service.dart
// FIXED - Compatible with Geolocator 11.0.0

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'background_location_service.dart';
import '../../config/api_endpoints.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Timer? _locationTimer;
  Position? _lastPosition;
  bool _isTracking = false;
  int _updateInterval = 5;
  final Battery _battery = Battery();
  final List<Map<String, dynamic>> _offlineQueue = [];

  bool get isTracking => _isTracking;
  int get queueSize => _offlineQueue.length;

  // ========= PERMISSION METHODS =========

  Future<bool> hasAlwaysPermission() async {
    final status = await Permission.locationAlways.status;
    debugPrint('📍 Always permission: $status');
    return status.isGranted;
  }

  Future<bool> requestAlwaysPermission() async {
    debugPrint('📍 Requesting ALWAYS location permission...');

    var status = await Permission.location.request();
    if (!status.isGranted) {
      debugPrint('❌ While using permission denied');
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

  // ========= TRACKING METHODS =========

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
      if (!granted) {
        return false;
      }
    }

    _isTracking = true;
    debugPrint('🎯 Started location tracking');

    await _loadOfflineQueue();

    // ✅ Start foreground updates
    _locationTimer = Timer.periodic(
      Duration(seconds: _updateInterval),
      (_) => _updateLocation(),
    );

    // ✅ Start background service
    await BackgroundLocationService.startTracking();

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
      await _adjustIntervalBasedOnBattery();

      debugPrint('📍 Getting foreground location (HIGH ACCURACY)...');

      // ✅ Use BEST accuracy (compatible with Geolocator 11.0.0)
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 15),
      );

      // Distance filter
      if (_lastPosition != null) {
        final distance = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );

        if (distance < 5) {
          debugPrint('⏭️ Skipped: Moved only ${distance.toStringAsFixed(1)}m');
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

      debugPrint('✅ Foreground location: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}');
      debugPrint('📊 Accuracy: ${position.accuracy.toStringAsFixed(1)}m | Battery: $batteryLevel%');

      await _sendLocationToBackend(locationData);

    } catch (e) {
      debugPrint('❌ Error updating location: $e');
    }
  }

  Future<void> _sendLocationToBackend(Map<String, dynamic> locationData) async {
    try {
      final apiService = ApiService();
      
      final response = await apiService.dio.post(
        ApiEndpoints.updateLocation,
        data: locationData,
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Location sent successfully');
        
        if (_offlineQueue.isNotEmpty) {
          await _sendQueuedLocations();
        }
      }
    } catch (e) {
      debugPrint('❌ Error sending location: $e');
      await _addToOfflineQueue(locationData);
    }
  }

  // ========= OFFLINE QUEUE =========

  Future<void> _addToOfflineQueue(Map<String, dynamic> locationData) async {
    if (_offlineQueue.length >= 100) {
      _offlineQueue.removeAt(0);
    }
    
    _offlineQueue.add(locationData);
    await _saveOfflineQueue();
    
    debugPrint('📥 Location queued (${_offlineQueue.length} in queue)');
  }

  Future<void> _sendQueuedLocations() async {
    if (_offlineQueue.isEmpty) return;

    debugPrint('📤 Sending ${_offlineQueue.length} queued locations...');

    final apiService = ApiService();
    final locationsToSend = List<Map<String, dynamic>>.from(_offlineQueue);

    for (final locationData in locationsToSend) {
      try {
        final response = await apiService.dio.post(
          ApiEndpoints.updateLocation,
          data: locationData,
        );

        if (response.statusCode == 200) {
          _offlineQueue.remove(locationData);
          debugPrint('✅ Queued location sent');
        }
      } catch (e) {
        debugPrint('❌ Failed to send queued location');
        break;
      }
    }

    await _saveOfflineQueue();
    debugPrint('📊 Remaining in queue: ${_offlineQueue.length}');
  }

  Future<void> _saveOfflineQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = jsonEncode(_offlineQueue);
      await prefs.setString('location_queue', queueJson);
    } catch (e) {
      debugPrint('❌ Error saving queue: $e');
    }
  }

  Future<void> _loadOfflineQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString('location_queue');
      
      if (queueJson != null) {
        final List<dynamic> decoded = jsonDecode(queueJson);
        _offlineQueue.clear();
        _offlineQueue.addAll(decoded.cast<Map<String, dynamic>>());
        debugPrint('📥 Loaded ${_offlineQueue.length} queued locations');
      }
    } catch (e) {
      debugPrint('❌ Error loading queue: $e');
    }
  }

  Future<void> clearOfflineQueue() async {
    _offlineQueue.clear();
    await _saveOfflineQueue();
    debugPrint('🗑️ Offline queue cleared');
  }

  // ========= BATTERY OPTIMIZATION =========

  Future<void> _adjustIntervalBasedOnBattery() async {
    try {
      final batteryLevel = await _battery.batteryLevel;

      int newInterval;
      if (batteryLevel < 15) {
        newInterval = 10;
      } else if (batteryLevel < 20) {
        newInterval = 7;
      } else {
        newInterval = 5;
      }

      if (newInterval != _updateInterval) {
        _updateInterval = newInterval;
        debugPrint('🔋 Battery $batteryLevel% → Update interval: ${_updateInterval}s');
      }
    } catch (e) {
      debugPrint('❌ Error checking battery: $e');
    }
  }

  // ========= TEST METHODS =========

  Future<Position?> getLocationOnce() async {
    try {
      if (!await hasAlwaysPermission()) {
        await requestAlwaysPermission();
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      
      debugPrint('📍 Test location: ${position.latitude}, ${position.longitude}');
      debugPrint('📊 Test accuracy: ${position.accuracy}m');
      return position;
    } catch (e) {
      debugPrint('❌ Error: $e');
      return null;
    }
  }
}