// lib/features/go_to/screens/go_to_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/go_to_provider.dart';
import '../models/customer_model.dart';
import '../../orders/widgets/bottom_nav_bar.dart';
import 'customer_detail_screen.dart';

class GoToScreen extends StatefulWidget {
  const GoToScreen({super.key});

  @override
  State<GoToScreen> createState() => _GoToScreenState();
}

class _GoToScreenState extends State<GoToScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _handleSearch(String query) {
    context.read<GoToProvider>().searchCustomers(query);
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<GoToProvider>().clearSearch();
    // Force rebuild to show recent searches
    setState(() {});
  }

  // ✅ FIXED: Simplified navigation with proper error handling
  Future<void> _viewCustomerDetails(CustomerModel customer) async {
    try {
      // Add to recent searches
      await context.read<GoToProvider>().addToRecentSearches(customer);
      
      // Navigate to detail screen
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CustomerDetailScreen(customer: customer),
        ),
      );
    } catch (e) {
      debugPrint('Navigation error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white.withValues(alpha: 0.8),
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'Search Customer',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: -0.015 * 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Column(
            children: [
              Container(
                height: 1,
                color: const Color(0xFFDBE0E6),
              ),
              _buildSearchBar(),
            ],
          ),
        ),
      ),
      body: Consumer<GoToProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recent Searches Section (show only when search is empty)
                if (provider.recentSearches.isNotEmpty &&
                    provider.searchQuery.isEmpty)
                  _buildRecentSearches(provider),

                // Search Results Section
                if (provider.searchQuery.isNotEmpty)
                  _buildSearchResults(provider),

                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: const OrdersBottomNavBar(selectedIndex: 3),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F2F4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          onChanged: (value) {
            _handleSearch(value);
            setState(() {}); // ✅ Rebuild to show/hide X button
          },
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Search customer by name or shop...',
            hintStyle: const TextStyle(
              color: Color(0xFF617589),
              fontSize: 16,
            ),
            prefixIcon: const Icon(
              Icons.search,
              color: Color(0xFF617589),
              size: 24,
            ),
            // ✅ Always show X button when there's text
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: _clearSearch,
                    color: const Color(0xFF617589),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSearches(GoToProvider provider) {
    // ✅ FIXED: Show only last 3 recent searches
    final recentToShow = provider.recentSearches.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Searches',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.015 * 18,
                ),
              ),
              if (provider.recentSearches.isNotEmpty)
                TextButton(
                  onPressed: () => provider.clearRecentSearches(),
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                      color: Color(0xFF2B8CEE),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        ...recentToShow.map((customer) => _recentSearchItem(customer)),
      ],
    );
  }

  Widget _recentSearchItem(CustomerModel customer) {
    return Column(
      children: [
        Material(
          color: Colors.white,
          child: InkWell(
            onTap: () => _viewCustomerDetails(customer),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B8CEE).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.history,
                      color: Color(0xFF2B8CEE),
                      size: 24,
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
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          customer.name,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF617589),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // ✅ Show arrow icon instead of buttons
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Color(0xFF617589),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          color: const Color(0xFFDBE0E6),
        ),
      ],
    );
  }

  Widget _buildSearchResults(GoToProvider provider) {
    if (provider.isSearching) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF2B8CEE),
          ),
        ),
      );
    }

    if (provider.error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(16),
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
                child: Text(
                  provider.error!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.search_off,
                size: 72,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 16),
              const Text(
                'No customers found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Try a different search term',
                style: TextStyle(
                  color: Color(0xFF617589),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Found ${provider.searchResults.length} ${provider.searchResults.length == 1 ? 'customer' : 'customers'}',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF617589),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: provider.searchResults
                .map((customer) => _searchResultCard(customer))
                .toList(),
          ),
        ),
      ],
    );
  }

  // ✅ FIXED: Simplified card without Call/Navigate buttons
  Widget _searchResultCard(CustomerModel customer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDBE0E6)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _viewCustomerDetails(customer),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B8CEE).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.storefront,
                    color: Color(0xFF2B8CEE),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.shopName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        customer.name,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF617589),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        customer.shopAddress,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF617589),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (customer.location?.isValid ?? false) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.green.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Location available',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Color(0xFF617589),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}