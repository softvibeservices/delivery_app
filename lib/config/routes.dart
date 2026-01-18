// lib/config/routes.dart

import 'package:flutter/material.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/home_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/pending_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/otp_screen.dart';
import '../features/orders/screens/pending_orders_screen.dart';
import '../features/orders/screens/order_details_screen.dart';
import '../features/orders/models/order_model.dart';

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

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      // Auth Routes
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case welcome:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case otp:
        return MaterialPageRoute(builder: (_) => const OtpScreen());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case pending:
        return MaterialPageRoute(builder: (_) => const PendingApprovalScreen());

      // Order Routes
      case orders:
        return MaterialPageRoute(builder: (_) => const PendingOrdersScreen());
      case orderDetails:
        final order = settings.arguments as OrderModel;
        return MaterialPageRoute(
          builder: (_) => OrderDetailsScreen(order: order),
        );

      // Placeholder Routes
      case deliveredOrders:
        return MaterialPageRoute(builder: (_) => _placeholder('DELIVERED ORDERS'));
      case stickyNote:
        return MaterialPageRoute(builder: (_) => _placeholder('STICKY NOTE'));
      case goTo:
        return MaterialPageRoute(builder: (_) => _placeholder('GO TO'));
      case profile:
        return MaterialPageRoute(builder: (_) => _placeholder('PROFILE'));

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('Route ${settings.name} not found'),
            ),
          ),
        );
    }
  }

  static final Map<String, WidgetBuilder> routes = {
    splash: (_) => const SplashScreen(),
    welcome: (_) => const HomeScreen(),
    login: (_) => const LoginScreen(),
    otp: (_) => const OtpScreen(),
    register: (_) => const RegisterScreen(),
    pending: (_) => const PendingApprovalScreen(),
    orders: (_) => const PendingOrdersScreen(),
  };

  static Widget _placeholder(String title) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
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