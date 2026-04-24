import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/orders_provider.dart';
import '../models/order_model.dart';
import '../widgets/order_card.dart';
import '../widgets/skeleton_card.dart';
import 'order_details_screen.dart';

class PendingOrdersScreen extends StatefulWidget {
  const PendingOrdersScreen({super.key});

  @override
  State<PendingOrdersScreen> createState() => _PendingOrdersScreenState();
}

class _PendingOrdersScreenState extends State<PendingOrdersScreen> {
  String _searchQuery = '';
  String _selectedSort = 'All Orders';
  final _searchController = TextEditingController();
  bool _fetchTriggered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fetchTriggered) {
      _fetchTriggered = true;
      context.read<OrdersProvider>().fetchIfNeeded();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() => context.read<OrdersProvider>().fetchOrders();

  List<OrderModel> _displayOrders(OrdersProvider p) {
    final filtered = p.filterOrders(_searchQuery);
    return p.sortOrders(filtered, _selectedSort);
  }

  void _onSearch(String q) => setState(() => _searchQuery = q);
  void _clearSearch() {
    _searchController.clear();
    _onSearch('');
  }

  Future<void> _openDetail(OrderModel order, OrdersProvider provider) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: order)),
    );
    if ((changed ?? false) && mounted) await provider.fetchOrders();
  }

  Future<void> _updateStatus(OrdersProvider p, OrderModel order) async {
    await p.updateOrderStatus(orderId: order.id, status: order.nextStatus);
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
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          Selector<OrdersProvider, int>(
            selector: (_, p) => p.orders.length,
            builder: (_, count, __) => Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shopping_bag_outlined,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 6),
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
          final orders = _displayOrders(provider);
          final isEmpty = !provider.isLoading && orders.isEmpty;

          return RefreshIndicator(
            onRefresh: _refresh,
            color: primary,
            child: isEmpty && !provider.isLoading
                ? _EmptyState(
                    hasError: provider.error != null,
                    onRetry: _refresh,
                  )
                : _OrderList(
                    provider: provider,
                    orders: orders,
                    primary: primary,
                    searchQuery: _searchQuery,
                    selectedSort: _selectedSort,
                    searchController: _searchController,
                    onSearch: _onSearch,
                    onClearSearch: _clearSearch,
                    onSortChanged: (s) => setState(() => _selectedSort = s),
                    onView: (o) => _openDetail(o, provider),
                    onAction: (o) => _updateStatus(provider, o),
                  ),
          );
        },
      ),
    );
  }
}

// ─── Order List with Search, Chips & Cards ─────────────────────────────────

class _OrderList extends StatelessWidget {
  final OrdersProvider provider;
  final List<OrderModel> orders;
  final Color primary;
  final String searchQuery;
  final String selectedSort;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<OrderModel> onView;
  final ValueChanged<OrderModel> onAction;

  const _OrderList({
    required this.provider,
    required this.orders,
    required this.primary,
    required this.searchQuery,
    required this.selectedSort,
    required this.searchController,
    required this.onSearch,
    required this.onClearSearch,
    required this.onSortChanged,
    required this.onView,
    required this.onAction,
  });

  static const _sortOptions = [
    ('All Orders', null, Color(0xFF2B8CEE)),
    ('Pending', 'Pending', Colors.orange),
    ('On the Way', 'On the Way', Colors.blue),
    ('Quantity', 'Quantity', Colors.green),
  ];

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // Search
        SliverToBoxAdapter(
          child: _SearchBar(
            controller: searchController,
            query: searchQuery,
            onChanged: onSearch,
            onClear: onClearSearch,
          ),
        ),

        // Last updated
        if (provider.lastUpdated != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Updated ${DateFormat('hh:mm a').format(provider.lastUpdated!)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
          ),

        // Error banner
        if (provider.error != null)
          SliverToBoxAdapter(child: _ErrorBanner(error: provider.error!)),

        // Sort chips
        SliverToBoxAdapter(
          child: SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _sortOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final (label, _, color) = _sortOptions[i];
                final active = selectedSort == label;
                return _SortChip(
                  label: label,
                  active: active,
                  color: color,
                  onTap: () => onSortChanged(label),
                );
              },
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 8)),

        // Loading or List
        if (provider.isLoading && orders.isEmpty)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, __) => const SkeletonCard(),
              childCount: 6,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.builder(
              itemCount: orders.length,
              itemBuilder: (_, index) {
                final order = orders[index];
                return RepaintBoundary(
                  child: OrderCard(
                    order: order,
                    onTap: () => onView(order),
                    onActionTap: order.canUpdateStatus
                        ? () => onAction(order)
                        : null,
                  ),
                );
              },
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

// ─── Supporting Widgets ────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(Icons.search, color: Colors.grey.shade400, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search by customer, shop or order ID...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: onChanged,
              ),
            ),
            if (query.isNotEmpty)
              GestureDetector(
                onTap: onClear,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.clear, size: 18, color: Colors.grey.shade400),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: active ? color : Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
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
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String error;
  const _ErrorBanner({required this.error});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
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
                error,
                style: TextStyle(color: Colors.red.shade700, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasError;
  final VoidCallback onRetry;

  const _EmptyState({required this.hasError, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    hasError ? Icons.wifi_off_rounded : Icons.inbox_outlined,
                    size: 72,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    hasError ? 'Could not load orders' : 'No pending orders',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasError
                        ? 'Check your connection and try again.'
                        : 'Pull down to refresh. New orders will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  if (hasError) ...[
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2B8CEE),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}