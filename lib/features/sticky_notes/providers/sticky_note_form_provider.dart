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

  // ── Product search cache ───────────────────────────────────────────────────
  // Keyed by QUERY STRING (lowercased), not row index.
  // This means if rows 1 and 3 both type "vanilla", the second lookup is
  // instantaneous — zero network round-trip.
  final Map<String, List<ProductSuggestion>> _productQueryCache = {};

  // Per-row suggestion lists: what each row is currently showing.
  final Map<int, List<ProductSuggestion>> _rowSuggestions = {};

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

  static const int _defaultRowCount = 3;

  void _initializeRows() {
    _productRows = List.generate(_defaultRowCount, (_) => ProductRow());
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

    // Keep at least _defaultRowCount rows so there's always space to add more.
    while (_productRows.length < _defaultRowCount) {
      _productRows.add(ProductRow());
    }

    _rowSuggestions.clear();
    notifyListeners();
  }

  void resetForm() {
    _selectedCustomer = null;
    _customerSuggestions = [];
    _rowSuggestions.clear();
    // Don't clear _productQueryCache — it's session-scoped and speeds up
    // subsequent note creation within the same session.
    _initializeRows();
    _error = null;
    _customerSearchTimer?.cancel();
    _productSearchTimer?.cancel();
    notifyListeners();
  }

  // ─── CUSTOMER SEARCH ──────────────────────────────────────────────────────
  //
  // Debounced to 350 ms.
  // Minimum 2 characters before hitting the network — single-char queries
  // return too many results and feel laggy.

  void searchCustomers(String query) {
    if (query.trim().length < 2) {
      _customerSuggestions = [];
      notifyListeners();
      return;
    }

    _customerSearchTimer?.cancel();
    _customerSearchTimer = Timer(
      const Duration(milliseconds: 350),
      () => _performCustomerSearch(query.trim()),
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
        final customers = response.data['customers'] as List? ?? [];
        _customerSuggestions = customers
            .map((json) =>
                CustomerSuggestion.fromJson(json as Map<String, dynamic>))
            .toList();
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
    _customerSuggestions = [];
    notifyListeners();
  }

  // ─── PRODUCT SEARCH ───────────────────────────────────────────────────────
  //
  // Debounced to 350 ms.
  // Minimum 2 characters.
  // CACHE HIT: if the same query was already searched in this form session,
  // return the cached results immediately without any network call.

  Future<List<ProductSuggestion>> searchProducts(
    int rowIndex,
    String query,
  ) async {
    final trimmed = query.trim();

    if (trimmed.length < 2) {
      _rowSuggestions[rowIndex] = [];
      notifyListeners();
      return [];
    }

    final cacheKey = trimmed.toLowerCase();

    // ── Cache hit: return instantly ─────────────────────────────────────────
    if (_productQueryCache.containsKey(cacheKey)) {
      final cached = _productQueryCache[cacheKey]!;
      _rowSuggestions[rowIndex] = cached;
      notifyListeners();
      debugPrint('⚡ Product cache hit for "$cacheKey" (${cached.length} results)');
      return cached;
    }

    // ── Cache miss: debounce then fetch ─────────────────────────────────────
    _productSearchTimer?.cancel();
    final completer = Completer<List<ProductSuggestion>>();

    _productSearchTimer = Timer(
      const Duration(milliseconds: 350),
      () async {
        final results = await _fetchProducts(rowIndex, cacheKey);
        if (!completer.isCompleted) completer.complete(results);
      },
    );

    return completer.future;
  }

  Future<List<ProductSuggestion>> _fetchProducts(
    int rowIndex,
    String query,
  ) async {
    try {
      _isSearchingProducts = true;
      notifyListeners();

      debugPrint('🔍 Fetching products: "$query"');

      final response = await _apiService.dio.get(
        ApiEndpoints.searchProducts,
        queryParameters: {'q': query},
      );

      if (response.statusCode == 200) {
        final products = response.data['products'] as List? ?? [];
        final suggestions = products
            .map((json) =>
                ProductSuggestion.fromJson(json as Map<String, dynamic>))
            .toList();

        // Store in query-level cache for future rows.
        _productQueryCache[query] = suggestions;
        _rowSuggestions[rowIndex] = suggestions;

        debugPrint(
          '✅ Fetched ${suggestions.length} products for "$query" — cached',
        );
        notifyListeners();
        return suggestions;
      }
      return [];
    } on DioException catch (e) {
      debugPrint('❌ Product fetch error: ${e.type} — ${e.message}');
      return [];
    } finally {
      _isSearchingProducts = false;
      notifyListeners();
    }
  }

  List<ProductSuggestion> getProductSuggestions(int rowIndex) {
    return _rowSuggestions[rowIndex] ?? [];
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
      _rowSuggestions[rowIndex] = [];
      notifyListeners();
    }
  }

  /// Add a single empty row.
  void addRow() {
    _productRows.add(ProductRow());
    notifyListeners();
  }

  /// Legacy: add 3 rows at once (kept for backwards compatibility).
  void addMoreRows() {
    _productRows.addAll([ProductRow(), ProductRow(), ProductRow()]);
    notifyListeners();
  }

  void removeProductRow(int index) {
    if (_productRows.length > 1) {
      _productRows.removeAt(index);
      _rowSuggestions.remove(index);
      // Re-index suggestions above the removed row.
      final rebuilt = <int, List<ProductSuggestion>>{};
      for (final entry in _rowSuggestions.entries) {
        final k = entry.key > index ? entry.key - 1 : entry.key;
        rebuilt[k] = entry.value;
      }
      _rowSuggestions
        ..clear()
        ..addAll(rebuilt);
      notifyListeners();
    }
  }

  // ─── COMPUTED ─────────────────────────────────────────────────────────────

  int get totalQuantity => _productRows
      .where((r) => r.isValid)
      .fold(0, (sum, r) => sum + int.parse(r.quantity));

  int get totalBoxes => _productRows
      .where((r) => r.isValid && r.unit == 'box')
      .fold(0, (sum, r) => sum + int.parse(r.quantity));

  int get validRowCount => _productRows.where((r) => r.isValid).length;

  bool isFormValid() {
    if (_selectedCustomer == null) {
      _error = 'Please select a customer';
      notifyListeners();
      return false;
    }

    if (validRowCount == 0) {
      _error = 'Please add at least one product with a quantity';
      notifyListeners();
      return false;
    }

    _error = null;
    return true;
  }

  StickyNoteModel buildStickyNote({String? existingId}) {
    final validRows = _productRows.where((r) => r.isValid).toList();
    return StickyNoteModel(
      id: existingId ?? '',
      userId: '',
      customerId: _selectedCustomer?.id,
      customerName: _selectedCustomer!.name,
      shopName: _selectedCustomer!.shopName,
      items: validRows
          .map(
            (r) => StickyNoteItem(
              productId: r.productId,
              productName: r.productName,
              quantity: int.parse(r.quantity),
              unit: r.unit,
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