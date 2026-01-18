// lib/features/orders/providers/orders_provider.dart

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../config/api_endpoints.dart';
import '../models/order_model.dart';

class OrdersProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<OrderModel> _orders = [];
  List<OrderModel> get orders => _orders;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  DateTime? _lastUpdated;
  DateTime? get lastUpdated => _lastUpdated;

  /// Fetch pending orders from the API
  Future<void> fetchOrders() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('📱 Fetching orders...');
      
      final partnerId = await StorageService.getPartnerId();
      debugPrint('🔑 Partner ID: $partnerId');

      final response = await _apiService.dio.get(
        ApiEndpoints.pendingOrders,
        queryParameters: {
          'onlyUnsettled': 'true',
          if (partnerId != null) 'partnerId': partnerId,
        },
      );

      debugPrint('📦 Response status: ${response.statusCode}');
      debugPrint('📦 Response data: ${response.data}');

      if (response.statusCode == 200) {
        // Handle both possible response formats
        final List<dynamic> data = response.data is List 
            ? response.data 
            : (response.data['orders'] ?? []);
        
        _orders = data.map((json) => OrderModel.fromJson(json)).toList();
        _lastUpdated = DateTime.now();
        _error = null;
        
        debugPrint('✅ Successfully loaded ${_orders.length} orders');
      }
    } on DioException catch (e) {
      _error = _handleDioError(e);
      debugPrint('❌ DioException: ${e.type} - ${e.message}');
      debugPrint('❌ Error details: $_error');
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

  /// Update order delivery status
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

      debugPrint('📦 Update response: ${response.statusCode}');
      debugPrint('📦 Update response data: ${response.data}');

      if (response.statusCode == 200) {
        // Refresh the entire order list from server
        await fetchOrders();
        debugPrint('✅ Order updated and list refreshed');
        return true;
      }
      
      debugPrint('❌ Update failed with status: ${response.statusCode}');
      return false;
    } on DioException catch (e) {
      debugPrint('❌ Update error: ${e.type} - ${e.message}');
      debugPrint('❌ Response: ${e.response?.data}');
      return false;
    } catch (e) {
      debugPrint('❌ Unexpected update error: $e');
      return false;
    }
  }

  /// Filter orders by search query
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

  /// Sort orders based on criteria
  List<OrderModel> sortOrders(List<OrderModel> orders, String sortBy) {
    final sorted = List<OrderModel>.from(orders);

    switch (sortBy) {
      case 'Pending':
        // Filter only pending orders
        return sorted.where((order) => order.deliveryStatus == 'Pending').toList();
      
      case 'On the Way':
        // Filter only "On the Way" orders
        return sorted.where((order) => order.deliveryStatus == 'On the Way').toList();
      
      case 'Quantity':
        // Sort by total items (highest first)
        sorted.sort((a, b) => b.totalItems.compareTo(a.totalItems));
        break;
      
      default:
        // 'All Orders' - keep original order (already sorted by creation time from API)
        break;
    }

    return sorted;
  }

  /// Get a specific order by ID
  OrderModel? getOrderById(String id) {
    try {
      return _orders.firstWhere((order) => order.id == id);
    } catch (e) {
      debugPrint('⚠️ Order not found: $id');
      return null;
    }
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
          return 'No orders found.';
        } else if (statusCode == 500) {
          return 'Server error. Please try again later.';
        }
        return 'Failed to fetch orders (Error $statusCode)';
      
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      
      case DioExceptionType.connectionError:
        return 'No internet connection. Please check your network.';
      
      default:
        return 'Failed to fetch orders. Please try again.';
    }
  }
}