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

  // ─── AUTO-LOAD FIX ────────────────────────────────────────────────────────
  //
  // We use didChangeDependencies() instead of initState() +
  // addPostFrameCallback().  didChangeDependencies fires synchronously after
  // the widget's dependencies (i.e. Providers) are available, which makes it
  // more reliable than postFrameCallback in an IndexedStack where all children
  // mount simultaneously.
  //
  // The _fetchTriggered guard prevents re-triggering on every subsequent
  // dependency change (theme, locale, etc.).
  bool _fetchTriggered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fetchTriggered) {
      _fetchTriggered = true;
      // fetchIfNeeded() is smart: it skips if data is fresh and only hits the
      // network when needed, so switching tabs is instant.
      context.read<OrdersProvider>().fetchIfNeeded();
    }
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
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text(
          'Current Orders',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Count badge — uses Selector so ONLY this widget rebuilds when
          // order count changes, not the whole screen.
          Selector<OrdersProvider, int>(
            selector: (_, p) => p.orders.length,
            builder: (_, count, _) => Container(
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
                      color: Colors.white, size: 16),
                  const SizedBox(width: 5),
                  Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Consumer<OrdersProvider>(
        builder: (context, provider, _) {
          final displayOrders = _getDisplayOrders(provider);
          final isEmpty = !provider.isLoading && displayOrders.isEmpty;

          return RefreshIndicator(
            onRefresh: _refreshOrders,
            color: primary,
            child: isEmpty && !provider.isLoading
                ? _buildEmptyStateWithScroll(provider)
                : _buildOrdersList(provider, displayOrders, primary),
          );
        },
      ),
    );
  }

  // ─── LAYOUTS ──────────────────────────────────────────────────────────────

  Widget _buildEmptyStateWithScroll(OrdersProvider provider) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            children: [
              _SearchBar(
                controller: _searchController,
                searchQuery: _searchQuery,
                onChanged: _filterOrders,
                onClear: _clearSearch,
              ),
              SizedBox(height: constraints.maxHeight * 0.18),
              // Show error if fetch failed, otherwise empty state
              if (provider.error != null)
                _buildErrorCard(provider)
              else
                _emptyState(provider),
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
        _SearchBar(
          controller: _searchController,
          searchQuery: _searchQuery,
          onChanged: _filterOrders,
          onClear: _clearSearch,
        ),

        if (provider.lastUpdated != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Updated ${DateFormat('hh:mm a').format(provider.lastUpdated!)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
          ),

        if (provider.error != null) _buildErrorCard(provider),

        // Sort chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 0, 8),
          child: SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _chip('All Orders',
                    active: _selectedSort == 'All Orders',
                    color: primary,
                    onTap: () =>
                        setState(() => _selectedSort = 'All Orders')),
                _chip('Pending',
                    active: _selectedSort == 'Pending',
                    color: Colors.orange,
                    onTap: () =>
                        setState(() => _selectedSort = 'Pending')),
                _chip('On the Way',
                    active: _selectedSort == 'On the Way',
                    color: Colors.blue,
                    onTap: () =>
                        setState(() => _selectedSort = 'On the Way')),
                _chip('Quantity',
                    active: _selectedSort == 'Quantity',
                    color: Colors.green,
                    onTap: () =>
                        setState(() => _selectedSort = 'Quantity')),
              ],
            ),
          ),
        ),

        Expanded(
          child: provider.isLoading
              ? const _LoadingList()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: displayOrders.length,
                  itemBuilder: (context, index) => RepaintBoundary(
                    child: _orderCard(
                      displayOrders[index],
                      primary,
                      context,
                      provider,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────────

  Widget _chip(String label,
      {required bool active,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? color : Colors.grey.shade200,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(OrdersProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                provider.error!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 13),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: provider.clearError,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(OrdersProvider provider) {
    // Distinguish between "loading failed" and "genuinely no orders"
    final isError = provider.error != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isError ? Icons.wifi_off_rounded : Icons.inbox_rounded,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              isError ? 'Could not load orders' : 'No pending orders',
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isError
                  ? 'Pull down to try again'
                  : 'Pull down to refresh',
              style: TextStyle(
                  color: Colors.grey.shade500, fontSize: 14),
              textAlign: TextAlign.center,
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
    final orderDate =
        DateFormat('MMM dd, hh:mm a').format(order.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.customerName,
                        style: const TextStyle(
                          fontSize: 16,
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
                              color: Colors.grey, fontSize: 12),
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
            const SizedBox(height: 10),
            if (order.customerContact != null)
              _infoRow(Icons.call, order.customerContact!),
            const SizedBox(height: 4),
            _infoRow(Icons.location_on, order.customerAddress),
            const SizedBox(height: 8),
            Row(
              children: [
                Flexible(
                  child: Text(
                    'Order: $orderDate',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${order.totalItems} items',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: () async {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              OrderDetailsScreen(order: order),
                        ),
                      );
                      // Only refetch if the status was changed (result == true)
                      if ((result ?? false) && context.mounted) {
                        await provider.fetchOrders();
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primary,
                      side: BorderSide(color: primary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('View',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                if (order.canUpdateStatus) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton(
                      onPressed: () async {
                        await provider.updateOrderStatus(
                          orderId: order.id,
                          status: order.nextStatus,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: status == 'Pending'
                            ? primary
                            : Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                      ),
                      child: Text(
                        status == 'Pending'
                            ? 'Start Delivery'
                            : 'Mark Delivered',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
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

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(String status) {
    final (bg, fg) = switch (status) {
      'On the Way' => (Colors.blue.shade50, Colors.blue.shade700),
      'Delivered' => (Colors.green.shade50, Colors.green.shade700),
      _ => (Colors.orange.shade50, Colors.orange.shade700),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
            color: fg, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }
}

// ─── Extracted Search Bar ─────────────────────────────────────────────────────
// Separate StatefulWidget so typing inside the bar doesn't rebuild the whole
// screen — only this tiny widget rerenders.

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.searchQuery,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String searchQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: Colors.grey.shade400, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search by customer or shop...',
                  hintStyle:
                      TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: onChanged,
              ),
            ),
            if (searchQuery.isNotEmpty)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.clear, size: 16, color: Colors.grey.shade400),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Shimmer-style loading placeholder ────────────────────────────────────────

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: 5,
      itemBuilder: (_, _) => const _SkeletonCard(),
    );
  }
}

class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) {
        final shimmer = Color.lerp(
          Colors.grey.shade200,
          Colors.grey.shade100,
          _anim.value,
        )!;
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                      height: 14, width: 140,
                      decoration: BoxDecoration(
                          color: shimmer,
                          borderRadius: BorderRadius.circular(7))),
                  const Spacer(),
                  Container(
                      height: 22, width: 70,
                      decoration: BoxDecoration(
                          color: shimmer,
                          borderRadius: BorderRadius.circular(11))),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                  height: 10, width: 100,
                  decoration: BoxDecoration(
                      color: shimmer,
                      borderRadius: BorderRadius.circular(5))),
              const SizedBox(height: 10),
              Container(
                  height: 10, width: double.infinity,
                  decoration: BoxDecoration(
                      color: shimmer,
                      borderRadius: BorderRadius.circular(5))),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(
                        height: 34,
                        decoration: BoxDecoration(
                            color: shimmer,
                            borderRadius: BorderRadius.circular(10))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                        height: 34,
                        decoration: BoxDecoration(
                            color: shimmer,
                            borderRadius: BorderRadius.circular(10))),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}