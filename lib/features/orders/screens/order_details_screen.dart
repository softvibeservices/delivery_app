import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/order_model.dart';
import '../providers/orders_provider.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/notification_service.dart';

class OrderDetailsScreen extends StatefulWidget {
  final OrderModel order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late OrderModel _order;
  final GlobalKey<SlideToConfirmButtonState> _slideKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  Future<void> _call(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _navigate() async {
    if (_order.customerLat == null || _order.customerLng == null) {
      _showSnack('Location not available', isError: true);
      return;
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${_order.customerLat},${_order.customerLng}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _updateStatus() async {
    if (!_order.canUpdateStatus) return;
    final next = _order.nextStatus;
    final provider = context.read<OrdersProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(status: next),
    );

    if (confirmed != true) {
      _slideKey.currentState?.reset();
      return;
    }

    final success = await provider.updateOrderStatus(
      orderId: _order.id,
      status: next,
    );

    if (!mounted) return; // CRITICAL: guard before any context usage

    if (success) {
      // FIX (Bug 4B): When the order is marked Delivered the backend stops
      // returning it in the pending list, so getOrderById returns null.
      // Fall back to copyWith so local state still reflects the new status —
      // this makes canUpdateStatus return false and hides the slide button.
      final updated = provider.getOrderById(_order.id);
      if (updated != null) {
        setState(() => _order = updated);
      } else {
        setState(() => _order = _order.copyWith(
              deliveryStatus: next,
              deliveryCompletedAt:
                  next == 'Delivered' ? DateTime.now() : _order.deliveryCompletedAt,
              deliveryOnTheWayAt:
                  next == 'On the Way' ? DateTime.now() : _order.deliveryOnTheWayAt,
            ));
      }

      _slideKey.currentState?.reset();
      _showSnack('Order marked as $next');

      // FIX (Bug 4A): Notification now fires ONLY on success (moved inside
      // the if-block; was previously outside and fired on failures too).
      await NotificationService.instance.showOrderStatusNotification(
        orderId: _order.id,
        status: next,
        customerName: _order.shopName ?? _order.customerName,
      );

      // FIX (Bug 5): Signal the delivered orders screen to reload when this
      // order transitions to Delivered.
      if (next == 'Delivered') {
        NavigationService.instance.triggerDeliveredOrdersRefresh();
      }
    } else {
      _slideKey.currentState?.reset();
      _showSnack('Failed to update status', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return; // FIX: guard against calling after widget disposal
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Order Details',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE8EAED)),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _HeaderCard(order: _order)),

          SliverToBoxAdapter(
            child: _SectionCard(
              title: 'Customer',
              icon: Icons.person_outline,
              child: _CustomerBody(
                order: _order,
                onCall: _call,
                onNavigate: _navigate,
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: _SectionCard(
              title: 'Items (${_order.items.length})',
              icon: Icons.shopping_bag_outlined,
              child: _ItemsBody(order: _order),
            ),
          ),

          SliverToBoxAdapter(
            child: _SectionCard(
              title: 'Summary',
              icon: Icons.receipt_long_outlined,
              child: _SummaryBody(order: _order),
            ),
          ),

          if (_order.deliveryStatus != 'Pending')
            SliverToBoxAdapter(
              child: _SectionCard(
                title: 'Timeline',
                icon: Icons.local_shipping_outlined,
                child: _TimelineBody(order: _order),
              ),
            ),

          if (_order.remarks != null && _order.remarks!.isNotEmpty)
            SliverToBoxAdapter(
              child: _SectionCard(
                title: 'Remarks',
                icon: Icons.sticky_note_2_outlined,
                child: Text(
                  _order.remarks!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      bottomNavigationBar: _order.canUpdateStatus
          ? _BottomAction(
              order: _order,
              slideKey: _slideKey,
              onConfirm: _updateStatus,
            )
          : null,
    );
  }
}

// ─── Header Card ───────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final OrderModel order;
  const _HeaderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final statusTheme = _statusTheme(order.deliveryStatus);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EAED)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order.id.length > 8 ? order.id.substring(order.id.length - 8).toUpperCase() : order.id.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.shopName ?? order.customerName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: statusTheme.bg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: statusTheme.fg.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusTheme.fg,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      order.deliveryStatus.toUpperCase(),
                      style: TextStyle(
                        color: statusTheme.fg,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  ({Color bg, Color fg}) _statusTheme(String status) {
    return switch (status) {
      'On the Way' => (bg: Colors.blue.shade50, fg: Colors.blue.shade700),
      'Delivered' => (bg: Colors.green.shade50, fg: Colors.green.shade700),
      _ => (bg: Colors.orange.shade50, fg: Colors.orange.shade700),
    };
  }
}

// ─── Section Card ──────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EAED)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

// ─── Customer Body ─────────────────────────────────────────────────────────

class _CustomerBody extends StatelessWidget {
  final OrderModel order;
  final void Function(String?) onCall;
  final VoidCallback onNavigate;

  const _CustomerBody({
    required this.order,
    required this.onCall,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Avatar(name: order.customerName),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.customerName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (order.shopName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      order.shopName!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _InfoTile(
          icon: Icons.location_on_outlined,
          label: 'Delivery Address',
          value: order.customerAddress,
        ),
        if (order.customerContact != null) ...[
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.phone_outlined,
            label: 'Contact',
            value: order.customerContact!,
            // FIX (Bug 3): Keep the compact inline "Call" chip here —
            // removed the redundant full-width "Call Customer" action button
            // that was in the Row below (left only "Navigate").
            trailing: GestureDetector(
              onTap: () => onCall(order.customerContact),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.call, size: 14, color: Colors.green.shade700),
                    const SizedBox(width: 6),
                    Text(
                      'Call',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        // FIX (Bug 3): Removed duplicate "Call Customer" _ActionButton.
        // The inline "Call" chip on the _InfoTile above is sufficient.
        // "Navigate" now occupies the full width on its own.
        SizedBox(
          width: double.infinity,
          child: _ActionButton(
            icon: Icons.directions,
            label: 'Navigate',
            color: primary,
            onTap: onNavigate,
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF2B8CEE),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
    ];
    final color = colors[name.hashCode.abs() % colors.length];
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: Colors.grey.shade600),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Items Body ────────────────────────────────────────────────────────────

class _ItemsBody extends StatelessWidget {
  final OrderModel order;
  const _ItemsBody({required this.order});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...order.items.asMap().entries.map(
          (e) => _ItemRow(item: e.value, index: e.key + 1),
        ),
        if (order.freeItems != null && order.freeItems!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.card_giftcard,
                  size: 16,
                  color: Colors.green.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  'Free Items (${order.freeItems!.length})',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...order.freeItems!.asMap().entries.map(
            (e) => _ItemRow(item: e.value, index: e.key + 1, isFree: true),
          ),
        ],
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  final OrderItem item;
  final int index;
  final bool isFree;

  const _ItemRow({
    required this.item,
    required this.index,
    this.isFree = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isFree ? Colors.green.shade50 : const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isFree ? Colors.green.shade700 : const Color(0xFF2B8CEE),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.quantity} ${item.unit ?? 'pcs'}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (!isFree && item.total != null)
            Text(
              '₹${item.total!.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'FREE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Summary Body ──────────────────────────────────────────────────────────

class _SummaryBody extends StatelessWidget {
  final OrderModel order;
  const _SummaryBody({required this.order});

  @override
  Widget build(BuildContext context) {
    final discount = order.subtotal * order.discountPercentage / 100;

    return Column(
      children: [
        _SummaryRow(
          label: 'Subtotal',
          value: '₹${order.subtotal.toStringAsFixed(2)}',
        ),
        if (order.discountPercentage > 0)
          _SummaryRow(
            label: 'Discount (${order.discountPercentage}%)',
            value: '- ₹${discount.toStringAsFixed(2)}',
            valueColor: Colors.red,
          ),
        const Divider(height: 24),
        _SummaryRow(
          label: 'Total Amount',
          value: '₹${order.total.toStringAsFixed(2)}',
          isTotal: true,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: order.status == 'Unsettled'
                ? Colors.orange.shade50
                : Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: order.status == 'Unsettled'
                  ? Colors.orange.shade200
                  : Colors.green.shade200,
            ),
          ),
          child: Row(
            children: [
              Icon(
                order.status == 'Unsettled'
                    ? Icons.pending
                    : Icons.check_circle,
                size: 20,
                color: order.status == 'Unsettled'
                    ? Colors.orange.shade700
                    : Colors.green.shade700,
              ),
              const SizedBox(width: 12),
              Text(
                order.status == 'Unsettled'
                    ? 'Payment Pending'
                    : 'Payment Received',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: order.status == 'Unsettled'
                      ? Colors.orange.shade800
                      : Colors.green.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isTotal;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 15 : 14,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w700,
              color:
                  valueColor ??
                  (isTotal ? const Color(0xFF2B8CEE) : Colors.black87),
              letterSpacing: isTotal ? -0.3 : 0,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Timeline Body ─────────────────────────────────────────────────────────

class _TimelineBody extends StatelessWidget {
  final OrderModel order;
  const _TimelineBody({required this.order});

  @override
  Widget build(BuildContext context) {
    final items = <_TimelineItem>[];
    if (order.deliveryAssignedAt != null) {
      items.add(
        _TimelineItem(
          title: 'Order Assigned',
          time: order.deliveryAssignedAt!,
          icon: Icons.assignment_outlined,
          color: Colors.blue,
          isFirst: true,
        ),
      );
    }
    if (order.deliveryOnTheWayAt != null) {
      items.add(
        _TimelineItem(
          title: 'On the Way',
          time: order.deliveryOnTheWayAt!,
          icon: Icons.delivery_dining_outlined,
          color: Colors.orange,
        ),
      );
    }
    if (order.deliveryCompletedAt != null) {
      items.add(
        _TimelineItem(
          title: 'Delivered',
          time: order.deliveryCompletedAt!,
          icon: Icons.check_circle_outline,
          color: Colors.green,
          isLast: true,
        ),
      );
    }

    return Column(
      children: items.asMap().entries.map((e) {
        final item = e.value;
        final isLast = e.key == items.length - 1;
        return _TimelineTile(item: item, isLast: isLast);
      }).toList(),
    );
  }
}

class _TimelineItem {
  final String title;
  final DateTime time;
  final IconData icon;
  final Color color;
  final bool isFirst;
  final bool isLast;

  _TimelineItem({
    required this.title,
    required this.time,
    required this.icon,
    required this.color,
    this.isFirst = false,
    this.isLast = false,
  });
}

class _TimelineTile extends StatelessWidget {
  final _TimelineItem item;
  final bool isLast;

  const _TimelineTile({required this.item, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, color: item.color, size: 20),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          item.color.withValues(alpha: 0.3),
                          Colors.grey.shade300,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd, yyyy • hh:mm a').format(item.time),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom Action ─────────────────────────────────────────────────────────

class _BottomAction extends StatelessWidget {
  final OrderModel order;
  final GlobalKey<SlideToConfirmButtonState> slideKey;
  final VoidCallback onConfirm;

  const _BottomAction({
    required this.order,
    required this.slideKey,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = order.deliveryStatus == 'Pending';
    final color = isPending ? const Color(0xFF2B8CEE) : Colors.green.shade600;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SlideToConfirmButton(
          key: slideKey,
          onConfirm: onConfirm,
          text: 'Slide to mark as ${order.nextStatus}',
          backgroundColor: color,
        ),
      ),
    );
  }
}

// ─── Confirm Dialog ────────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final String status;
  const _ConfirmDialog({required this.status});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Mark as $status?',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      content: Text(
        'Are you sure you want to update this order status to "$status"?',
        style: TextStyle(
          fontSize: 15,
          color: Colors.grey.shade700,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(
            'Cancel',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Confirm',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

// ─── Slide to Confirm (Premium) ────────────────────────────────────────────

class SlideToConfirmButton extends StatefulWidget {
  final VoidCallback onConfirm;
  final String text;
  final Color backgroundColor;

  const SlideToConfirmButton({
    super.key,
    required this.onConfirm,
    required this.text,
    required this.backgroundColor,
  });

  @override
  State<SlideToConfirmButton> createState() => SlideToConfirmButtonState();
}

class SlideToConfirmButtonState extends State<SlideToConfirmButton>
    with SingleTickerProviderStateMixin {
  double _drag = 0.0;
  bool _dragging = false;
  static const double _threshold = 0.82;

  late final AnimationController _bounceCtrl;
  late final Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _bounce = Tween<double>(
      begin: 0,
      end: 6,
    ).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  void reset() {
    if (mounted) setState(() => _drag = 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final thumb = 56.0;
        final trackH = 64.0;
        final progress = _drag / (maxW - thumb);

        return GestureDetector(
          onHorizontalDragUpdate: (d) {
            setState(() {
              _dragging = true;
              _drag = (_drag + d.delta.dx).clamp(0.0, maxW - thumb);
            });
          },
          onHorizontalDragEnd: (_) {
            if (progress >= _threshold) {
              HapticFeedback.lightImpact();
              widget.onConfirm();
            } else {
              setState(() {
                _drag = 0.0;
                _dragging = false;
              });
            }
          },
          child: AnimatedContainer(
            duration: _dragging
                ? Duration.zero
                : const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            height: trackH,
            decoration: BoxDecoration(
              color: widget.backgroundColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: widget.backgroundColor.withValues(alpha: 0.25),
                width: 2,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Fill
                AnimatedContainer(
                  duration: _dragging
                      ? Duration.zero
                      : const Duration(milliseconds: 280),
                  width: _drag + thumb,
                  height: trackH,
                  decoration: BoxDecoration(
                    color: widget.backgroundColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                // Text
                AnimatedOpacity(
                  opacity: progress < 0.4 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    widget.text,
                    style: TextStyle(
                      color: widget.backgroundColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                // Thumb
                AnimatedPositioned(
                  duration: _dragging
                      ? Duration.zero
                      : const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  left: _drag,
                  top: 4,
                  bottom: 4,
                  child: AnimatedBuilder(
                    animation: _bounce,
                    builder: (_, child) {
                      return Transform.translate(
                        offset: progress > 0.1
                            ? Offset.zero
                            : Offset(_bounce.value, 0),
                        child: child,
                      );
                    },
                    child: Container(
                      width: thumb,
                      height: thumb,
                      decoration: BoxDecoration(
                        color: widget.backgroundColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: widget.backgroundColor.withValues(
                              alpha: 0.35,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          progress >= _threshold
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                          key: ValueKey(progress >= _threshold),
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}