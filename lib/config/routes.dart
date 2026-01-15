//lib\config\routes.dart
import 'package:flutter/material.dart';

// Auth screens
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/home_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/pending_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/otp_screen.dart';

class AppRoutes {
  /// Initial route
  static const String initial = splash;

  // ================= AUTH =================
  static const String splash = '/splash';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String register = '/register';
  static const String otp = '/otp';
  static const String pending = '/pending';

  // ================= MAIN =================
  static const String orders = '/orders';
  static const String orderDetails = '/order-details';
  static const String deliveredOrders = '/delivered-orders';
  static const String stickyNote = '/sticky-note';
  static const String goTo = '/go-to';
  static const String profile = '/profile';

  static final Map<String, WidgetBuilder> routes = {
    // ---------- AUTH ----------
    splash: (_) => const SplashScreen(),
    welcome: (_) => const HomeScreen(), // ✅ REAL WELCOME UI
    login: (_) => const LoginScreen(),
    otp: (_) => const OtpScreen(),
    register: (_) => const RegisterScreen(),
    pending: (_) => const PendingApprovalScreen(),

    // ---------- MAIN ----------
    orders: (_) => _placeholder('PENDING ORDERS'),
    orderDetails: (_) => _placeholder('ORDER DETAILS'),
    deliveredOrders: (_) => _placeholder('DELIVERED ORDERS'),
    stickyNote: (_) => _placeholder('STICKY NOTE'),
    goTo: (_) => _placeholder('GO TO'),
    profile: (_) => _placeholder('PROFILE'),
  };

  static Widget _placeholder(String title) {
    return Scaffold(
      body: Center(
        child: Text(
          '$title SCREEN\n(Coming next)',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
