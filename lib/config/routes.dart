//lib\config\routes.dart
import 'package:flutter/material.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/home_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/pending_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/otp_screen.dart';
import '../features/orders/screens/pending_orders_screen.dart';

class AppRoutes {
  static const String initial = splash;

  // Auth Screens
  static const String splash = '/splash';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String register = '/register';
  static const String otp = '/otp';
  static const String pending = '/pending';

  // Main Screens
  static const String orders = '/orders';
  static const String orderDetails = '/order-details';
  static const String deliveredOrders = '/delivered-orders';
  static const String stickyNote = '/sticky-note';
  static const String goTo = '/go-to';
  static const String profile = '/profile';

  static final Map<String, WidgetBuilder> routes = {
    // Auth
    splash: (_) => const SplashScreen(),
    welcome: (_) => const HomeScreen(),
    login: (_) => const LoginScreen(),
    otp: (_) => const OtpScreen(),
    register: (_) => const RegisterScreen(),
    pending: (_) => const PendingApprovalScreen(),

    // Main
    orders: (_) => const PendingOrdersScreen(),
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
