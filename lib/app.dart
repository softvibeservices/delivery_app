//lib\app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'features/auth/providers/auth_provider.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'Ice Cream Delivery Partner',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: AppRoutes.initial,
        routes: AppRoutes.routes,
      ),
    );
  }
}
