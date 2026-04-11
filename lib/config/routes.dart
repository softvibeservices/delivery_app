// lib/config/routes.dart

import 'package:flutter/material.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/home_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/pending_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/otp_screen.dart';
import '../features/orders/screens/order_details_screen.dart';
import '../features/orders/models/order_model.dart';
import '../features/main_shell.dart';

class AppRoutes {
  AppRoutes._();

  static const String initial = splash;

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const String splash = '/splash';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String register = '/register';
  static const String otp = '/otp';
  static const String pending = '/pending';

  // ── Main shell (all tabs live inside here) ────────────────────────────────
  static const String main = '/main';

  // ── Deep-link into a specific order detail (pushed on top of shell) ───────
  static const String orderDetails = '/order-details';

  // 'orders' kept as an alias that redirects to the shell so any existing
  // push calls (e.g. in auth flow) still work without needing an update.
  static const String orders = '/main';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      // Auth
      case splash:
        return _route(const SplashScreen());
      case welcome:
        return _route(const HomeScreen());
      case login:
        return _route(const LoginScreen());
      case otp:
        return _route(const OtpScreen());
      case register:
        return _route(const RegisterScreen());
      case pending:
        return _route(const PendingApprovalScreen());

      // Main app shell
      case main:
        return _route(const MainShell());

      // Order details is pushed on top of the shell, not inside it.
      case orderDetails:
        final order = settings.arguments as OrderModel;
        return _route(OrderDetailsScreen(order: order));

      default:
        return _route(
          Scaffold(
            body: Center(
              child: Text('Route "${settings.name}" not found'),
            ),
          ),
        );
    }
  }

  static MaterialPageRoute<dynamic> _route(Widget page) {
    return MaterialPageRoute(builder: (_) => page);
  }
}