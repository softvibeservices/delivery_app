// lib/features/main_shell.dart
// IndexedStack shell — all 5 tabs are kept alive in memory.
// Screens are built once on first visit and never destroyed on tab switch.
// No API calls on every tab switch. Navigation is instant.

import 'package:flutter/material.dart';
import '/features/orders/screens/pending_orders_screen.dart';
import '/features/orders/screens/delivered_orders_screen.dart';
import '/features/sticky_notes/screens/sticky_notes_list_screen.dart';
import '/features/go_to/screens/go_to_screen.dart';
import '/features/profile/screens/profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // All screens instantiated once and kept alive by IndexedStack.
  static const List<Widget> _screens = [
    PendingOrdersScreen(),
    DeliveredOrdersScreen(),
    StickyNotesListScreen(),
    GoToScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      // IndexedStack keeps all screens alive — only the active index is painted.
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(Icons.assignment, 'Orders', 0, primary),
                _navItem(Icons.history, 'Delivered', 1, primary),
                _navItem(Icons.sticky_note_2, 'Notes', 2, primary),
                _navItem(Icons.directions, 'Go To', 3, primary),
                _navItem(Icons.person, 'Profile', 4, primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index, Color primary) {
    final active = _currentIndex == index;
    return InkWell(
      onTap: () {
        if (_currentIndex != index) {
          setState(() => _currentIndex = index);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? primary : Colors.grey, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                color: active ? primary : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}