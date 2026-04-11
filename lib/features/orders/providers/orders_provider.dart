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

  // ApiService is injected so the whole app shares one Dio instance.
  OrdersProvider(this._apiService);

  List<OrderModel> _orders = [];
  List<OrderModel> get orders => _orders;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  DateTime? _lastUpdated;
  DateTime? get lastUpdated => _lastUpdated;

  // ─── FETCH ────────────────────────────────────────────────────────────────

  Future<void> fetchOrders() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('📱 Fetching orders...');

      final partnerId = StorageService.getPartnerId();
      debugPrint('🔑 Partner ID: $partnerId');

      final response = await _apiService.dio.get(
        ApiEndpoints.pendingOrders,
        queryParameters: {
          'onlyUnsettled': 'true',
          if (partnerId != null) 'partnerId': partnerId,
        },
      );

      debugPrint('📦 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List
            ? response.data
            : (response.data['orders'] ?? []);

        _orders = data.map((json) => OrderModel.fromJson(json)).toList();
        _lastUpdated = DateTime.now();
        _error = null;
        debugPrint('✅ Loaded ${_orders.length} orders');
      }
    } on DioException catch (e) {
      _error = handleDioError(e, entityName: 'orders');
      debugPrint('❌ DioException: ${e.type} - ${e.message}');
      _orders = [];
    } catch (e) {
      _error = 'Unexpected error: ${e.toString()}';
      debugPrint('❌ Unexpected error: $e');
      _orders = [];
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
    } catch (e) {
      debugPrint('⚠️ Order not found: $id');
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}