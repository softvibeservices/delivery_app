// lib/features/orders/screens/order_details_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/order_model.dart';
import '../providers/orders_provider.dart';
import '../../../core/services/notification_service.dart'; 

class OrderDetailsScreen extends StatefulWidget {
  final OrderModel order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late OrderModel _order;
  final GlobalKey<SlideToConfirmButtonState> _slideButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not make phone call')),
        );
      }
    }
  }

  Future<void> _openMaps() async {
    if (_order.customerLat == null || _order.customerLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not available')),
      );
      return;
    }

    final Uri mapsUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${_order.customerLat},${_order.customerLng}',
    );

    if (await canLaunchUrl(mapsUri)) {
      await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps')),
        );
      }
    }
  }

  Future<void> _updateOrderStatus() async {
    if (!_order.canUpdateStatus) return;

    final nextStatus = _order.nextStatus;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Status to $nextStatus?'),
        content: Text(
          'Are you sure you want to mark this order as "$nextStatus"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    // ✅ FIXED: Reset slider if user cancels
    if (confirmed != true) {
      _slideButtonKey.currentState?.reset();
      return;
    }

    if (!mounted) return;
    // Capture provider before the await gap.
    final provider = context.read<OrdersProvider>();
    final success = await provider.updateOrderStatus(
      orderId: _order.id,
      status: nextStatus,
    );

    if (!mounted) return;
      if (success) {
        // ✅ FIXED: Update local order and reset slider
        final updatedOrder = provider.getOrderById(_order.id);
        if (updatedOrder != null) {
          setState(() {
            _order = updatedOrder;
          });
          // Reset slider after successful update
          _slideButtonKey.currentState?.reset();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order marked as $nextStatus'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // ✅ FIXED: Reset slider on failure too
        _slideButtonKey.currentState?.reset();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update order status'),
            backgroundColor: Colors.red,
          ),
        );
      }

    await NotificationService.instance.showOrderStatusNotification(
      orderId: _order.id,
      status: nextStatus,
      customerName: _order.shopName ?? _order.customerName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Order Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order #${_order.orderId}',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_order.serialNumber != null)
                              Text(
                                'Serial: ${_order.serialNumber}',
                                style: theme.textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      _statusBadge(_order.deliveryStatus),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    DateFormat('MMMM dd, yyyy • hh:mm a').format(_order.createdAt),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Customer Information
            _sectionCard(
              title: 'Customer Information',
              icon: Icons.person,
              child: Column(
                children: [
                  _detailRow('Name', _order.customerName),
                  if (_order.shopName != null)
                    _detailRow('Shop', _order.shopName!),
                  _detailRow('Address', _order.customerAddress),
                  if (_order.customerContact != null) ...[
                    const Divider(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _makePhoneCall(_order.customerContact!),
                            icon: const Icon(Icons.call, color: Colors.white),
                            label: const Text('Call Customer', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openMaps,
                            icon: const Icon(Icons.directions),
                            label: const Text('Navigate'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Order Items
            _sectionCard(
              title: 'Order Items (${_order.items.length})',
              icon: Icons.shopping_cart,
              child: Column(
                children: [
                  ..._order.items.map((item) => _itemRow(item)),
                  if (_order.freeItems != null && _order.freeItems!.isNotEmpty) ...[
                    const Divider(height: 24),
                    Text(
                      'Free Items (${_order.freeItems!.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._order.freeItems!.map((item) => _itemRow(item, isFree: true)),
                  ],
                ],
              ),
            ),

            // Order Summary
            _sectionCard(
              title: 'Order Summary',
              icon: Icons.receipt,
              child: Column(
                children: [
                  _summaryRow('Subtotal', '₹${_order.subtotal.toStringAsFixed(2)}'),
                  if (_order.discountPercentage > 0)
                    _summaryRow(
                      'Discount (${_order.discountPercentage}%)',
                      '- ₹${(_order.subtotal * _order.discountPercentage / 100).toStringAsFixed(2)}',
                      isDiscount: true,
                    ),
                  const Divider(height: 20),
                  _summaryRow(
                    'Total',
                    '₹${_order.total.toStringAsFixed(2)}',
                    isTotal: true,
                  ),
                  _summaryRow(
                    'Payment Status',
                    _order.status == 'Unsettled' ? 'Pending' : 'Paid',
                    isStatus: true,
                  ),
                ],
              ),
            ),

            // Delivery Status
            if (_order.deliveryStatus != 'Pending')
              _sectionCard(
                title: 'Delivery Timeline',
                icon: Icons.local_shipping,
                child: Column(
                  children: [
                    if (_order.deliveryAssignedAt != null)
                      _timelineItem(
                        'Order Assigned',
                        DateFormat('MMM dd, hh:mm a').format(_order.deliveryAssignedAt!),
                        Icons.assignment,
                        Colors.blue,
                      ),
                    if (_order.deliveryOnTheWayAt != null)
                      _timelineItem(
                        'On the Way',
                        DateFormat('MMM dd, hh:mm a').format(_order.deliveryOnTheWayAt!),
                        Icons.delivery_dining,
                        Colors.orange,
                      ),
                    if (_order.deliveryCompletedAt != null)
                      _timelineItem(
                        'Delivered',
                        DateFormat('MMM dd, hh:mm a').format(_order.deliveryCompletedAt!),
                        Icons.check_circle,
                        Colors.green,
                      ),
                  ],
                ),
              ),

            // Remarks
            if (_order.remarks != null && _order.remarks!.isNotEmpty)
              _sectionCard(
                title: 'Remarks',
                icon: Icons.note,
                child: Text(
                  _order.remarks!,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: _order.canUpdateStatus
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: SafeArea(
                child: SlideToConfirmButton(
                  key: _slideButtonKey, // ✅ FIXED: Added key to control slider
                  onConfirm: _updateOrderStatus,
                  text: 'Slide to mark as ${_order.nextStatus}',
                  backgroundColor: _order.deliveryStatus == 'Pending'
                      ? primary
                      : Colors.green,
                ),
              ),
            )
          : null,
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemRow(OrderItem item, {bool isFree = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isFree ? Colors.green.shade50 : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.icecream,
              color: isFree ? Colors.green : Colors.blue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${item.quantity} ${item.unit ?? 'pcs'}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (!isFree && item.total != null)
            Text(
              '₹${item.total!.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          if (isFree)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'FREE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isDiscount = false, bool isTotal = false, bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              fontSize: isTotal ? 16 : 14,
              color: isDiscount ? Colors.red : null,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              fontSize: isTotal ? 18 : 14,
              color: isDiscount ? Colors.red : (isStatus ? Colors.orange : null),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineItem(String title, String time, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha:0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  time,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color badgeColor;
    Color textColor;

    switch (status) {
      case 'On the Way':
        badgeColor = Colors.blue.shade50;
        textColor = Colors.blue.shade700;
        break;
      case 'Delivered':
        badgeColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        break;
      default:
        badgeColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ✅ FIXED: Modern Slide-to-Confirm Button Widget with Reset Method
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

class SlideToConfirmButtonState extends State<SlideToConfirmButton> {
  double _dragPosition = 0.0;
  bool _isDragging = false;
  static const double _threshold = 0.85;

  // ✅ FIXED: Added public reset method
  void reset() {
    if (mounted) {
      setState(() {
        _dragPosition = 0.0;
        _isDragging = false;
      });
    }
  }

  void _onDragUpdate(DragUpdateDetails details, double maxWidth) {
    setState(() {
      _isDragging = true;
      _dragPosition = (_dragPosition + details.delta.dx).clamp(0.0, maxWidth - 60);
    });
  }

  void _onDragEnd(double maxWidth) {
    if (_dragPosition >= (maxWidth - 60) * _threshold) {
      // Trigger confirmation
      widget.onConfirm();
      // Note: Don't reset here - let parent control reset after confirmation
    } else {
      // Reset position if not confirmed
      setState(() {
        _dragPosition = 0.0;
      });
    }
    setState(() {
      _isDragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final progress = _dragPosition / (maxWidth - 60);

        return Container(
          height: 60,
          decoration: BoxDecoration(
            color: widget.backgroundColor.withValues(alpha:0.2),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: widget.backgroundColor,
              width: 2,
            ),
          ),
          child: Stack(
            children: [
              // Background fill animation
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _dragPosition + 60,
                height: 60,
                decoration: BoxDecoration(
                  color: widget.backgroundColor.withValues(alpha:0.3),
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              // Text
              Center(
                child: AnimatedOpacity(
                  opacity: progress < 0.5 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    widget.text,
                    style: TextStyle(
                      color: widget.backgroundColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              // Draggable button
              AnimatedPositioned(
                duration: _isDragging ? Duration.zero : const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                left: _dragPosition,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) => _onDragUpdate(details, maxWidth),
                  onHorizontalDragEnd: (_) => _onDragEnd(maxWidth),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: widget.backgroundColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.backgroundColor.withValues(alpha:0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      progress >= _threshold ? Icons.check : Icons.arrow_forward,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}