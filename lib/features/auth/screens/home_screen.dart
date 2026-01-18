//lib\features\auth\screens\home_screen.dart

import 'package:flutter/material.dart';
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
            // ================= HERO IMAGE =================
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(
                          'https://lh3.googleusercontent.com/aida-public/AB6AXuDwpztP3hvbRTqlmzLeL2cxdI7yr9YeyMg81uCMQ-uRUXV0EHsLH-jk-1_TXWe96zqawWpSj3lkqKC9TmWxfOz9vD-6G-gs6qIOGj2c4eXNu-Oxl9psuRr_q_5wbvVY0asvjoVuFwQqsDGbA77wPSMM-187BPjQpTRhyRHt8Z4nL2V6Q5TfohIcMUshnCXebBmP0uQupX5DGKB9OT0tX4inJZcXmW0IBUacwdkFFa11r3PkoaZjDZQPXhyHVVezkRJYcIyxl-8qq51s',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                  // Gradient overlay (top → bottom)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            theme.scaffoldBackgroundColor,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ================= CONTENT =================
            Expanded(
              flex: 6,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      primary.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // -------- TEXT --------
                    Column(
                      children: [
                        const SizedBox(height: 24),
                        Text(
                          'Ready to Scoop?',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Join our fleet and bring the coolest treats to your city. Start delivering happiness today.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.grey.shade600,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    // -------- BUTTONS --------
                    Column(
                      children: [
                        const SizedBox(height: 32),

                        // LOGIN
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.login,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              elevation: 6,
                              shadowColor:
                                  primary.withValues(alpha: 0.25),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: const Text('Login'),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // REGISTER
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.register,
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primary,
                              side: BorderSide(color: primary, width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: const Text('Register'),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // SUPPORT
                        GestureDetector(
                          onTap: () {
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.help_outline,
                                size: 18,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Need help? Contact support',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ================= SAFE AREA INDICATOR =================
            Container(
              height: 32,
              alignment: Alignment.center,
              child: Container(
                width: 120,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}