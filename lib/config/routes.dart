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
      // ── Auth ──────────────────────────────────────────────────────────────
      case splash:
        return _slide(const SplashScreen());
      case welcome:
        return _slide(const HomeScreen());
      case login:
        return _slide(const LoginScreen());
      case otp:
        return _slide(const OtpScreen());
      case register:
        return _slide(const RegisterScreen());
      case pending:
        return _slide(const PendingApprovalScreen());

      // ── Main app shell ─────────────────────────────────────────────────────
      case main:
        return _slide(const MainShell());

      // ── Order details — pushed on top of the shell, not inside it ──────────
      case orderDetails:
        final order = settings.arguments as OrderModel;
        return _slideUp(OrderDetailsScreen(order: order));

      // ── Fallback ───────────────────────────────────────────────────────────
      // Previously this showed a "route not found" scaffold which caused the
      // Android back button to crash.  Now we redirect to the main shell so
      // the user never ends up on a broken screen.
      //
      // Unknown route names can arrive from:
      //   • Android system back button events leaking through PopScope
      //   • Deep links with unrecognised paths
      //   • Hot-restart artefacts in debug mode
      default:
        debugPrint(
          '⚠️ AppRoutes: unknown route "${settings.name}" — redirecting to /main',
        );
        return _slide(const MainShell());
    }
  }

  // ─── Route builders ───────────────────────────────────────────────────────

  /// Standard horizontal slide (used for all full-screen auth flows).
  static MaterialPageRoute<dynamic> _slide(Widget page) {
    return MaterialPageRoute(builder: (_) => page);
  }

  /// Bottom-sheet style slide-up for overlay screens (order details, etc.).
  static PageRouteBuilder<dynamic> _slideUp(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, _, a) => page,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (_, animation, a, child) {
        final tween = Tween(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }
}