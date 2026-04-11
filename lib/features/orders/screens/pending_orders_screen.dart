// lib/features/orders/screens/pending_orders_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/orders_provider.dart';
import '../models/order_model.dart';
import 'order_details_screen.dart';

class PendingOrdersScreen extends StatefulWidget {
  const PendingOrdersScreen({super.key});

  @override
  State<PendingOrdersScreen> createState() => _PendingOrdersScreenState();
}

class _PendingOrdersScreenState extends State<PendingOrdersScreen> {
  String _searchQuery = '';
  String _selectedSort = 'All Orders';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrdersProvider>().fetchOrders();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshOrders() async {
    await context.read<OrdersProvider>().fetchOrders();
  }

  void _filterOrders(String query) => setState(() => _searchQuery = query);

  void _clearSearch() {
    _searchController.clear();
    _filterOrders('');
  }

  List<OrderModel> _getDisplayOrders(OrdersProvider provider) {
    final filtered = provider.filterOrders(_searchQuery);
    return provider.sortOrders(filtered, _selectedSort);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        automaticallyImplyLeading: false,
        title: const Text(
          'Current Orders',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Consumer<OrdersProvider>(
            builder: (context, provider, _) {
              return Container(
                margin: const EdgeInsets.only(right: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shopping_bag_outlined,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '${provider.orders.length}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<OrdersProvider>(
        builder: (context, provider, _) {
          final displayOrders = _getDisplayOrders(provider);
          final isEmpty = !provider.isLoading && displayOrders.isEmpty;

          return RefreshIndicator(
            onRefresh: _refreshOrders,
            child: isEmpty && !provider.isLoading
                ? _buildEmptyStateWithScroll()
                : _buildOrdersList(provider, displayOrders, primary),
          );
        },
      ),
    );
  }

  // ─── LAYOUTS ──────────────────────────────────────────────────────────────

  Widget _buildEmptyStateWithScroll() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            children: [
              _buildSearchAndFilters(),
              SizedBox(height: constraints.maxHeight * 0.2),
              _emptyState(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrdersList(
    OrdersProvider provider,
    List<OrderModel> displayOrders,
    Color primary,
  ) {
    return Column(
      children: [
        _buildSearchAndFilters(),

        if (provider.lastUpdated != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Last updated: ${DateFormat('hh:mm a').format(provider.lastUpdated!)}',
                style:
                    TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
          ),

        if (provider.error != null) _buildErrorBanner(provider),

        // Sort chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _chip('All Orders', active: _selectedSort == 'All Orders',
                    color: Theme.of(context).primaryColor,
                    onTap: () => setState(() => _selectedSort = 'All Orders')),
                _chip('Pending', active: _selectedSort == 'Pending',
                    color: Colors.orange,
                    onTap: () => setState(() => _selectedSort = 'Pending')),
                _chip('On the Way', active: _selectedSort == 'On the Way',
                    color: Colors.blue,
                    onTap: () => setState(() => _selectedSort = 'On the Way')),
                _chip('Quantity', active: _selectedSort == 'Quantity',
                    color: Colors.green,
                    onTap: () => setState(() => _selectedSort = 'Quantity')),
              ],
            ),
          ),
        ),

        Expanded(
          child: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: displayOrders.length,
                  itemBuilder: (context, index) => _orderCard(
                    displayOrders[index],
                    primary,
                    context,
                    provider,
                  ),
                ),
        ),
      ],
    );
  }

  // ─── SEARCH & FILTERS ─────────────────────────────────────────────────────

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search by customer or shop...',
                  border: InputBorder.none,
                ),
                onChanged: _filterOrders,
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: _clearSearch,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(OrdersProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(provider.error!,
                  style: TextStyle(color: Colors.red.shade700)),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: provider.clearError,
            ),
          ],
        ),
      ),
    );
  }

  // ─── ORDER CARD ───────────────────────────────────────────────────────────

  Widget _orderCard(
    OrderModel order,
    Color primary,
    BuildContext context,
    OrdersProvider provider,
  ) {
    final status = order.deliveryStatus;
    final orderDate = DateFormat('MMM dd, hh:mm a').format(order.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: customer name + status badge ──────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Names column — Expanded so long names never overflow
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.customerName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (order.shopName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          order.shopName!,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _statusBadge(status),
              ],
            ),

            const SizedBox(height: 12),

            // ── Contact ───────────────────────────────────────────────────
            if (order.customerContact != null)
              _infoRow(Icons.call, order.customerContact!),

            const SizedBox(height: 8),

            // ── Address ───────────────────────────────────────────────────
            _infoRow(Icons.location_on, order.customerAddress),

            const SizedBox(height: 10),

            // ── Date + quantity badge ─────────────────────────────────────
            Row(
              children: [
                Flexible(
                  child: Text(
                    'Order: $orderDate',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${order.totalItems} items',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            // ── Action buttons — Flexible so they never overflow ──────────
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              OrderDetailsScreen(order: order),
                        ),
                      );
                      if (context.mounted) await provider.fetchOrders();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: primary,
                      side: BorderSide(color: primary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('View'),
                  ),
                ),
                if (order.canUpdateStatus) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton(
                      onPressed: () async {
                        final success = await provider.updateOrderStatus(
                          orderId: order.id,
                          status: order.nextStatus,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success
                                  ? 'Marked as ${order.nextStatus}'
                                  : 'Failed to update order'),
                              backgroundColor:
                                  success ? Colors.green : Colors.red,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            status == 'Pending' ? primary : Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        order.nextStatus,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── SHARED WIDGETS ───────────────────────────────────────────────────────

  Widget _chip(
    String label, {
    bool active = false,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Chip(
          label: Text(label),
          backgroundColor: active ? color : Colors.white,
          labelStyle: TextStyle(
            color: active ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
          side: BorderSide(color: Colors.grey.shade200),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'On the Way':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        break;
      case 'Delivered':
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        break;
      default:
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade700;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
            color: fg, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: Colors.grey.shade100,
          child: Icon(icon, size: 16, color: Colors.grey),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No pending orders',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try adjusting your search'
                : 'Pull down to refresh',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}