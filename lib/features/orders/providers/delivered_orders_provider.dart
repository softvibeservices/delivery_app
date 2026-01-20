// lib/features/orders/providers/delivered_orders_provider.dart

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/services/api_service.dart';
import '../../../config/api_endpoints.dart';
import '../models/order_model.dart';

class DeliveredOrdersProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

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

  // Statistics
  int get todayCount => _groupedOrders['today']?.length ?? 0;
  int get yesterdayCount => _groupedOrders['yesterday']?.length ?? 0;
  int get thisWeekCount => _groupedOrders['this_week']?.length ?? 0;
  int get olderCount => _groupedOrders['older']?.length ?? 0;

  /// Fetch delivered orders from API
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
      debugPrint('📦 Response data: ${response.data}');

      if (response.statusCode == 200) {
        _totalDeliveries = response.data['total'] ?? 0;
        
        final groups = response.data['groups'] as Map<String, dynamic>;
        
        _groupedOrders = {
          'today': (groups['today'] as List?)
              ?.map((json) => OrderModel.fromJson(json))
              .toList() ?? [],
          'yesterday': (groups['yesterday'] as List?)
              ?.map((json) => OrderModel.fromJson(json))
              .toList() ?? [],
          'this_week': (groups['this_week'] as List?)
              ?.map((json) => OrderModel.fromJson(json))
              .toList() ?? [],
          'older': (groups['older'] as List?)
              ?.map((json) => OrderModel.fromJson(json))
              .toList() ?? [],
        };

        _lastUpdated = DateTime.now();
        _error = null;
        
        debugPrint('✅ Successfully loaded $_totalDeliveries delivered orders');
        debugPrint('   Today: $todayCount, Yesterday: $yesterdayCount, This Week: $thisWeekCount, Older: $olderCount');
      }
    } on DioException catch (e) {
      _error = _handleDioError(e);
      debugPrint('❌ DioException: ${e.type} - ${e.message}');
      _groupedOrders = {
        'today': [],
        'yesterday': [],
        'this_week': [],
        'older': [],
      };
      _totalDeliveries = 0;
    } catch (e) {
      _error = 'Unexpected error: ${e.toString()}';
      debugPrint('❌ Unexpected error: $e');
      _groupedOrders = {
        'today': [],
        'yesterday': [],
        'this_week': [],
        'older': [],
      };
      _totalDeliveries = 0;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Filter orders by search query across all groups
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

  /// Get order by ID from all groups
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

  /// Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Handle Dio errors and return user-friendly messages
  String _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please check your internet connection.';
      
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 401) {
          return 'Unauthorized. Please login again.';
        } else if (statusCode == 404) {
          return 'No delivered orders found.';
        } else if (statusCode == 500) {
          return 'Server error. Please try again later.';
        }
        return 'Failed to fetch delivered orders (Error $statusCode)';
      
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      
      case DioExceptionType.connectionError:
        return 'No internet connection. Please check your network.';
      
      default:
        return 'Failed to fetch delivered orders. Please try again.';
    }
  }

  /// Get total deliveries for today
  int getTodayDeliveries() {
    return todayCount;
  }

  /// Get total deliveries for this week
  int getThisWeekDeliveries() {
    return todayCount + yesterdayCount + thisWeekCount;
  }

  /// Get total deliveries for this month (approximation based on available data)
  int getThisMonthDeliveries() {
    // This is an approximation - in a real app you'd need a separate API call
    return totalDeliveries;
  }
}