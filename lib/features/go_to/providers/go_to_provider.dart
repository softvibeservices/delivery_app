// lib/features/go_to/providers/go_to_provider.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../config/api_endpoints.dart';
import '../../../core/utils/dio_error_handler.dart';
import '../models/customer_model.dart';

class GoToProvider extends ChangeNotifier {
  final ApiService _apiService;

  GoToProvider(this._apiService) {
    _loadRecentSearches();
  }

  // ─── State ────────────────────────────────────────────────────────────────

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

  CustomerModel? _selectedCustomer;
  CustomerModel? get selectedCustomer => _selectedCustomer;

  bool _isLoadingDetails = false;
  bool get isLoadingDetails => _isLoadingDetails;

  static const int _maxRecentSearches = 10;

  // ─── RECENT SEARCHES (via StorageService — no direct SharedPreferences) ────

  void _loadRecentSearches() {
    try {
      final raw = StorageService.getRecentSearches();
      if (raw != null) {
        final List<dynamic> decoded = json.decode(raw);
        _recentSearches = decoded
            .map((j) => CustomerModel.fromJson(j as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error loading recent searches: $e');
    }
  }

  Future<void> _saveRecentSearches() async {
    try {
      final encoded = json.encode(
        _recentSearches.map((c) => c.toJson()).toList(),
      );
      await StorageService.saveRecentSearches(encoded);
    } catch (e) {
      debugPrint('❌ Error saving recent searches: $e');
    }
  }

  Future<void> addToRecentSearches(CustomerModel customer) async {
    _recentSearches.removeWhere((c) => c.id == customer.id);
    _recentSearches.insert(0, customer);

    if (_recentSearches.length > _maxRecentSearches) {
      _recentSearches = _recentSearches.take(_maxRecentSearches).toList();
    }

    await _saveRecentSearches();
    notifyListeners();
  }

  Future<void> clearRecentSearches() async {
    _recentSearches.clear();
    await StorageService.clearRecentSearches();
    notifyListeners();
  }

  // ─── SEARCH ───────────────────────────────────────────────────────────────

  Future<void> searchCustomers(String query) async {
    _searchQuery = query;

    if (query.trim().isEmpty) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(milliseconds: 500),
      () => _performSearch(query),
    );
  }

  Future<void> _performSearch(String query) async {
    try {
      _isSearching = true;
      _error = null;
      notifyListeners();

      debugPrint('🔍 Searching customers: $query');

      final response = await _apiService.dio.get(
        ApiEndpoints.searchCustomers,
        queryParameters: {'q': query},
      );

      if (response.statusCode == 200) {
        final customers = response.data['customers'] as List?;
        _searchResults = customers
                ?.map((json) => CustomerModel.fromJson(json))
                .toList() ??
            [];
        debugPrint('✅ Found ${_searchResults.length} customers');
      }
    } on DioException catch (e) {
      _error = handleDioError(e, entityName: 'customers');
      debugPrint('❌ Search error: ${e.type} — ${e.message}');
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  // ─── CUSTOMER DETAILS ─────────────────────────────────────────────────────

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

      if (response.statusCode == 200) {
        final customerData = response.data['customer'];
        if (customerData != null) {
          _selectedCustomer = CustomerModel.fromJson(customerData);
          await addToRecentSearches(_selectedCustomer!);
          debugPrint('✅ Customer details loaded');
          return _selectedCustomer;
        }
      }
      return null;
    } on DioException catch (e) {
      _error = handleDioError(e, entityName: 'customer');
      debugPrint('❌ Details error: ${e.type} — ${e.message}');
      return null;
    } finally {
      _isLoadingDetails = false;
      notifyListeners();
    }
  }

  // ─── CLEAR ────────────────────────────────────────────────────────────────

  void clearSearch() {
    _searchQuery = '';
    _searchResults = [];
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}