//lib\features\auth\screens\splash_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import '../../../config/routes.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();

    // ✅ Remove native splash immediately when Flutter splash shows
    // This creates a seamless transition from native to Flutter splash
    FlutterNativeSplash.remove();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(
      begin: 0,
      end: -12,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _handleNavigation();
  }

  Future<void> _handleNavigation() async {
    final authProvider = context.read<AuthProvider>();

    authProvider.setContext(context);
    await authProvider.initialize();
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    switch (authProvider.status) {
      case AuthStatus.authenticated:
        Navigator.pushReplacementNamed(context, AppRoutes.orders);
        break;
      case AuthStatus.pending:
        Navigator.pushReplacementNamed(context, AppRoutes.welcome);
        break;
      case AuthStatus.rejected:
      case AuthStatus.unauthenticated:
      default:
        Navigator.pushReplacementNamed(context, AppRoutes.welcome);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.4,
            colors: [Color(0xFFE0F2FE), Color(0xFFFDF2F8), Color(0xFFFEFCE8)],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 80),

            AnimatedBuilder(
              animation: _floatAnimation,
              builder: (_, child) {
                return Transform.translate(
                  offset: Offset(0, _floatAnimation.value),
                  child: child,
                );
              },
              child: const _GlassLogoCard(),
            ),

            const SizedBox(height: 40),

            Column(
              children: [
                Text(
                  'Scoop & Go',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 4,
                  width: 48,
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'DELIVERY PARTNER',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    letterSpacing: 3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const Spacer(),

            Column(
              children: [
                const AnimatedLoaderBar(),
                const SizedBox(height: 12),
                Text(
                  'SYNCING COLD CHAIN',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),
            Container(
              height: 6,
              width: 140,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.08),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _GlassLogoCard extends StatelessWidget {
  const _GlassLogoCard();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: 260,
          width: 260,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primary.withOpacity(0.05),
          ),
        ),
        Container(
          height: 230,
          width: 230,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: primary.withOpacity(0.1)),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(48),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              height: 180,
              width: 180,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.45),
                borderRadius: BorderRadius.circular(48),
                border: Border.all(color: Colors.white.withOpacity(0.6)),
                boxShadow: [
                  BoxShadow(
                    color: primary.withOpacity(0.15),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(
                      Icons.icecream,
                      size: 96,
                      color: Color(0xFF2B8CEE),
                    ),
                  ),
                  Positioned(
                    bottom: -6,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: const Icon(
                        Icons.delivery_dining,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AnimatedLoaderBar extends StatefulWidget {
  const AnimatedLoaderBar({super.key});

  @override
  State<AnimatedLoaderBar> createState() => _AnimatedLoaderBarState();
}

class _AnimatedLoaderBarState extends State<AnimatedLoaderBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return SizedBox(
      width: 140,
      height: 4,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              return Positioned(
                left: (140 * _controller.value) - 60,
                child: Container(
                  width: 60,
                  height: 4,
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}