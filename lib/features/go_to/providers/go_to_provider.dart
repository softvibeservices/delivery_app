// lib/features/go_to/providers/go_to_provider.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/api_service.dart';
import '../../../config/api_endpoints.dart';
import '../models/customer_model.dart';

class GoToProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  // Search state
  List<CustomerModel> _searchResults = [];
  List<CustomerModel> get searchResults => _searchResults;

  List<CustomerModel> _recentSearches = [];
  List<CustomerModel> get recentSearches => _recentSearches;

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  String? _error;
  String? get error => _error;

  Timer? _debounceTimer;

  // Selected customer for detail view
  CustomerModel? _selectedCustomer;
  CustomerModel? get selectedCustomer => _selectedCustomer;

  bool _isLoadingDetails = false;
  bool get isLoadingDetails => _isLoadingDetails;

  static const String _recentSearchesKey = 'recent_customer_searches';
  static const int _maxRecentSearches = 10;

  GoToProvider() {
    _loadRecentSearches();
  }

  /// Load recent searches from storage
  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? searchesJson = prefs.getString(_recentSearchesKey);
      
      if (searchesJson != null) {
        final List<dynamic> searchesList = json.decode(searchesJson);
        _recentSearches = searchesList
            .map((json) => CustomerModel.fromJson(json))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error loading recent searches: $e');
    }
  }

  /// Save recent searches to storage
  Future<void> _saveRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final searchesJson = json.encode(
        _recentSearches.map((c) => c.toJson()).toList(),
      );
      await prefs.setString(_recentSearchesKey, searchesJson);
    } catch (e) {
      debugPrint('❌ Error saving recent searches: $e');
    }
  }

  /// Add customer to recent searches
  Future<void> addToRecentSearches(CustomerModel customer) async {
    // Remove if already exists
    _recentSearches.removeWhere((c) => c.id == customer.id);
    
    // Add to beginning
    _recentSearches.insert(0, customer);
    
    // Limit to max
    if (_recentSearches.length > _maxRecentSearches) {
      _recentSearches = _recentSearches.take(_maxRecentSearches).toList();
    }
    
    await _saveRecentSearches();
    notifyListeners();
  }

  /// Clear all recent searches
  Future<void> clearRecentSearches() async {
    _recentSearches.clear();
    await _saveRecentSearches();
    notifyListeners();
  }

  /// Search customers with debouncing
  Future<void> searchCustomers(String query) async {
    _searchQuery = query;
    
    if (query.trim().isEmpty) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    // Cancel previous timer
    _debounceTimer?.cancel();

    // Start new timer
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      await _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    try {
      _isSearching = true;
      _error = null;
      notifyListeners();

      debugPrint('🔍 Searching customers for: $query');

      final response = await _apiService.dio.get(
        ApiEndpoints.searchCustomers,
        queryParameters: {'q': query},
      );

      debugPrint('📦 Search response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final customers = response.data['customers'] as List?;
        if (customers != null) {
          _searchResults = customers
              .map((json) => CustomerModel.fromJson(json))
              .toList();
          debugPrint('✅ Found ${_searchResults.length} customers');
        } else {
          _searchResults = [];
        }
      }
    } on DioException catch (e) {
      _error = _handleDioError(e);
      debugPrint('❌ Search error: ${e.type} - ${e.message}');
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Get customer details
  Future<CustomerModel?> getCustomerDetails(String customerId) async {
    try {
      _isLoadingDetails = true;
      _error = null;
      notifyListeners();

      debugPrint('📋 Fetching customer details: $customerId');

      final response = await _apiService.dio.get(
        ApiEndpoints.customerDetails,
        queryParameters: {'customerId': customerId},
      );

      debugPrint('📦 Details response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final customerData = response.data['customer'];
        if (customerData != null) {
          _selectedCustomer = CustomerModel.fromJson(customerData);
          debugPrint('✅ Customer details loaded');
          
          // Add to recent searches
          await addToRecentSearches(_selectedCustomer!);
          
          return _selectedCustomer;
        }
      }
      return null;
    } on DioException catch (e) {
      _error = _handleDioError(e);
      debugPrint('❌ Details error: ${e.type} - ${e.message}');
      return null;
    } finally {
      _isLoadingDetails = false;
      notifyListeners();
    }
  }

  /// Clear search
  void clearSearch() {
    _searchQuery = '';
    _searchResults = [];
    _error = null;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Handle Dio errors
  String _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please check your internet.';

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 401) {
          return 'Unauthorized. Please login again.';
        } else if (statusCode == 404) {
          return 'Customer not found.';
        } else if (statusCode == 500) {
          return 'Server error. Please try again later.';
        }
        return 'Failed to search customers (Error $statusCode)';

      case DioExceptionType.cancel:
        return 'Request was cancelled.';

      case DioExceptionType.connectionError:
        return 'No internet connection.';

      default:
        return 'Failed to search customers.';
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}