// lib/features/orders/providers/delivered_orders_provider.dart

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/services/api_service.dart';
import '../../../config/api_endpoints.dart';
import '../../../core/utils/dio_error_handler.dart';
import '../models/order_model.dart';

class DeliveredOrdersProvider extends ChangeNotifier {
  final ApiService _apiService;

  DeliveredOrdersProvider(this._apiService);

  Map<String, List<OrderModel>> _groupedOrders = {
    'today': [],
    'yesterday': [],
    'this_week': [],
    'older': [],
  };

  Map<String, List<OrderModel>> get groupedOrders => _groupedOrders;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  DateTime? _lastUpdated;
  DateTime? get lastUpdated => _lastUpdated;

  int _totalDeliveries = 0;
  int get totalDeliveries => _totalDeliveries;

  int get todayCount => _groupedOrders['today']?.length ?? 0;
  int get yesterdayCount => _groupedOrders['yesterday']?.length ?? 0;
  int get thisWeekCount => _groupedOrders['this_week']?.length ?? 0;
  int get olderCount => _groupedOrders['older']?.length ?? 0;

  // ─── FETCH ────────────────────────────────────────────────────────────────

  Future<void> fetchDeliveredOrders() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('📱 Fetching delivered orders...');

      final response = await _apiService.dio.get(
        ApiEndpoints.deliveredOrders,
      );

      debugPrint('📦 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        _totalDeliveries = response.data['total'] ?? 0;

        final groups = response.data['groups'] as Map<String, dynamic>;

        _groupedOrders = {
          'today': (groups['today'] as List?)
                  ?.map((json) => OrderModel.fromJson(json))
                  .toList() ??
              [],
          'yesterday': (groups['yesterday'] as List?)
                  ?.map((json) => OrderModel.fromJson(json))
                  .toList() ??
              [],
          'this_week': (groups['this_week'] as List?)
                  ?.map((json) => OrderModel.fromJson(json))
                  .toList() ??
              [],
          'older': (groups['older'] as List?)
                  ?.map((json) => OrderModel.fromJson(json))
                  .toList() ??
              [],
        };

        _lastUpdated = DateTime.now();
        _error = null;

        debugPrint('✅ Loaded $_totalDeliveries delivered orders');
        debugPrint(
          '   Today: $todayCount  Yesterday: $yesterdayCount  '
          'This week: $thisWeekCount  Older: $olderCount',
        );
      }
    } on DioException catch (e) {
      _error = handleDioError(e, entityName: 'delivered orders');
      debugPrint('❌ DioException: ${e.type} - ${e.message}');
      _resetGroups();
    } catch (e) {
      _error = 'Unexpected error: ${e.toString()}';
      debugPrint('❌ Unexpected error: $e');
      _resetGroups();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── FILTER ───────────────────────────────────────────────────────────────

  Map<String, List<OrderModel>> filterOrders(String query) {
    if (query.isEmpty) return _groupedOrders;

    final lowerQuery = query.toLowerCase();
    return _groupedOrders.map((key, orders) {
      final filtered = orders.where((order) {
        return order.customerName.toLowerCase().contains(lowerQuery) ||
            (order.shopName?.toLowerCase().contains(lowerQuery) ?? false) ||
            (order.customerContact?.contains(lowerQuery) ?? false) ||
            order.orderId.toLowerCase().contains(lowerQuery);
      }).toList();
      return MapEntry(key, filtered);
    });
  }

  // ─── GET BY ID ────────────────────────────────────────────────────────────

  OrderModel? getOrderById(String id) {
    for (final orders in _groupedOrders.values) {
      try {
        return orders.firstWhere((order) => order.id == id);
      } catch (e) {
        continue;
      }
    }
    debugPrint('⚠️ Order not found: $id');
    return null;
  }

  // ─── STATISTICS ───────────────────────────────────────────────────────────

  int getTodayDeliveries() => todayCount;
  int getThisWeekDeliveries() => todayCount + yesterdayCount + thisWeekCount;
  int getThisMonthDeliveries() => totalDeliveries;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _resetGroups() {
    _groupedOrders = {
      'today': [],
      'yesterday': [],
      'this_week': [],
      'older': [],
    };
    _totalDeliveries = 0;
  }
}