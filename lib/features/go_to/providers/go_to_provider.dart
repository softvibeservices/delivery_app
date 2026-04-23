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

  // ─── Search state ─────────────────────────────────────────────────────────

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

  // ─── Paginated all-customers list state ───────────────────────────────────

  List<CustomerModel> _allCustomers = [];
  List<CustomerModel> get allCustomers => _allCustomers;

  /// Running total from the server (for the header count badge).
  int _totalCustomers = 0;
  int get totalCustomers => _totalCustomers;

  int _currentPage = 1;
  bool _hasMore = false;
  bool get hasMore => _hasMore;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  bool _isLoadingCustomers = false;
  bool get isLoadingCustomers => _isLoadingCustomers;

  static const int _pageSize = 20;

  // ─── LOAD ALL CUSTOMERS (paginated) ───────────────────────────────────────

  /// Call on screen init or pull-to-refresh.
  /// [refresh] = true clears the existing list and starts from page 1.
  Future<void> loadCustomers({bool refresh = false}) async {
    if (_isLoadingCustomers || _isLoadingMore) return;
    if (!refresh && _isLoadingMore) return;

    if (refresh) {
      _allCustomers = [];
      _currentPage = 1;
      _hasMore = false;
      _isLoadingCustomers = true;
    } else {
      _isLoadingCustomers = true;
    }

    _error = null;
    notifyListeners();

    try {
      debugPrint('📋 Loading customers page $_currentPage...');

      final response = await _apiService.dio.get(
        ApiEndpoints.searchCustomers,
        queryParameters: {
          'page': _currentPage,
          'limit': _pageSize,
          // q is intentionally absent → triggers MODE 2 (paginated list)
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final List<dynamic> raw = data['customers'] as List? ?? [];
        final newCustomers =
            raw.map((j) => CustomerModel.fromJson(j as Map<String, dynamic>)).toList();

        if (refresh) {
          _allCustomers = newCustomers;
        } else {
          _allCustomers = [..._allCustomers, ...newCustomers];
        }

        _totalCustomers = (data['total'] as num?)?.toInt() ?? _allCustomers.length;
        _hasMore = data['hasMore'] as bool? ?? false;
        _currentPage++;

        debugPrint(
          '✅ Loaded ${newCustomers.length} customers '
          '(total: $_totalCustomers, hasMore: $_hasMore)',
        );
      }
    } on DioException catch (e) {
      _error = handleDioError(e, entityName: 'customers');
      debugPrint('❌ Load customers error: ${e.type} - ${e.message}');
    } catch (e) {
      _error = 'Failed to load customers';
      debugPrint('❌ Unexpected error: $e');
    } finally {
      _isLoadingCustomers = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Called by the scroll controller when the user nears the bottom.
  Future<void> loadMoreCustomers() async {
    if (!_hasMore || _isLoadingMore || _isLoadingCustomers) return;

    _isLoadingMore = true;
    notifyListeners();

    await loadCustomers(refresh: false);
  }

  // ─── SEARCH ───────────────────────────────────────────────────────────────

  void searchCustomers(String query) {
    _searchQuery = query.trim();
    _debounceTimer?.cancel();

    if (_searchQuery.isEmpty) {
      _searchResults = [];
      _error = null;
      notifyListeners();
      return;
    }

    _debounceTimer = Timer(
      const Duration(milliseconds: 350),
      () => _performSearch(_searchQuery),
    );
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;

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
        final customers = response.data['customers'] as List? ?? [];
        _searchResults = customers
            .map((j) => CustomerModel.fromJson(j as Map<String, dynamic>))
            .toList();
        debugPrint('✅ Found ${_searchResults.length} results');
      }
    } on DioException catch (e) {
      _error = handleDioError(e, entityName: 'customers');
      debugPrint('❌ Search error: ${e.type} - ${e.message}');
      _searchResults = [];
    } catch (e) {
      _error = 'Search failed';
      debugPrint('❌ Unexpected search error: $e');
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchQuery = '';
    _searchResults = [];
    _error = null;
    _debounceTimer?.cancel();
    notifyListeners();
  }

  // ─── RECENT SEARCHES ──────────────────────────────────────────────────────

  void _loadRecentSearches() {
    try {
      final raw = StorageService.getRecentSearches();
      if (raw != null) {
        final List<dynamic> decoded = json.decode(raw) as List;
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
      _recentSearches = _recentSearches.sublist(0, _maxRecentSearches);
    }

    notifyListeners();
    await _saveRecentSearches();
  }

  Future<void> clearRecentSearches() async {
    _recentSearches = [];
    notifyListeners();
    await StorageService.clearRecentSearches();
  }

  // ─── CUSTOMER DETAILS ─────────────────────────────────────────────────────

  Future<CustomerModel?> fetchCustomerDetails(String customerId) async {
    try {
      _isLoadingDetails = true;
      notifyListeners();

      final response = await _apiService.dio.get(
        ApiEndpoints.customerDetails,
        queryParameters: {'customerId': customerId},
      );

      if (response.statusCode == 200) {
        final data = response.data['customer'] as Map<String, dynamic>;
        _selectedCustomer = CustomerModel.fromJson(data);
        return _selectedCustomer;
      }
      return null;
    } on DioException catch (e) {
      debugPrint('❌ Fetch customer details error: ${e.type}');
      return null;
    } finally {
      _isLoadingDetails = false;
      notifyListeners();
    }
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