// lib/features/main_shell.dart

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

  // Keep screens alive (DO NOT CHANGE)
  final List<Widget> _screens = const [
    PendingOrdersScreen(key: PageStorageKey('pending_orders')),
    DeliveredOrdersScreen(key: PageStorageKey('delivered_orders')),
    StickyNotesListScreen(key: PageStorageKey('sticky_notes')),
    GoToScreen(key: PageStorageKey('go_to')),
    ProfileScreen(key: PageStorageKey('profile')),
  ];

  void _onTap(int index) {
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
    }
  }

  // BACK BUTTON HANDLING
  void _onPopInvoked(bool didPop) {
    if (didPop) return;

    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
    } else {
      if (Theme.of(context).platform == TargetPlatform.android) {
        SystemNavigator.pop();
      }
    }
  }

  bool _isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = _isTablet(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _onPopInvoked(didPop),
      child: Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              if (isTablet)
                _SideNavRail(
                  currentIndex: _currentIndex,
                  onTap: _onTap,
                ),
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: _screens
                      .map((screen) =>
                          RepaintBoundary(child: screen))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: isTablet
            ? null
            : _BottomNav(
                currentIndex: _currentIndex,
                onTap: _onTap,
                theme: theme,
              ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// 🔻 BOTTOM NAV (PHONES)
////////////////////////////////////////////////////////////

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.theme,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final ThemeData theme;

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
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (index) {
              final active = currentIndex == index;
              final (outlinedIcon, filledIcon, label) = _items[index];

              return _NavItem(
                icon: active ? filledIcon : outlinedIcon,
                label: label,
                active: active,
                onTap: () => onTap(index),
              );
            }),
          ),
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// 🔻 NAV ITEM (ANIMATED)
////////////////////////////////////////////////////////////

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: active ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                size: 22,
                color: active
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight:
                    active ? FontWeight.bold : FontWeight.w500,
                color: active
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// 🔻 SIDE NAV (TABLETS)
////////////////////////////////////////////////////////////

class _SideNavRail extends StatelessWidget {
  const _SideNavRail({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
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
    final theme = Theme.of(context);

    return NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      backgroundColor: theme.colorScheme.surface,
      selectedIconTheme: IconThemeData(
        color: theme.colorScheme.primary,
      ),
      unselectedIconTheme: IconThemeData(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      selectedLabelTextStyle: TextStyle(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      destinations: _items.map((item) {
        final (outlinedIcon, filledIcon, label) = item;
        return NavigationRailDestination(
          icon: Icon(outlinedIcon),
          selectedIcon: Icon(filledIcon),
          label: Text(label),
        );
      }).toList(),
    );
  }
}