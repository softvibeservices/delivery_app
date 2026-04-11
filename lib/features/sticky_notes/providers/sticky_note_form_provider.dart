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
  final ApiService _apiService;

  StickyNoteFormProvider(this._apiService) {
    _initializeRows();
  }

  // ─── State ────────────────────────────────────────────────────────────────

  CustomerSuggestion? _selectedCustomer;
  CustomerSuggestion? get selectedCustomer => _selectedCustomer;

  List<CustomerSuggestion> _customerSuggestions = [];
  List<CustomerSuggestion> get customerSuggestions => _customerSuggestions;

  bool _isSearchingCustomers = false;
  bool get isSearchingCustomers => _isSearchingCustomers;

  List<ProductRow> _productRows = [];
  List<ProductRow> get productRows => _productRows;

  Map<int, List<ProductSuggestion>> _productSuggestionsCache = {};

  bool _isSearchingProducts = false;
  bool get isSearchingProducts => _isSearchingProducts;

  Timer? _customerSearchTimer;
  Timer? _productSearchTimer;
  // ignore: prefer_final_fields
  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String? _error;
  String? get error => _error;

  // ─── INIT ─────────────────────────────────────────────────────────────────

  void _initializeRows() {
    _productRows = List.generate(5, (_) => ProductRow());
  }

  void initializeForEdit(StickyNoteModel note) {
    debugPrint('🔧 Initialising form for edit — ${note.items.length} items');

    _selectedCustomer = CustomerSuggestion(
      id: note.customerId ?? '',
      name: note.customerName,
      shopName: note.shopName,
      shopAddress: '',
      contacts: [],
    );

    _productRows = note.items
        .map(
          (item) => ProductRow(
            productId: item.productId,
            productName: item.productName,
            quantity: item.quantity.toString(),
            unit: item.unit,
          ),
        )
        .toList();

    while (_productRows.length < 5) {
      _productRows.add(ProductRow());
    }

    _productSuggestionsCache.clear();
    notifyListeners();
  }

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

  // ─── CUSTOMER SEARCH ──────────────────────────────────────────────────────

  Future<void> searchCustomers(String query) async {
    if (query.trim().isEmpty) {
      _customerSuggestions = [];
      notifyListeners();
      return;
    }

    _customerSearchTimer?.cancel();
    _customerSearchTimer = Timer(
      const Duration(milliseconds: 500),
      () => _performCustomerSearch(query),
    );
  }

  Future<void> _performCustomerSearch(String query) async {
    try {
      _isSearchingCustomers = true;
      notifyListeners();

      debugPrint('🔍 Searching customers: $query');

      final response = await _apiService.dio.get(
        ApiEndpoints.searchCustomers,
        queryParameters: {'q': query},
      );

      if (response.statusCode == 200) {
        final customers = response.data['customers'] as List?;
        _customerSuggestions = customers
                ?.map((json) => CustomerSuggestion.fromJson(json))
                .toList() ??
            [];
        debugPrint('✅ Found ${_customerSuggestions.length} customers');
      }
    } on DioException catch (e) {
      debugPrint('❌ Customer search error: ${e.type} — ${e.message}');
      _customerSuggestions = [];
    } finally {
      _isSearchingCustomers = false;
      notifyListeners();
    }
  }

  void selectCustomer(CustomerSuggestion customer) {
    _selectedCustomer = customer;
    _customerSuggestions = [];
    notifyListeners();
  }

  void clearCustomer() {
    _selectedCustomer = null;
    notifyListeners();
  }

  // ─── PRODUCT SEARCH ───────────────────────────────────────────────────────

  Future<List<ProductSuggestion>> searchProducts(
    int rowIndex,
    String query,
  ) async {
    if (query.trim().isEmpty) {
      _productSuggestionsCache[rowIndex] = [];
      notifyListeners();
      return [];
    }

    _productSearchTimer?.cancel();
    final completer = Completer<List<ProductSuggestion>>();

    _productSearchTimer = Timer(
      const Duration(milliseconds: 500),
      () async {
        final results = await _performProductSearch(rowIndex, query);
        completer.complete(results);
      },
    );

    return completer.future;
  }

  Future<List<ProductSuggestion>> _performProductSearch(
    int rowIndex,
    String query,
  ) async {
    try {
      _isSearchingProducts = true;
      notifyListeners();

      debugPrint('🔍 Searching products for row $rowIndex: $query');

      final response = await _apiService.dio.get(
        ApiEndpoints.searchProducts,
        queryParameters: {'q': query},
      );

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
      debugPrint('❌ Product search error: ${e.type} — ${e.message}');
      return [];
    } finally {
      _isSearchingProducts = false;
      notifyListeners();
    }
  }

  List<ProductSuggestion> getProductSuggestions(int rowIndex) {
    return _productSuggestionsCache[rowIndex] ?? [];
  }

  // ─── PRODUCT ROWS ─────────────────────────────────────────────────────────

  void updateProductRow(int index, ProductRow row) {
    if (index >= 0 && index < _productRows.length) {
      _productRows[index] = row;
      notifyListeners();
    }
  }

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

  void addMoreRows() {
    _productRows.addAll([ProductRow(), ProductRow(), ProductRow()]);
    notifyListeners();
  }

  void removeProductRow(int index) {
    if (_productRows.length > 1) {
      _productRows.removeAt(index);
      notifyListeners();
    }
  }

  // ─── COMPUTED ─────────────────────────────────────────────────────────────

  int get totalQuantity {
    return _productRows
        .where((row) => row.isValid)
        .fold(0, (sum, row) => sum + int.parse(row.quantity));
  }

  int get totalBoxes {
    return _productRows
        .where((row) => row.isValid && row.unit == 'box')
        .fold(0, (sum, row) => sum + int.parse(row.quantity));
  }

  bool isFormValid() {
    if (_selectedCustomer == null) {
      _error = 'Please select a customer';
      notifyListeners();
      return false;
    }

    final validProducts = _productRows.where((row) => row.isValid).toList();
    if (validProducts.isEmpty) {
      _error = 'Please add at least one product';
      notifyListeners();
      return false;
    }

    _error = null;
    return true;
  }

  StickyNoteModel buildStickyNote({String? existingId}) {
    final validRows = _productRows.where((row) => row.isValid).toList();
    return StickyNoteModel(
      id: existingId ?? '',
      userId: '',
      customerId: _selectedCustomer?.id,
      customerName: _selectedCustomer!.name,
      shopName: _selectedCustomer!.shopName,
      items: validRows
          .map(
            (row) => StickyNoteItem(
              productId: row.productId,
              productName: row.productName,
              quantity: int.parse(row.quantity),
              unit: row.unit,
            ),
          )
          .toList(),
      totalQuantity: totalQuantity,
      createdAt: DateTime.now(),
    );
  }

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