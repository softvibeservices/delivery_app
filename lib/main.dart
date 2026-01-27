// lib/main.dart
// Initialize TRUE background service

import 'package:flutter/material.dart';
import 'core/services/background_location_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ Initialize TRUE background service
  await BackgroundLocationService.initialize();
  
  runApp(const App());
}