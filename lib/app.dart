// lib/app.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/orders/providers/orders_provider.dart';
import 'features/orders/providers/delivered_orders_provider.dart';
import 'features/sticky_notes/providers/sticky_notes_provider.dart';
import 'features/sticky_notes/providers/sticky_note_form_provider.dart';
import 'features/go_to/providers/go_to_provider.dart'; // ✅ NEW

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => OrdersProvider()),
        ChangeNotifierProvider(create: (_) => DeliveredOrdersProvider()),
        ChangeNotifierProvider(create: (_) => StickyNotesProvider()),
        ChangeNotifierProvider(create: (_) => StickyNoteFormProvider()),
        ChangeNotifierProvider(create: (_) => GoToProvider()), // ✅ NEW
      ],
      child: MaterialApp(
        title: 'Ice Cream Delivery Partner',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: AppRoutes.initial,
        onGenerateRoute: AppRoutes.onGenerateRoute,
        routes: AppRoutes.routes,
      ),
    );
  }
}