import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/routes.dart';
import '../providers/auth_provider.dart';

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await auth.initialize();
              if (auth.status == AuthStatus.authenticated) {
                Navigator.pushReplacementNamed(context, AppRoutes.orders);
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_empty,
                  size: 96, color: primary),
              const SizedBox(height: 16),
              const Text(
                'Pending Approval',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your account is under review.\nYou will be able to login once approved.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  await auth.logout();
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.login,
                    (_) => false,
                  );
                },
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
