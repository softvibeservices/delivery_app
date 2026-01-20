// lib/features/sticky_notes/widgets/product_row_widget_modern.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/sticky_note_form_provider.dart';
import '../models/sticky_note_model.dart';

class ProductRowWidgetModern extends StatefulWidget {
  final int rowIndex;
  final ProductRow row;
  final VoidCallback? onRemove;

  const ProductRowWidgetModern({
    super.key,
    required this.rowIndex,
    required this.row,
    this.onRemove,
  });

  @override
  State<ProductRowWidgetModern> createState() => _ProductRowWidgetModernState();
}

class _ProductRowWidgetModernState extends State<ProductRowWidgetModern> {
  late TextEditingController _productController;
  late TextEditingController _quantityController;
  final FocusNode _productFocus = FocusNode();
  final FocusNode _quantityFocus = FocusNode();
  bool _showSuggestions = false;
  List<ProductSuggestion> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _productController = TextEditingController(text: widget.row.productName);
    _quantityController = TextEditingController(text: widget.row.quantity);

    _productFocus.addListener(() {
      if (!_productFocus.hasFocus) {
        setState(() => _showSuggestions = false);
      }
    });
  }

  @override
  void dispose() {
    _productController.dispose();
    _quantityController.dispose();
    _productFocus.dispose();
    _quantityFocus.dispose();
    super.dispose();
  }

  void _updateRow({String? productName, String? quantity}) {
    final provider = context.read<StickyNoteFormProvider>();
    final updatedRow = ProductRow(
      productId: widget.row.productId,
      productName: productName ?? widget.row.productName,
      quantity: quantity ?? widget.row.quantity,
      unit: widget.row.unit,
    );
    provider.updateProductRow(widget.rowIndex, updatedRow);
  }

  Future<void> _searchProducts(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    final provider = context.read<StickyNoteFormProvider>();
    final results = await provider.searchProducts(widget.rowIndex, query);
    
    if (mounted) {
      setState(() {
        _suggestions = results;
        _showSuggestions = results.isNotEmpty;
      });
    }
  }

  void _selectProduct(ProductSuggestion product) {
    final provider = context.read<StickyNoteFormProvider>();
    provider.selectProduct(widget.rowIndex, product);
    
    _productController.text = product.name;
    setState(() => _showSuggestions = false);
    
    _quantityFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDBE0E6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Name Field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Product Name',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _productFocus.hasFocus
                        ? const Color(0xFF2B8CEE).withValues(alpha: 0.5)
                        : const Color(0xFFDBE0E6),
                  ),
                ),
                child: TextField(
                  controller: _productController,
                  focusNode: _productFocus,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Search ice cream...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF617589),
                      fontSize: 16,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF617589),
                      size: 24,
                    ),
                    suffixIcon: _productController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _productController.clear();
                              _updateRow(productName: '');
                              setState(() => _showSuggestions = false);
                            },
                            color: const Color(0xFF617589),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  onChanged: (value) {
                    _updateRow(productName: value);
                    _searchProducts(value);
                  },
                  onTap: () {
                    if (_productController.text.isNotEmpty) {
                      _searchProducts(_productController.text);
                    }
                  },
                ),
              ),

              // Product Suggestions
              if (_showSuggestions && _suggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDBE0E6)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _suggestions.length,
                    separatorBuilder: (context, index) => const Divider(
                      height: 1,
                      color: Color(0xFFDBE0E6),
                    ),
                    itemBuilder: (context, index) {
                      final product = _suggestions[index];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        title: Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            if (product.category != null) ...[
                              Text(
                                product.category!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF617589),
                                ),
                              ),
                              if (product.unit != null)
                                const Text(
                                  ' • ',
                                  style: TextStyle(color: Color(0xFF617589)),
                                ),
                            ],
                            if (product.unit != null)
                              Text(
                                'Unit: ${product.unit}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF617589),
                                ),
                              ),
                          ],
                        ),
                        trailing: product.currentStock != null
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  product.stockInfo,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF059669),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            : null,
                        onTap: () => _selectProduct(product),
                      );
                    },
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 12),

          // Quantity Row
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Qty',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _quantityFocus.hasFocus
                              ? const Color(0xFF2B8CEE).withValues(alpha: 0.5)
                              : const Color(0xFFDBE0E6),
                        ),
                      ),
                      child: TextField(
                        controller: _quantityController,
                        focusNode: _quantityFocus,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(fontSize: 16),
                        decoration: const InputDecoration(
                          hintText: '0',
                          hintStyle: TextStyle(
                            color: Color(0xFF617589),
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        onChanged: (value) => _updateRow(quantity: value),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Unit Display
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Unit',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: widget.row.unit != null
                            ? const Color(0xFFFEF3C7)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.row.unit != null
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFFDBE0E6),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          widget.row.unit ?? '--',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: widget.row.unit != null
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF617589),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}