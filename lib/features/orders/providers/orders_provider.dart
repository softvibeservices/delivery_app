// lib/features/orders/providers/orders_provider.dart

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../config/api_endpoints.dart';
import '../../../core/utils/dio_error_handler.dart';
import '../models/order_model.dart';

class OrdersProvider extends ChangeNotifier {
  final ApiService _apiService;

  OrdersProvider(this._apiService);

  // ─── State ────────────────────────────────────────────────────────────────

  List<OrderModel> _orders = [];
  List<OrderModel> get orders => _orders;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  DateTime? _lastUpdated;
  DateTime? get lastUpdated => _lastUpdated;

  /// True once the first successful fetch has completed.
  bool _hasFetched = false;
  bool get hasFetched => _hasFetched;

  // ─── FETCH IF NEEDED ──────────────────────────────────────────────────────
  //
  // Called by PendingOrdersScreen on mount.  Smart rules:
  //   1. Never already loading  → skip
  //   2. Never fetched          → fetch
  //   3. Last fetch errored     → retry
  //   4. Data stale (> 5 min)   → refresh
  //   5. Otherwise              → skip (use cached data)
  //
  // This guarantees the screen always shows data on first open without
  // hammering the API on every tab switch.

  static const _staleDuration = Duration(minutes: 5);

  Future<void> fetchIfNeeded() async {
    if (_isLoading) return; // already in-flight

    final isStale = _lastUpdated == null ||
        DateTime.now().difference(_lastUpdated!) > _staleDuration;

    if (!_hasFetched || _error != null || isStale) {
      await fetchOrders();
    }
  }

  // ─── FETCH ────────────────────────────────────────────────────────────────

  Future<void> fetchOrders() async {
    if (_isLoading) return;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('📱 Fetching orders...');

      final partnerId = StorageService.getPartnerId();
      final userId = StorageService.getUserId(); // ← FIX: scopes orders to your admin only
      debugPrint('🔑 Partner ID: $partnerId | Admin (userId): $userId');

      final response = await _apiService.dio.get(
        ApiEndpoints.pendingOrders,
        queryParameters: {
          'onlyUnsettled': 'true',
          if (partnerId != null) 'partnerId': partnerId,
          if (userId != null) 'userId': userId, // ← FIX: without this, unassigned orders from ALL admins were returned
        },
      );

      debugPrint('📦 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List
            ? response.data as List
            : (response.data['orders'] as List? ?? []);

        _orders = data
            .map((json) => OrderModel.fromJson(json as Map<String, dynamic>))
            .toList();
        _lastUpdated = DateTime.now();
        _hasFetched = true;
        _error = null;
        debugPrint('✅ Loaded ${_orders.length} orders');
      }
    } on DioException catch (e) {
      _error = handleDioError(e, entityName: 'orders');
      debugPrint('❌ DioException: ${e.type} - ${e.message}');
      // Keep any existing orders visible so the user sees something
      // (empty list would appear as "no orders" which is misleading on error)
      if (!_hasFetched) _orders = [];
    } catch (e) {
      _error = 'Unexpected error: ${e.toString()}';
      debugPrint('❌ Unexpected error: $e');
      if (!_hasFetched) _orders = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── UPDATE STATUS ────────────────────────────────────────────────────────

  Future<bool> updateOrderStatus({
    required String orderId,
    required String status,
    String? note,
  }) async {
    try {
      debugPrint('🔄 Updating order $orderId to status: $status');

      final response = await _apiService.dio.patch(
        ApiEndpoints.updateOrderStatus,
        data: {
          'orderId': orderId,
          'status': status,
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );

      if (response.statusCode == 200) {
        // Update the local copy immediately so the UI snaps without waiting
        // for a full refetch — then fetch to sync with server.
        _updateLocalOrderStatus(orderId, status);
        await fetchOrders();
        debugPrint('✅ Order updated and list refreshed');
        return true;
      }

      debugPrint('❌ Update failed: ${response.statusCode}');
      return false;
    } on DioException catch (e) {
      debugPrint('❌ Update error: ${e.type} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('❌ Unexpected update error: $e');
      return false;
    }
  }

  /// Optimistically update a single order's delivery status in the local list
  /// so the UI reflects the change before the refetch completes.
  void _updateLocalOrderStatus(String orderId, String newStatus) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return;

    // OrderModel is immutable, so we rebuild with fromJson using the local data
    final existing = _orders[index];
    final now = DateTime.now();
    final updated = OrderModel(
      id: existing.id,
      userId: existing.userId,
      orderId: existing.orderId,
      serialNumber: existing.serialNumber,
      shopName: existing.shopName,
      customerId: existing.customerId,
      customerName: existing.customerName,
      customerAddress: existing.customerAddress,
      customerContact: existing.customerContact,
      customerLat: existing.customerLat,
      customerLng: existing.customerLng,
      items: existing.items,
      freeItems: existing.freeItems,
      quantitySummary: existing.quantitySummary,
      subtotal: existing.subtotal,
      discountPercentage: existing.discountPercentage,
      total: existing.total,
      remarks: existing.remarks,
      status: existing.status,
      settlementMethod: existing.settlementMethod,
      settlementAmount: existing.settlementAmount,
      deliveryPartnerId: existing.deliveryPartnerId,
      deliveryStatus: newStatus,
      deliveryAssignedAt: existing.deliveryAssignedAt,
      deliveryOnTheWayAt: newStatus == 'On the Way'
          ? now
          : existing.deliveryOnTheWayAt,
      deliveryCompletedAt: newStatus == 'Delivered'
          ? now
          : existing.deliveryCompletedAt,
      deliveryNotes: existing.deliveryNotes,
      createdAt: existing.createdAt,
      updatedAt: now,
    );

    _orders[index] = updated;
    notifyListeners();
  }

  // ─── FILTER ───────────────────────────────────────────────────────────────

  List<OrderModel> filterOrders(String query) {
    if (query.isEmpty) return _orders;
    final lowerQuery = query.toLowerCase();
    return _orders.where((order) {
      return order.customerName.toLowerCase().contains(lowerQuery) ||
          (order.shopName?.toLowerCase().contains(lowerQuery) ?? false) ||
          (order.customerContact?.contains(lowerQuery) ?? false) ||
          order.orderId.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  // ─── SORT ─────────────────────────────────────────────────────────────────

  List<OrderModel> sortOrders(List<OrderModel> orders, String sortBy) {
    final sorted = List<OrderModel>.from(orders);
    switch (sortBy) {
      case 'Pending':
        return sorted
            .where((o) => o.deliveryStatus == 'Pending')
            .toList();
      case 'On the Way':
        return sorted
            .where((o) => o.deliveryStatus == 'On the Way')
            .toList();
      case 'Quantity':
        sorted.sort((a, b) => b.totalItems.compareTo(a.totalItems));
        break;
      default:
        break;
    }
    return sorted;
  }

  // ─── GET BY ID ────────────────────────────────────────────────────────────

  OrderModel? getOrderById(String id) {
    try {
      return _orders.firstWhere((order) => order.id == id);
    } catch (_) {
      debugPrint('⚠️ Order not found: $id');
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}