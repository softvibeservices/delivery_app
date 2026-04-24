import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/delivered_orders_provider.dart';
import '../models/order_model.dart';
import '../widgets/order_card.dart';
import '../widgets/skeleton_card.dart';
import '../../../core/utils/date_utils.dart';
import 'order_details_screen.dart';

class DeliveredOrdersScreen extends StatefulWidget {
  const DeliveredOrdersScreen({super.key});

  @override
  State<DeliveredOrdersScreen> createState() => _DeliveredOrdersScreenState();
}

class _DeliveredOrdersScreenState extends State<DeliveredOrdersScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeliveredOrdersProvider>().fetchDeliveredOrders();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() =>
      context.read<DeliveredOrdersProvider>().fetchDeliveredOrders();

  void _onSearch(String q) => setState(() => _searchQuery = q);
  void _clearSearch() {
    _searchController.clear();
    _onSearch('');
  }

  Future<void> _openDetail(OrderModel order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: order)),
    );
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
          'Delivered Orders',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          Selector<DeliveredOrdersProvider, int>(
            selector: (_, p) => p.totalDeliveries,
            builder: (_, count, __) => Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE8EAED)),
        ),
      ),
      body: Consumer<DeliveredOrdersProvider>(
        builder: (context, provider, _) {
          final grouped = provider.filterOrders(_searchQuery);
          final hasData = grouped.values.any((l) => l.isNotEmpty);
          final isEmpty = !provider.isLoading && !hasData;

          return RefreshIndicator(
            onRefresh: _refresh,
            color: primary,
            child: isEmpty
                ? _EmptyState(
                    hasError: provider.error != null,
                    hasSearch: _searchQuery.isNotEmpty,
                    onRetry: _refresh,
                  )
                : CustomScrollView(
                    slivers: [
                      // Search
                      SliverToBoxAdapter(
                        child: _SearchBar(
                          controller: _searchController,
                          query: _searchQuery,
                          onChanged: _onSearch,
                          onClear: _clearSearch,
                        ),
                      ),

                      // Stats
                      if (!provider.isLoading && provider.totalDeliveries > 0)
                        SliverToBoxAdapter(
                          child: _StatsRow(provider: provider),
                        ),

                      // Last updated
                      if (provider.lastUpdated != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                            child: Text(
                              'Updated ${DateFormat('hh:mm a').format(provider.lastUpdated!)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                        ),

                      // Error
                      if (provider.error != null)
                        SliverToBoxAdapter(
                          child: _ErrorBanner(
                            error: provider.error!,
                            onDismiss: provider.clearError,
                          ),
                        ),

                      // Loading skeletons
                      if (provider.isLoading && !hasData)
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, __) => const SkeletonCard(),
                            childCount: 5,
                          ),
                        ),

                      // Grouped list
                      if (hasData) ...[
                        _GroupSliver(
                          title: 'Today',
                          orders: grouped['today']!,
                          onTap: _openDetail,
                        ),
                        _GroupSliver(
                          title: 'Yesterday',
                          orders: grouped['yesterday']!,
                          onTap: _openDetail,
                        ),
                        _GroupSliver(
                          title: 'This Week',
                          orders: grouped['this_week']!,
                          onTap: _openDetail,
                        ),
                        _GroupSliver(
                          title: 'Older',
                          orders: grouped['older']!,
                          onTap: _openDetail,
                        ),
                      ],

                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

// ─── Search Bar ────────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Container(
        height: 48,
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
            const SizedBox(width: 14),
            Icon(Icons.search, color: Colors.grey.shade400, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search delivered orders...',
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
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Icon(Icons.clear, size: 18, color: Colors.grey.shade400),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Stats Row ─────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final DeliveredOrdersProvider provider;
  const _StatsRow({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          _StatCard(
            label: 'Today',
            value: provider.todayCount.toString(),
            icon: Icons.today_outlined,
            color: Colors.blue,
          ),
          const SizedBox(width: 12),
          _StatCard(
            label: 'This Week',
            value: provider.getThisWeekDeliveries().toString(),
            icon: Icons.date_range_outlined,
            color: Colors.green,
          ),
          const SizedBox(width: 12),
          _StatCard(
            label: 'Total',
            value: provider.totalDeliveries.toString(),
            icon: Icons.check_circle_outline,
            color: Colors.orange,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8EAED)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                value,
                key: ValueKey(value),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Group Sliver ──────────────────────────────────────────────────────────

class _GroupSliver extends StatelessWidget {
  final String title;
  final List<OrderModel> orders;
  final ValueChanged<OrderModel> onTap;

  const _GroupSliver({
    required this.title,
    required this.orders,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2B8CEE),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$title (${orders.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              );
            }
            final order = orders[index - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: OrderCard(
                order: order,
                onTap: () => onTap(order),
              ),
            );
          },
          childCount: orders.length + 1,
        ),
      ),
    );
  }
}

// ─── Error Banner ──────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String error;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.error, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(14),
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
            GestureDetector(
              onTap: onDismiss,
              child: Icon(Icons.close, size: 18, color: Colors.red.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty State ───────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasError;
  final bool hasSearch;
  final VoidCallback onRetry;

  const _EmptyState({
    required this.hasError,
    required this.hasSearch,
    required this.onRetry,
  });

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
                    hasError
                        ? 'Could not load orders'
                        : (hasSearch ? 'No matches found' : 'No deliveries yet'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasError
                        ? 'Check your connection and try again.'
                        : (hasSearch
                            ? 'Try a different search term.'
                            : 'Completed deliveries will appear here.'),
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