import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';

/// Premium order card with clear hierarchy, ripple feedback, and
/// animated status transitions.
class OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback? onTap;
  final VoidCallback? onActionTap;

  const OrderCard({
    super.key,
    required this.order,
    this.onTap,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EAED)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: primary.withValues(alpha: 0.08),
          highlightColor: primary.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header: Customer + Status ───────────────────────────
                _Header(order: order),

                const SizedBox(height: 12),

                // ── Info: Contact & Address ─────────────────────────────
                if (order.customerContact != null)
                  _InfoRow(
                    icon: Icons.phone_outlined,
                    text: order.customerContact!,
                  ),
                const SizedBox(height: 6),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  text: order.customerAddress,
                ),

                const SizedBox(height: 14),

                // ── Meta: Time + Items ──────────────────────────────────
                _MetaBar(order: order),

                const Divider(height: 24, thickness: 1),

                // ── Actions ─────────────────────────────────────────────
                _ActionBar(
                  primary: primary,
                  order: order,
                  onView: onTap,
                  onAction: onActionTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sub-widgets ───────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final OrderModel order;
  const _Header({required this.order});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar placeholder with initial
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _avatarColor(order.customerName),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            order.customerName.isNotEmpty
                ? order.customerName[0].toUpperCase()
                : '?',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Names
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.customerName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (order.shopName != null && order.shopName!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  order.shopName!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Order #${order.orderId}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // Animated status badge
        _StatusBadge(status: order.deliveryStatus),
      ],
    );
  }

  Color _avatarColor(String name) {
    final colors = [
      const Color(0xFF2B8CEE),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  (Color bg, Color fg, String label) get _theme {
    return switch (status) {
      'On the Way' => (
          Colors.blue.shade50,
          Colors.blue.shade700,
          'ON THE WAY'
        ),
      'Delivered' => (
          Colors.green.shade50,
          Colors.green.shade700,
          'DELIVERED'
        ),
      _ => (
          Colors.orange.shade50,
          Colors.orange.shade700,
          'PENDING'
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = _theme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.15)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _MetaBar extends StatelessWidget {
  final OrderModel order;
  const _MetaBar({required this.order});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.access_time_rounded, size: 13, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Text(
          DateFormat('MMM dd, hh:mm a').format(order.createdAt),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shopping_bag_outlined,
                  size: 12, color: Colors.blue.shade700),
              const SizedBox(width: 4),
              Text(
                '${order.totalItems} items',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  final Color primary;
  final OrderModel order;
  final VoidCallback? onView;
  final VoidCallback? onAction;

  const _ActionBar({
    required this.primary,
    required this.order,
    this.onView,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: OutlinedButton(
            onPressed: onView,
            style: OutlinedButton.styleFrom(
              foregroundColor: primary,
              side: BorderSide(color: primary.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            child: const Text('View Details'),
          ),
        ),
        if (order.canUpdateStatus) ...[
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: _AnimatedActionButton(
              status: order.deliveryStatus,
              onTap: onAction,
            ),
          ),
        ],
      ],
    );
  }
}

class _AnimatedActionButton extends StatefulWidget {
  final String status;
  final VoidCallback? onTap;
  const _AnimatedActionButton({required this.status, this.onTap});

  @override
  State<_AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<_AnimatedActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPending = widget.status == 'Pending';
    final label = isPending ? 'Start Delivery' : 'Mark Delivered';
    final color = isPending ? const Color(0xFF2B8CEE) : Colors.green.shade600;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}