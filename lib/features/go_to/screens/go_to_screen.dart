// lib/features/go_to/screens/go_to_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/go_to_provider.dart';
import '../models/customer_model.dart';
import 'customer_detail_screen.dart';

class GoToScreen extends StatefulWidget {
  const GoToScreen({super.key});

  @override
  State<GoToScreen> createState() => _GoToScreenState();
}

class _GoToScreenState extends State<GoToScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();

  static const _kBrand = Color(0xFF2B8CEE);

  @override
  void initState() {
    super.initState();
    // Load the full customer list on first open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GoToProvider>().loadCustomers(refresh: true);
    });

    // Infinite scroll — load next page when 80 % of the list is visible.
    _scrollController.addListener(() {
      final pos = _scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent * 0.8) {
        context.read<GoToProvider>().loadMoreCustomers();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSearch(String query) {
    context.read<GoToProvider>().searchCustomers(query);
    setState(() {}); // refresh clear-button visibility
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<GoToProvider>().clearSearch();
    setState(() {});
    _searchFocus.unfocus();
  }

  Future<void> _viewCustomer(CustomerModel customer) async {
    await context.read<GoToProvider>().addToRecentSearches(customer);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerDetailScreen(customer: customer),
      ),
    );
  }

  Future<void> _refresh() async {
    await context.read<GoToProvider>().loadCustomers(refresh: true);
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text(
          'Go To',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        // Live customer count badge in the app bar.
        actions: [
          Selector<GoToProvider, int>(
            selector: (_, p) => p.totalCustomers,
            builder: (_, total, _) {
              if (total == 0) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(right: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _kBrand.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$total customers',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kBrand,
                  ),
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Column(
            children: [
              Container(height: 1, color: const Color(0xFFDBE0E6)),
              _buildSearchBar(),
            ],
          ),
        ),
      ),
      body: Consumer<GoToProvider>(
        builder: (context, provider, _) {
          // ── Search active: show search results ──────────────────────────
          if (provider.searchQuery.isNotEmpty) {
            return _buildSearchResults(provider);
          }
          // ── No search: show full paginated list ─────────────────────────
          return _buildAllCustomersList(provider);
        },
      ),
    );
  }

  // ─── SEARCH BAR ───────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F2F4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          onChanged: _handleSearch,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Search by customer or shop name...',
            hintStyle: const TextStyle(
              color: Color(0xFF617589),
              fontSize: 14,
            ),
            prefixIcon: const Icon(Icons.search,
                color: Color(0xFF617589), size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear,
                        size: 18, color: Color(0xFF617589)),
                    onPressed: _clearSearch,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 12,
            ),
          ),
        ),
      ),
    );
  }

  // ─── FULL CUSTOMERS LIST ──────────────────────────────────────────────────

  Widget _buildAllCustomersList(GoToProvider provider) {
    if (provider.isLoadingCustomers && provider.allCustomers.isEmpty) {
      return _buildLoadingShimmer();
    }

    if (provider.error != null && provider.allCustomers.isEmpty) {
      return _buildErrorState(provider);
    }

    if (!provider.isLoadingCustomers && provider.allCustomers.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: _kBrand,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Recent searches section (pinned at top when not empty)
          if (provider.recentSearches.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildRecentSearchesSection(provider),
            ),

          // Section header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Text(
                    'ALL CUSTOMERS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF617589),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  if (provider.totalCustomers > 0)
                    Text(
                      '${provider.allCustomers.length} / ${provider.totalCustomers}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF617589),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Customer tiles
          SliverList.builder(
            itemCount: provider.allCustomers.length +
                (provider.isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= provider.allCustomers.length) {
                // Loading indicator at the bottom
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _kBrand),
                    ),
                  ),
                );
              }
              return _CustomerTile(
                customer: provider.allCustomers[index],
                onTap: () => _viewCustomer(provider.allCustomers[index]),
              );
            },
          ),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  // ─── SEARCH RESULTS ───────────────────────────────────────────────────────

  Widget _buildSearchResults(GoToProvider provider) {
    if (provider.isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: _kBrand),
      );
    }

    if (provider.error != null) {
      return _buildErrorBanner(provider.error!);
    }

    if (provider.searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('No customers found',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              'Try a different search term',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text(
            '${provider.searchResults.length} result${provider.searchResults.length == 1 ? '' : 's'}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF617589),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: provider.searchResults.length,
            itemBuilder: (_, index) => _CustomerTile(
              customer: provider.searchResults[index],
              onTap: () => _viewCustomer(provider.searchResults[index]),
              showAddress: true,
            ),
          ),
        ),
      ],
    );
  }

  // ─── RECENT SEARCHES SECTION ──────────────────────────────────────────────

  Widget _buildRecentSearchesSection(GoToProvider provider) {
    final recents = provider.recentSearches.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              const Text(
                'RECENT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF617589),
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: provider.clearRecentSearches,
                child: const Text(
                  'Clear',
                  style: TextStyle(
                    fontSize: 12,
                    color: _kBrand,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...recents.map(
          (c) => _CustomerTile(
            customer: c,
            onTap: () => _viewCustomer(c),
            showHistoryIcon: true,
          ),
        ),
        const Divider(height: 1, color: Color(0xFFEEF0F2)),
      ],
    );
  }

  // ─── LOADING SHIMMER ──────────────────────────────────────────────────────

  Widget _buildLoadingShimmer() {
    return ListView.builder(
      itemCount: 12,
      itemBuilder: (_, _) => const _ShimmerTile(),
    );
  }

  // ─── ERROR / EMPTY STATES ─────────────────────────────────────────────────

  Widget _buildErrorState(GoToProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('Could not load customers',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(provider.error ?? '',
              style:
                  TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kBrand,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String error) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 10),
            Expanded(
              child: Text(error,
                  style: TextStyle(color: Colors.red.shade700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 56, color: Colors.grey),
          SizedBox(height: 12),
          Text('No customers found',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ─── Customer Tile (shared between all-list & search results) ─────────────────

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({
    required this.customer,
    required this.onTap,
    this.showAddress = false,
    this.showHistoryIcon = false,
  });

  final CustomerModel customer;
  final VoidCallback onTap;
  final bool showAddress;
  final bool showHistoryIcon;

  static const _kBrand = Color(0xFF2B8CEE);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 11),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: showHistoryIcon
                          ? Colors.grey.shade100
                          : _kBrand.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      showHistoryIcon
                          ? Icons.history
                          : Icons.storefront_outlined,
                      color: showHistoryIcon
                          ? Colors.grey.shade500
                          : _kBrand,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Text block
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.shopName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111418),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          customer.name,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF617589),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (showAddress && customer.shopAddress.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            customer.shopAddress,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF617589),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // GPS indicator
                  if (customer.location?.isValid ?? false)
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.location_on,
                          size: 14, color: Colors.green.shade600),
                    )
                  else
                    const Icon(Icons.chevron_right,
                        size: 18, color: Color(0xFF617589)),
                ],
              ),
            ),
            const Divider(
                height: 1,
                indent: 70,
                color: Color(0xFFF0F2F4)),
          ],
        ),
      ),
    );
  }
}

// ─── Shimmer tile ─────────────────────────────────────────────────────────────

class _ShimmerTile extends StatefulWidget {
  const _ShimmerTile();

  @override
  State<_ShimmerTile> createState() => _ShimmerTileState();
}

class _ShimmerTileState extends State<_ShimmerTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
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
        final c = Color.lerp(
            Colors.grey.shade200, Colors.grey.shade100, _anim.value)!;
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                    color: c, borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      height: 13, width: 140,
                      decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(6))),
                  const SizedBox(height: 6),
                  Container(
                      height: 10, width: 90,
                      decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(5))),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}