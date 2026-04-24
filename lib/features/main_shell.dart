// lib/features/main_shell.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '/config/routes.dart';
import '/features/auth/providers/auth_provider.dart';
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

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;

  // Keep screens alive (DO NOT CHANGE)
  final List<Widget> _screens = const [
    PendingOrdersScreen(key: PageStorageKey('pending_orders')),
    DeliveredOrdersScreen(key: PageStorageKey('delivered_orders')),
    StickyNotesListScreen(key: PageStorageKey('sticky_notes')),
    GoToScreen(key: PageStorageKey('go_to')),
    ProfileScreen(key: PageStorageKey('profile')),
  ];

  @override
  void initState() {
    super.initState();

    // ── FIX: lifecycle observer ───────────────────────────────────────────
    // Registers this widget to receive app lifecycle events.
    // didChangeAppLifecycleState() calls checkAccountStatus() every time
    // the app comes back to the foreground. If the user's account was
    // deleted while the app was backgrounded, they are kicked out
    // immediately on return rather than waiting for the next API call.
    WidgetsBinding.instance.addObserver(this);

    // ── FIX: auth-status listener ─────────────────────────────────────────
    // Attaches after the first frame so context.read() is safe.
    // Whenever AuthProvider notifies, _handleAuthChange checks whether the
    // user is still authenticated and navigates to /welcome if not.
    // This is what actually moves the user off the MainShell when either:
    //   • the API interceptor fires a 401/403-account-gone force-logout, or
    //   • checkAccountStatus() detects the account was deleted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().addListener(_handleAuthChange);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Safe to call even if addListener hasn't fired yet — ChangeNotifier
    // ignores removeListener for a callback that was never added.
    context.read<AuthProvider>().removeListener(_handleAuthChange);
    super.dispose();
  }

  // ── Auth change handler ──────────────────────────────────────────────────

  void _handleAuthChange() {
    if (!mounted) return;
    final status = context.read<AuthProvider>().status;
    if (status != AuthStatus.authenticated) {
      debugPrint('🔐 MainShell: auth status changed to $status — navigating to /welcome');
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.welcome,
        (route) => false,
      );
    }
  }

  // ── App lifecycle ────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-validate with the backend every time the user opens the app.
      // Non-fatal network errors inside checkAccountStatus() are swallowed
      // so an offline user is not incorrectly kicked out.
      debugPrint('📱 MainShell: app resumed — re-checking account status');
      context.read<AuthProvider>().checkAccountStatus();
    }
  }

  // ── Navigation ───────────────────────────────────────────────────────────

  void _onTap(int index) {
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
    }
  }

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