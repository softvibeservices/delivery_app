// lib/features/sticky_notes/providers/sticky_note_form_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/services/api_service.dart';
import '../../../config/api_endpoints.dart';
import '../models/sticky_note_model.dart';

class ProductRow {
  String? productId;
  String productName;
  String quantity;
  String? unit;

  ProductRow({
    this.productId,
    this.productName = '',
    this.quantity = '',
    this.unit,
  });

  bool get isValid =>
      productName.trim().isNotEmpty &&
      quantity.isNotEmpty &&
      int.tryParse(quantity) != null &&
      int.parse(quantity) > 0;
}

class StickyNoteFormProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  // Customer selection
  CustomerSuggestion? _selectedCustomer;
  CustomerSuggestion? get selectedCustomer => _selectedCustomer;

  List<CustomerSuggestion> _customerSuggestions = [];
  List<CustomerSuggestion> get customerSuggestions => _customerSuggestions;

  bool _isSearchingCustomers = false;
  bool get isSearchingCustomers => _isSearchingCustomers;

  // Product rows
  List<ProductRow> _productRows = [];
  List<ProductRow> get productRows => _productRows;

  // Product suggestions cache (per row)
  Map<int, List<ProductSuggestion>> _productSuggestionsCache = {};

  bool _isSearchingProducts = false;
  bool get isSearchingProducts => _isSearchingProducts;

  // Debounce timers
  Timer? _customerSearchTimer;
  Timer? _productSearchTimer;

  // Form state
  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String? _error;
  String? get error => _error;

  StickyNoteFormProvider() {
    _initializeRows();
  }

  void _initializeRows() {
    _productRows = List.generate(
      5,
      (index) => ProductRow(),
    );
  }

  /// Initialize form for editing
  void initializeForEdit(StickyNoteModel note) {
    debugPrint('🔧 Initializing form for edit');
    debugPrint('📦 Note has ${note.items.length} items');
    
    // Set customer
    _selectedCustomer = CustomerSuggestion(
      id: note.customerId ?? '',
      name: note.customerName,
      shopName: note.shopName,
      shopAddress: '',
      contacts: [],
    );
    
    debugPrint('✅ Customer set: ${_selectedCustomer?.name}');

    // Set product rows from existing items
    _productRows = note.items.map((item) {
      debugPrint('📝 Loading item: ${item.productName} (${item.quantity} ${item.unit})');
      return ProductRow(
        productId: item.productId,
        productName: item.productName,
        quantity: item.quantity.toString(),
        unit: item.unit,
      );
    }).toList();

    debugPrint('✅ Loaded ${_productRows.length} product rows');

    // Add empty rows to reach minimum of 5
    while (_productRows.length < 5) {
      _productRows.add(ProductRow());
    }

    debugPrint('✅ Final product rows count: ${_productRows.length}');
    
    // Clear any cached suggestions
    _productSuggestionsCache.clear();
    
    notifyListeners();
  }

  /// Reset form
  void resetForm() {
    _selectedCustomer = null;
    _customerSuggestions = [];
    _productSuggestionsCache = {};
    _initializeRows();
    _error = null;
    _customerSearchTimer?.cancel();
    _productSearchTimer?.cancel();
    notifyListeners();
  }

  /// Search customers with debouncing
  Future<void> searchCustomers(String query) async {
    if (query.trim().isEmpty) {
      _customerSuggestions = [];
      notifyListeners();
      return;
    }

    // Cancel previous timer
    _customerSearchTimer?.cancel();

    // Start new timer
    _customerSearchTimer = Timer(const Duration(milliseconds: 500), () async {
      await _performCustomerSearch(query);
    });
  }

  Future<void> _performCustomerSearch(String query) async {
    try {
      _isSearchingCustomers = true;
      notifyListeners();

      // ✅ FIXED: No need to manually get userId - backend will extract it from token
      debugPrint('🔍 Searching customers for: $query');

      final response = await _apiService.dio.get(
        ApiEndpoints.searchCustomers,
        queryParameters: {
          'q': query, // ✅ Only send query, backend gets userId from auth token
        },
      );

      debugPrint('📦 Customer search response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final customers = response.data['customers'] as List?;
        if (customers != null) {
          _customerSuggestions = customers
              .map((json) => CustomerSuggestion.fromJson(json))
              .toList();
          debugPrint('✅ Found ${_customerSuggestions.length} customers');
        } else {
          _customerSuggestions = [];
          debugPrint('⚠️ No customers in response');
        }
      }
    } on DioException catch (e) {
      debugPrint('❌ Customer search error: ${e.type}');
      debugPrint('❌ Message: ${e.message}');
      if (e.response != null) {
        debugPrint('❌ Response data: ${e.response?.data}');
      }
      _customerSuggestions = [];
    } finally {
      _isSearchingCustomers = false;
      notifyListeners();
    }
  }

  /// Select customer
  void selectCustomer(CustomerSuggestion customer) {
    _selectedCustomer = customer;
    _customerSuggestions = [];
    notifyListeners();
  }

  /// Clear customer selection
  void clearCustomer() {
    _selectedCustomer = null;
    notifyListeners();
  }

  /// Search products with debouncing
  Future<List<ProductSuggestion>> searchProducts(
    int rowIndex,
    String query,
  ) async {
    if (query.trim().isEmpty) {
      _productSuggestionsCache[rowIndex] = [];
      notifyListeners();
      return [];
    }

    // Cancel previous timer
    _productSearchTimer?.cancel();

    // Use Completer to return async result
    final completer = Completer<List<ProductSuggestion>>();

    _productSearchTimer = Timer(const Duration(milliseconds: 500), () async {
      final results = await _performProductSearch(rowIndex, query);
      completer.complete(results);
    });

    return completer.future;
  }

  Future<List<ProductSuggestion>> _performProductSearch(
    int rowIndex,
    String query,
  ) async {
    try {
      _isSearchingProducts = true;
      notifyListeners();

      // ✅ FIXED: No need to manually get userId - backend will extract it from token
      debugPrint('🔍 Searching products for row $rowIndex: $query');

      final response = await _apiService.dio.get(
        ApiEndpoints.searchProducts,
        queryParameters: {
          'q': query, // ✅ Only send query, backend gets userId from auth token
        },
      );

      debugPrint('📦 Product search response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final products = response.data['products'] as List?;
        if (products != null) {
          final suggestions = products
              .map((json) => ProductSuggestion.fromJson(json))
              .toList();
          
          _productSuggestionsCache[rowIndex] = suggestions;
          debugPrint('✅ Found ${suggestions.length} products for row $rowIndex');
          notifyListeners();
          return suggestions;
        }
      }

      return [];
    } on DioException catch (e) {
      debugPrint('❌ Product search error: ${e.type}');
      debugPrint('❌ Message: ${e.message}');
      if (e.response != null) {
        debugPrint('❌ Response data: ${e.response?.data}');
      }
      return [];
    } finally {
      _isSearchingProducts = false;
      notifyListeners();
    }
  }

  /// Get cached product suggestions for a row
  List<ProductSuggestion> getProductSuggestions(int rowIndex) {
    return _productSuggestionsCache[rowIndex] ?? [];
  }

  /// Update product row
  void updateProductRow(int index, ProductRow row) {
    if (index >= 0 && index < _productRows.length) {
      _productRows[index] = row;
      notifyListeners();
    }
  }

  /// Select product for a row
  void selectProduct(int rowIndex, ProductSuggestion product) {
    if (rowIndex >= 0 && rowIndex < _productRows.length) {
      _productRows[rowIndex] = ProductRow(
        productId: product.id,
        productName: product.name,
        quantity: _productRows[rowIndex].quantity,
        unit: product.unit,
      );
      _productSuggestionsCache[rowIndex] = [];
      notifyListeners();
    }
  }

  /// Add 3 more product rows
  void addMoreRows() {
    _productRows.addAll([
      ProductRow(),
      ProductRow(),
      ProductRow(),
    ]);
    notifyListeners();
  }

  /// Remove product row
  void removeProductRow(int index) {
    if (_productRows.length > 1) {
      _productRows.removeAt(index);
      notifyListeners();
    }
  }

  /// Calculate total quantity
  int get totalQuantity {
    return _productRows
        .where((row) => row.isValid)
        .fold(0, (sum, row) => sum + int.parse(row.quantity));
  }

  /// Calculate total boxes
  int get totalBoxes {
    return _productRows
        .where((row) => row.isValid && row.unit == 'box')
        .fold(0, (sum, row) => sum + int.parse(row.quantity));
  }

  /// Validate form
  bool isFormValid() {
    // Check customer selected
    if (_selectedCustomer == null) {
      _error = 'Please select a customer';
      notifyListeners();
      return false;
    }

    // Check at least one product
    final validProducts = _productRows.where((row) => row.isValid).toList();
    if (validProducts.isEmpty) {
      _error = 'Please add at least one product';
      notifyListeners();
      return false;
    }

    _error = null;
    return true;
  }

  /// Build sticky note model from form data
  StickyNoteModel buildStickyNote({String? existingId}) {
    final validRows = _productRows.where((row) => row.isValid).toList();

    return StickyNoteModel(
      id: existingId ?? '',
      userId: '', // Will be filled by backend
      customerId: _selectedCustomer?.id,
      customerName: _selectedCustomer!.name,
      shopName: _selectedCustomer!.shopName,
      items: validRows.map((row) {
        return StickyNoteItem(
          productId: row.productId,
          productName: row.productName,
          quantity: int.parse(row.quantity),
          unit: row.unit,
        );
      }).toList(),
      totalQuantity: totalQuantity,
      createdAt: DateTime.now(),
    );
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _customerSearchTimer?.cancel();
    _productSearchTimer?.cancel();
    super.dispose();
  }
}