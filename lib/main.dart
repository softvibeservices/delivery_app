// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'core/services/background_location_service.dart';
import 'app.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  
  // ✅ UPDATED: Match native splash background color
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFFE0F2FE), // ✅ Match native splash color
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFE0F2FE), // ✅ Match native splash color
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  await BackgroundLocationService.initialize();
  
  runApp(const App());
}