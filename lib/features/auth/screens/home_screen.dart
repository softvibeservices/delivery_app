// lib/features/auth/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/routes.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Hero Image ──────────────────────────────────────────────
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuDwpztP3hvbRTqlmzLeL2cxdI7yr9YeyMg81uCMQ-uRUXV0EHsLH-jk-1_TXWe96zqawWpSj3lkqKC9TmWxfOz9vD-6G-gs6qIOGj2c4eXNu-Oxl9psuRr_q_5wbvVY0asvjoVuFwQqsDGbA77wPSMM-187BPjQpTRhyRHt8Z4nL2V6Q5TfohIcMUshnCXebBmP0uQupX5DGKB9OT0tX4inJZcXmW0IBUacwdkFFa11r3PkoaZjDZQPXhyHVVezkRJYcIyxl-8qq51s',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: primary.withValues(alpha: 0.08),
                      child: Center(
                        child: Icon(
                          Icons.icecream,
                          size: 80,
                          color: primary.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          theme.scaffoldBackgroundColor.withValues(alpha: 0.95),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Content ─────────────────────────────────────────────────
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Ready to Scoop?',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Join our fleet and bring the coolest treats to your city. Start delivering happiness today.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.grey.shade600,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    _ActionButton(
                      label: 'Login',
                      isPrimary: true,
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRoutes.login,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ActionButton(
                      label: 'Register',
                      isPrimary: false,
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRoutes.register,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // ── "Need help?" support button ──────────────────────
                    TextButton.icon(
                      onPressed: () => _showSupportDialog(context),
                      icon: Icon(
                        Icons.help_outline,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      label: Text(
                        'Need help? Contact support',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSupportDialog(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.support_agent, color: primary),
            const SizedBox(width: 12),
            const Text('Contact Support'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Need help? Reach out to us at:'),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => launchUrl(
                Uri.parse('mailto:support@softvibeservices.com'),
              ),
              child: Text(
                'support@softvibeservices.com',
                style: TextStyle(
                  color: primary,
                  decoration: TextDecoration.underline,
                  decorationColor: primary,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.isPrimary,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: isPrimary
          ? ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: primary.withValues(alpha: 0.25),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(label),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: BorderSide(color: primary, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(label),
            ),
    );
  }
}