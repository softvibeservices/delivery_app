//lib\config\theme.dart

import 'package:flutter/material.dart';

class AppTheme {
  // 🎨 Brand Colors
  static const Color primaryColor = Color(0xFF4FC3F7); // Ice blue
  static const Color secondaryColor = Color(0xFFFFA726); // Warm orange
  static const Color backgroundColor = Color(0xFFF9F9F9);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFF44336);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundColor,
      primaryColor: primaryColor,

      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        error: errorColor,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.black,
      ),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
