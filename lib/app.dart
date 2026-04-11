// lib/app.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'core/services/api_service.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/orders/providers/orders_provider.dart';
import 'features/orders/providers/delivered_orders_provider.dart';
import 'features/sticky_notes/providers/sticky_notes_provider.dart';
import 'features/sticky_notes/providers/sticky_note_form_provider.dart';
import 'features/go_to/providers/go_to_provider.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ── ApiService singleton registered first so all providers can read it.
        Provider<ApiService>(create: (_) => ApiService()),

        // ── All feature providers receive the same ApiService instance.
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(
          create: (ctx) => OrdersProvider(ctx.read<ApiService>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => DeliveredOrdersProvider(ctx.read<ApiService>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => StickyNotesProvider(ctx.read<ApiService>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => StickyNoteFormProvider(ctx.read<ApiService>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => GoToProvider(ctx.read<ApiService>()),
        ),
      ],
      child: MaterialApp(
        title: 'Ice Cream Delivery Partner',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: AppRoutes.initial,
        // onGenerateRoute is the only routing mechanism — the routes map has
        // been removed to avoid the dual-routing conflict (Group 3).
        onGenerateRoute: AppRoutes.onGenerateRoute,
      ),
    );
  }
}