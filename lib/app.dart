// lib/app.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/orders/providers/orders_provider.dart';
import 'features/orders/providers/delivered_orders_provider.dart';
import 'features/sticky_notes/providers/sticky_notes_provider.dart'; // ✅ ADD THIS
import 'features/sticky_notes/providers/sticky_note_form_provider.dart'; // ✅ ADD THIS

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => OrdersProvider()),
        ChangeNotifierProvider(create: (_) => DeliveredOrdersProvider()),
        ChangeNotifierProvider(create: (_) => StickyNotesProvider()), // ✅ ADD THIS
        ChangeNotifierProvider(create: (_) => StickyNoteFormProvider()), // ✅ ADD THIS
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