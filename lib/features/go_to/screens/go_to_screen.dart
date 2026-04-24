// lib/features/go_to/screens/go_to_screen.dart
// Refactored for minimal rebuilds, clear navigation, and lightweight UX states.

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
  final _searchFocus = FocusNode();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GoToProvider>().loadCustomers(refresh: true);
    });
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent * 0.85) {
      context.read<GoToProvider>().loadMoreCustomers();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _handleSearch(String query) =>
      context.read<GoToProvider>().searchCustomers(query);

  void _clearSearch() {
    _searchFocus.unfocus();
    context.read<GoToProvider>().clearSearch();
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

  Future<void> _refresh() =>
      context.read<GoToProvider>().loadCustomers(refresh: true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: const _GoToAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            _SearchField(
              focusNode: _searchFocus,
              onChanged: _handleSearch,
              onClear: _clearSearch,
            ),
            Expanded(
              child: _Body(
                scrollController: _scrollController,
                onCustomerTap: _viewCustomer,
                onRetry: _refresh,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── App Bar ────────────────────────────────────────────────────────────────

class _GoToAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _GoToAppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.white,
      automaticallyImplyLeading: false,
      title: const Text(
        'Go To',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: Color(0xFF111418),
        ),
      ),
      actions: [
        Selector<GoToProvider, int>(
          selector: (_, p) => p.totalCustomers,
          builder: (_, total, child) {
            if (total == 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B8CEE).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$total customers',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2B8CEE),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFFDBE0E6)),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);
}

// ─── Search Field (self-contained) ──────────────────────────────────────────

class _SearchField extends StatefulWidget {
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    widget.onChanged(_controller.text);
    setState(() {});
  }

  void _clear() {
    _controller.clear();
    widget.onClear();
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.focusNode.hasFocus
                ? const Color(0xFF2B8CEE)
                : const Color(0xFFE0E0E0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _controller,
          focusNode: widget.focusNode,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Search by customer or shop name…',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
            prefixIcon: Icon(Icons.search,
                color: Colors.grey.shade400, size: 22),
            suffixIcon: hasText
                ? IconButton(
                    icon: Icon(Icons.clear,
                        size: 18, color: Colors.grey.shade500),
                    onPressed: _clear,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }
}

// ─── Body Router ────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  final ScrollController scrollController;
  final ValueChanged<CustomerModel> onCustomerTap;
  final VoidCallback onRetry;

  const _Body({
    required this.scrollController,
    required this.onCustomerTap,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<GoToProvider, _ViewState>(
      selector: (_, p) => _ViewState(
        isLoading: p.isLoadingCustomers && p.allCustomers.isEmpty,
        hasError: p.error != null && p.allCustomers.isEmpty,
        isSearching: p.searchQuery.isNotEmpty,
        isEmpty: !p.isLoadingCustomers &&
            p.allCustomers.isEmpty &&
            p.searchQuery.isEmpty,
      ),
      builder: (_, state, child) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _buildChild(state),
      ),
    );
  }

  Widget _buildChild(_ViewState state) {
    if (state.isLoading) {
      return const _SkeletonList(key: ValueKey('loading'));
    }
    if (state.hasError) {
      return _ErrorView(key: const ValueKey('error'), onRetry: onRetry);
    }
    if (state.isSearching) {
      return _SearchResultsView(
        key: const ValueKey('search'),
        onTap: onCustomerTap,
      );
    }
    if (state.isEmpty) {
      return const _EmptyView(key: ValueKey('empty'));
    }
    return _CustomerListView(
      key: const ValueKey('list'),
      scrollController: scrollController,
      onTap: onCustomerTap,
    );
  }
}

@immutable
class _ViewState {
  final bool isLoading;
  final bool hasError;
  final bool isSearching;
  final bool isEmpty;

  const _ViewState({
    required this.isLoading,
    required this.hasError,
    required this.isSearching,
    required this.isEmpty,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ViewState &&
          runtimeType == other.runtimeType &&
          isLoading == other.isLoading &&
          hasError == other.hasError &&
          isSearching == other.isSearching &&
          isEmpty == other.isEmpty;

  @override
  int get hashCode =>
      isLoading.hashCode ^ hasError.hashCode ^ isSearching.hashCode ^ isEmpty.hashCode;
}

// ─── Customer List (paginated) ──────────────────────────────────────────────

class _CustomerListView extends StatelessWidget {
  final ScrollController scrollController;
  final ValueChanged<CustomerModel> onTap;

  const _CustomerListView({
    super.key,
    required this.scrollController,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () =>
          context.read<GoToProvider>().loadCustomers(refresh: true),
      color: const Color(0xFF2B8CEE),
      backgroundColor: Colors.white,
      child: CustomScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _RecentSearchesSection(onTap: onTap),
          const _AllCustomersHeader(),
          _CustomerSliverList(onTap: onTap),
          const _LoadMoreIndicator(),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

class _RecentSearchesSection extends StatelessWidget {
  final ValueChanged<CustomerModel> onTap;

  const _RecentSearchesSection({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Selector<GoToProvider, List<CustomerModel>>(
      selector: (_, p) => p.recentSearches,
      builder: (_, recents, child) {
        if (recents.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

        final items = recents.take(3).toList();
        return SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                title: 'RECENT',
                trailing: GestureDetector(
                  onTap: context.read<GoToProvider>().clearRecentSearches,
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF2B8CEE),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              ...items.map(
                (c) => _CustomerTile(
                  customer: c,
                  onTap: () => onTap(c),
                  showHistoryIcon: true,
                ),
              ),
              const Divider(height: 1, color: Color(0xFFEEF0F2)),
            ],
          ),
        );
      },
    );
  }
}

class _AllCustomersHeader extends StatelessWidget {
  const _AllCustomersHeader();

  @override
  Widget build(BuildContext context) {
    return Selector<GoToProvider, ({int loaded, int total})>(
      selector: (_, p) => (loaded: p.allCustomers.length, total: p.totalCustomers),
      builder: (_, data, child) {
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Text(
                  'ALL CUSTOMERS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                if (data.total > 0)
                  Text(
                    '${data.loaded} / ${data.total}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
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

class _CustomerSliverList extends StatelessWidget {
  final ValueChanged<CustomerModel> onTap;

  const _CustomerSliverList({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Selector<GoToProvider, List<CustomerModel>>(
      selector: (_, p) => p.allCustomers,
      builder: (_, customers, child) {
        return SliverList.builder(
          itemCount: customers.length,
          itemBuilder: (_, index) => _CustomerTile(
            customer: customers[index],
            onTap: () => onTap(customers[index]),
          ),
        );
      },
    );
  }
}

class _LoadMoreIndicator extends StatelessWidget {
  const _LoadMoreIndicator();

  @override
  Widget build(BuildContext context) {
    return Selector<GoToProvider, bool>(
      selector: (_, p) => p.isLoadingMore,
      builder: (_, isLoading, child) {
        if (!isLoading) return const SliverToBoxAdapter(child: SizedBox.shrink());
        return const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF2B8CEE),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Search Results ─────────────────────────────────────────────────────────

class _SearchResultsView extends StatelessWidget {
  final ValueChanged<CustomerModel> onTap;

  const _SearchResultsView({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<GoToProvider,
        ({bool isSearching, String? error, List<CustomerModel> results})>(
      selector: (_, p) => (
        isSearching: p.isSearching,
        error: p.error,
        results: p.searchResults,
      ),
      builder: (_, state, child) {
        if (state.isSearching) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF2B8CEE)),
          );
        }
        if (state.error != null) {
          return _ErrorBanner(
            message: state.error!,
            onClear: context.read<GoToProvider>().clearError,
          );
        }
        if (state.results.isEmpty) {
          return const _EmptySearchView();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                '${state.results.length} result${state.results.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: state.results.length,
                itemBuilder: (_, i) => _CustomerTile(
                  customer: state.results[i],
                  onTap: () => onTap(state.results[i]),
                  showAddress: true,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Customer Tile ──────────────────────────────────────────────────────────

class _CustomerTile extends StatelessWidget {
  final CustomerModel customer;
  final VoidCallback onTap;
  final bool showAddress;
  final bool showHistoryIcon;

  const _CustomerTile({
    required this.customer,
    required this.onTap,
    this.showAddress = false,
    this.showHistoryIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        splashColor: const Color(0xFF2B8CEE).withValues(alpha: 0.05),
        highlightColor: const Color(0xFF2B8CEE).withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade100),
            ),
          ),
          child: Row(
            children: [
              Hero(
                tag: 'customer_avatar_${customer.id}',
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: showHistoryIcon
                        ? Colors.grey.shade100
                        : const Color(0xFF2B8CEE).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    showHistoryIcon ? Icons.history : Icons.storefront_outlined,
                    color: showHistoryIcon
                        ? Colors.grey.shade500
                        : const Color(0xFF2B8CEE),
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.shopName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111418),
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      customer.name,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showAddress && customer.shopAddress.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        customer.shopAddress,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (customer.location?.isValid ?? false)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on,
                          size: 12, color: Colors.green.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'GPS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Color(0xFF617589),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── UX States ──────────────────────────────────────────────────────────────

class _SkeletonList extends StatelessWidget {
  const _SkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: 10,
      itemBuilder: (_, __) => const _SkeletonTile(),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 140,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 10,
                  width: 90,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorView({
    super.key,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'Could not load customers',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Pull down to refresh or try again',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try Again'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2B8CEE),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'No customers yet',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Your customer list will appear here',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _EmptySearchView extends StatelessWidget {
  const _EmptySearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_outlined,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'No customers found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF617589),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onClear;

  const _ErrorBanner({required this.message, required this.onClear});

  @override
  Widget build(BuildContext context) {
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
              child: Text(
                message,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onClear,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared ─────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF617589),
              letterSpacing: 0.8,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}