// lib/features/main_shell.dart
// IndexedStack shell — all 5 tabs are kept alive in memory.
// Screens are built once on first visit and never destroyed on tab switch.
//
// BACK BUTTON HANDLING (Android):
//   • If not on tab 0 → switch back to tab 0 (Orders).
//   • If already on tab 0 → minimize the app (SystemNavigator.pop).
//   This prevents the "/route not found" error that occurred when Flutter tried
//   to pop a route that didn't exist below the shell.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // ─── BACK BUTTON ──────────────────────────────────────────────────────────
  //
  // canPop: false — we always intercept. Flutter will never pop the shell off
  // the stack automatically; we decide what to do.
  void _onPopInvoked(bool didPop) {
    if (didPop) return; // already handled (shouldn't happen with canPop:false)

    if (_currentIndex != 0) {
      // Not on home tab → go back to Orders tab.
      setState(() => _currentIndex = 0);
    } else {
      // Already on Orders → minimize the app.
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _onPopInvoked(didPop),
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: _BottomNav(
          currentIndex: _currentIndex,
          primary: primary,
          onTap: (index) {
            if (_currentIndex != index) {
              setState(() => _currentIndex = index);
            }
          },
        ),
      ),
    );
  }
}

// ─── Bottom navigation bar extracted to its own widget ───────────────────────
// Using a separate StatelessWidget means the shell body never rebuilds just
// because we tapped a tab — only the IndexedStack's active child repaints.

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.currentIndex,
    required this.primary,
    required this.onTap,
  });

  final int currentIndex;
  final Color primary;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.assignment_outlined, Icons.assignment, 'Orders'),
    (Icons.history_outlined, Icons.history, 'Delivered'),
    (Icons.sticky_note_2_outlined, Icons.sticky_note_2, 'Notes'),
    (Icons.directions_outlined, Icons.directions, 'Go To'),
    (Icons.person_outline, Icons.person, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (index) {
              final active = currentIndex == index;
              final (outlinedIcon, filledIcon, label) = _items[index];
              return _NavItem(
                icon: active ? filledIcon : outlinedIcon,
                label: label,
                active: active,
                primary: primary,
                onTap: () => onTap(index),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.primary,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: active ? primary : Colors.grey.shade500,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    active ? FontWeight.bold : FontWeight.w500,
                color: active ? primary : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}