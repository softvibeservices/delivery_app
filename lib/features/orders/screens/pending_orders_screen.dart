import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../config/api_endpoints.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class PendingOrdersScreen extends StatefulWidget {
  const PendingOrdersScreen({super.key});

  @override
  State<PendingOrdersScreen> createState() => _PendingOrdersScreenState();
}

class _PendingOrdersScreenState extends State<PendingOrdersScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  List<dynamic> _orders = [];
  List<dynamic> _filteredOrders = [];
  String _searchQuery = '';
  DateTime? _lastUpdated;
  String _selectedSort = 'All Orders';

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    try {
      final partnerId = await StorageService.getPartnerId();
      debugPrint('Fetching orders for partnerId: $partnerId');

      final res = await _api.dio.get(
        ApiEndpoints.pendingOrders,
        queryParameters: {
          'onlyUnsettled': 'true',
          if (partnerId != null) 'partnerId': partnerId,
        },
      );

      debugPrint('API Response: ${res.data}');

      if (mounted) {
        setState(() {
          _orders = res.data is List ? res.data : [];
          _filteredOrders = _orders;
          _sortOrders();
          _loading = false;
          _lastUpdated = DateTime.now();
        });
      }
    } catch (e) {
      debugPrint('Error fetching orders: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _sortOrders() {
    switch (_selectedSort) {
      case 'Time':
        _filteredOrders.sort((orderA, orderB) =>
            DateTime.parse(orderB['createdAt']).compareTo(DateTime.parse(orderA['createdAt'])));
        break;
      case 'Quantity':
        _filteredOrders.sort((orderA, orderB) {
          final totalA = orderA['items']?.fold(0, (sum, item) => sum + (item['quantity'] ?? 0)) ?? 0;
          final totalB = orderB['items']?.fold(0, (sum, item) => sum + (item['quantity'] ?? 0)) ?? 0;
          return totalB.compareTo(totalA);
        });
        break;
      default:
        break;
    }
  }

  void _filterOrders(String query) {
    setState(() {
      _searchQuery = query;
      _filteredOrders = _orders.where((order) {
        final customerName = order['customerName']?.toString().toLowerCase() ?? '';
        final shopName = order['shopName']?.toString().toLowerCase() ?? '';
        return customerName.contains(query.toLowerCase()) ||
               shopName.contains(query.toLowerCase());
      }).toList();
      _sortOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final isEmpty = !_loading && _filteredOrders.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white.withOpacity(0.9),
        title: const Text(
          'Pending Orders',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {},
              ),
              if (_filteredOrders.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${_filteredOrders.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _fetchOrders,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
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
                                    onPressed: () {
                                      _filterOrders('');
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          height: 44,
                          width: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.tune, color: Colors.grey),
                            onPressed: () {},
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_lastUpdated != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Last updated: ${DateFormat('hh:mm a').format(_lastUpdated!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _chip('All Orders', active: _selectedSort == 'All Orders', color: primary, onTap: () {
                            setState(() {
                              _selectedSort = 'All Orders';
                              _sortOrders();
                            });
                          }),
                          _chip('Time', active: _selectedSort == 'Time', color: primary, onTap: () {
                            setState(() {
                              _selectedSort = 'Time';
                              _sortOrders();
                            });
                          }),
                          _chip('Quantity', active: _selectedSort == 'Quantity', color: primary, onTap: () {
                            setState(() {
                              _selectedSort = 'Quantity';
                              _sortOrders();
                            });
                          }),
                        ],
                      ),
                    ),
                  ),

                  Expanded(
                    child: isEmpty
                        ? _emptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            itemCount: _filteredOrders.length,
                            itemBuilder: (context, index) {
                              return _orderCard(_filteredOrders[index], primary);
                            },
                          ),
                  ),
                ],
              ),
      ),

      bottomNavigationBar: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.list_alt, 'Orders', true, primary),
            _navItem(Icons.payments, 'Earnings', false, primary),
            _navItem(Icons.map, 'Map', false, primary),
            _navItem(Icons.person, 'Profile', false, primary),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, {bool active = false, required Color color, VoidCallback? onTap}) {
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

  Widget _orderCard(dynamic order, Color primary) {
    final status = order['deliveryStatus'] ?? 'Pending';
    final totalQuantity = order['items']?.fold(0, (sum, item) => sum + (item['quantity'] ?? 0)) ?? 0;
    final orderDate = order['createdAt'] != null
        ? DateFormat('MMM dd, hh:mm a').format(DateTime.parse(order['createdAt']))
        : '--';

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order['customerName'] ?? 'Customer',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      order['shopName'] ?? 'Shop',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                _statusBadge(status),
              ],
            ),

            const SizedBox(height: 14),

            _infoRow(Icons.call, order['customerContact'] ?? '--'),

            const SizedBox(height: 10),

            _infoRow(Icons.location_on, order['customerAddress'] ?? 'Delivery address'),

            const SizedBox(height: 10),

            Row(
              children: [
                Text(
                  'Order: $orderDate',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$totalQuantity items',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),

            const Divider(height: 30),

            SizedBox(
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 120,
                    child: ElevatedButton(
                      onPressed: () {
                        // Navigate to order details screen
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: primary,
                        side: BorderSide(color: primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('View'),
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: ElevatedButton(
                      onPressed: () {
                        // Update order status
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: status == 'Pending' ? primary : Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(status == 'Pending' ? 'On the Way' : 'Delivered'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey.shade100,
          child: Icon(icon, size: 18, color: Colors.grey),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _navItem(IconData icon, String label, bool active, Color primary) {
    return InkWell(
      onTap: () {},
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: active ? primary : Colors.grey),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: active ? FontWeight.bold : FontWeight.w500,
              color: active ? primary : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'No pending orders',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Pull down to refresh',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}