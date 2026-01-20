// lib/features/orders/widgets/bottom_nav_bar.dart

import 'package:flutter/material.dart';
import '../screens/pending_orders_screen.dart';
import '../screens/delivered_orders_screen.dart';
import '../../sticky_notes/screens/sticky_notes_list_screen.dart'; // ✅ NEW

class OrdersBottomNavBar extends StatelessWidget {
  final int selectedIndex;

  const OrdersBottomNavBar({super.key, required this.selectedIndex});

  void _onNavItemTapped(BuildContext context, int index) {
    // Don't navigate if already on the selected screen
    if (index == selectedIndex) return;

    switch (index) {
      case 0:
        // Current Orders
        if (selectedIndex != 0) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const PendingOrdersScreen(),
            ),
            (route) => false,
          );
        }
        break;
      case 1:
        // Delivered Orders
        if (selectedIndex != 1) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const DeliveredOrdersScreen(),
            ),
            (route) => false,
          );
        }
        break;
      case 2:
        // Sticky Notes ✅ UPDATED
        if (selectedIndex != 2) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const StickyNotesListScreen(),
            ),
            (route) => false,
          );
        }
        break;
      case 3:
        // Go to Customer
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Go to Customer screen - Coming soon')),
        );
        break;
      case 4:
        // Profile
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile screen - Coming soon')),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
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
              _navItem(
                context,
                Icons.assignment,
                'Current\nOrders',
                0,
                selectedIndex == 0,
                primary,
              ),
              _navItem(
                context,
                Icons.history,
                'Delivered\nOrders',
                1,
                selectedIndex == 1,
                primary,
              ),
              _navItem(
                context,
                Icons.sticky_note_2,
                'Sticky\nNotes',
                2,
                selectedIndex == 2,
                primary,
              ),
              _navItem(
                context,
                Icons.directions,
                'Go to\nCustomer',
                3,
                selectedIndex == 3,
                primary,
              ),
              _navItem(
                context,
                Icons.person,
                'Profile',
                4,
                selectedIndex == 4,
                primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    IconData icon,
    String label,
    int index,
    bool active,
    Color primary,
  ) {
    return InkWell(
      onTap: () => _onNavItemTapped(context, index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? primary : Colors.grey, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                color: active ? primary : Colors.grey,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
