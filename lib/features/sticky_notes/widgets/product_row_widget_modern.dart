// lib/features/sticky_notes/widgets/product_row_widget_modern.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/sticky_note_form_provider.dart';
import '../models/sticky_note_model.dart';

class ProductRowWidgetModern extends StatefulWidget {
  final int rowIndex;

  /// Total number of rows currently in the form. Used to detect the last row
  /// for auto-add and for setting the correct keyboard action on the qty field.
  final int totalRows;

  final ProductRow row;
  final VoidCallback? onRemove;

  const ProductRowWidgetModern({
    super.key,
    required this.rowIndex,
    required this.totalRows,
    required this.row,
    this.onRemove,
  });

  @override
  State<ProductRowWidgetModern> createState() =>
      _ProductRowWidgetModernState();
}

class _ProductRowWidgetModernState extends State<ProductRowWidgetModern> {
  late TextEditingController _productCtrl;
  late TextEditingController _quantityCtrl;
  final FocusNode _productFocus = FocusNode();
  final FocusNode _quantityFocus = FocusNode();
  bool _showSuggestions = false;
  List<ProductSuggestion> _suggestions = [];

  static const _kBorder = Color(0xFFDBE0E6);

  bool get _isLastRow => widget.rowIndex == widget.totalRows - 1;

  @override
  void initState() {
    super.initState();
    _productCtrl = TextEditingController(text: widget.row.productName);
    _quantityCtrl = TextEditingController(text: widget.row.quantity);
    _productFocus.addListener(_onProductFocusChange);
  }

  void _onProductFocusChange() {
    if (_productFocus.hasFocus) {
      // ── 1. Auto-scroll: snap this row to the top of the viewport so the
      //      suggestion dropdown (rendered below) stays fully on screen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            // alignment 0.0 → row aligns to the top edge, giving the
            // maximum screen space below for the dropdown.
            alignment: 0.0,
          );
        }
      });

      // ── 2. Auto-add a blank row when the user focuses the LAST row so
      //      there is always a ready slot below without manual tapping.
      if (_isLastRow && mounted) {
        context.read<StickyNoteFormProvider>().addRow();
      }

      // ── 3. Re-show suggestions if the field already has qualifying text
      //      (e.g. user tapped away and tapped back).
      if (_productCtrl.text.trim().length >= 2 && mounted) {
        setState(() => _showSuggestions = true);
      }
    } else {
      // Short delay so suggestion-item taps register before the dropdown hides.
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) setState(() => _showSuggestions = false);
      });
    }
  }

  @override
  void dispose() {
    _productFocus.removeListener(_onProductFocusChange);
    _productCtrl.dispose();
    _quantityCtrl.dispose();
    _productFocus.dispose();
    _quantityFocus.dispose();
    super.dispose();
  }

  void _updateRow({String? productName, String? quantity}) {
    context.read<StickyNoteFormProvider>().updateProductRow(
          widget.rowIndex,
          ProductRow(
            productId: widget.row.productId,
            productName: productName ?? widget.row.productName,
            quantity: quantity ?? widget.row.quantity,
            unit: widget.row.unit,
          ),
        );
  }

  Future<void> _searchProducts(String query) async {
    if (query.trim().length < 2) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _showSuggestions = false;
        });
      }
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
    context.read<StickyNoteFormProvider>().selectProduct(widget.rowIndex, product);
    _productCtrl.text = product.name;
    setState(() => _showSuggestions = false);
    _quantityFocus.requestFocus();
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isValid = widget.row.isValid;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isValid
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : _kBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row number / valid badge ──────────────────────────────────
            _RowBadge(number: widget.rowIndex + 1, isValid: isValid),
            const SizedBox(width: 8),

            // ── Product name field + suggestion dropdown ───────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProductField(
                    controller: _productCtrl,
                    focusNode: _productFocus,
                    // Always "Next" — moves focus to the qty field.
                    textInputAction: TextInputAction.next,
                    onChanged: (v) {
                      _updateRow(productName: v);
                      _searchProducts(v);
                      setState(() {});
                    },
                    onTap: () {
                      if (_productCtrl.text.trim().length >= 2) {
                        _searchProducts(_productCtrl.text);
                      }
                    },
                    onSubmitted: () => _quantityFocus.requestFocus(),
                    onClear: () {
                      _productCtrl.clear();
                      _updateRow(productName: '');
                      setState(() => _showSuggestions = false);
                    },
                  ),

                  if (_showSuggestions && _suggestions.isNotEmpty)
                    _SuggestionDropdown(
                      suggestions: _suggestions,
                      onSelect: _selectProduct,
                    ),
                ],
              ),
            ),

            const SizedBox(width: 6),

            // ── Quantity field ─────────────────────────────────────────────
            // Unit badge shown once, directly below qty — NOT duplicated below
            // the row container as was previously the case.
            _QuantityField(
              controller: _quantityCtrl,
              focusNode: _quantityFocus,
              unit: widget.row.unit,
              // "Next" traverses the focus tree to the next row's product
              // field automatically (Flutter follows widget-tree order).
              // On the last qty field this simply moves to the add-row button,
              // which is acceptable UX and avoids extra state tracking.
              textInputAction: TextInputAction.next,
              onChanged: (v) => _updateRow(quantity: v),
              onSubmitted: () => FocusScope.of(context).nextFocus(),
            ),

            // ── Remove button ─────────────────────────────────────────────
            if (widget.onRemove != null)
              IconButton(
                onPressed: widget.onRemove,
                icon: const Icon(Icons.remove_circle_outline,
                    size: 18, color: Colors.redAccent),
                padding: const EdgeInsets.only(left: 2),
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                visualDensity: VisualDensity.compact,
              )
            else
              const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _RowBadge extends StatelessWidget {
  const _RowBadge({required this.number, required this.isValid});
  final int number;
  final bool isValid;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: isValid
            ? const Color(0xFF10B981).withValues(alpha: 0.15)
            : Colors.grey.shade100,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: isValid
            ? const Icon(Icons.check, size: 12, color: Color(0xFF10B981))
            : Text(
                '$number',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500,
                ),
              ),
      ),
    );
  }
}

class _ProductField extends StatelessWidget {
  const _ProductField({
    required this.controller,
    required this.focusNode,
    required this.textInputAction,
    required this.onChanged,
    required this.onTap,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final TextInputAction textInputAction;
  final ValueChanged<String> onChanged;
  final VoidCallback onTap;
  final VoidCallback onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: focusNode.hasFocus
              ? const Color(0xFF2B8CEE).withValues(alpha: 0.5)
              : const Color(0xFFDBE0E6),
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        style: const TextStyle(fontSize: 13),
        textInputAction: textInputAction,
        decoration: InputDecoration(
          hintText: 'Product name...',
          hintStyle: const TextStyle(color: Color(0xFF617589), fontSize: 13),
          prefixIcon:
              const Icon(Icons.search, color: Color(0xFF617589), size: 16),
          suffixIcon: controller.text.isNotEmpty
              ? GestureDetector(
                  onTap: onClear,
                  child: const Icon(Icons.clear,
                      size: 14, color: Color(0xFF617589)),
                )
              : null,
          border: InputBorder.none,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
        onChanged: onChanged,
        onTap: onTap,
        onSubmitted: (_) => onSubmitted(),
      ),
    );
  }
}

class _QuantityField extends StatelessWidget {
  const _QuantityField({
    required this.controller,
    required this.focusNode,
    required this.unit,
    required this.textInputAction,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? unit;
  final TextInputAction textInputAction;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: focusNode.hasFocus
                    ? const Color(0xFF2B8CEE).withValues(alpha: 0.5)
                    : const Color(0xFFDBE0E6),
              ),
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold),
              textInputAction: textInputAction,
              decoration: const InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(
                    color: Color(0xFF617589), fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 4, vertical: 10),
              ),
              onChanged: onChanged,
              onSubmitted: (_) => onSubmitted(),
            ),
          ),

          // ── Unit badge — shown ONCE, here below qty only ─────────────────
          if (unit != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                ),
                child: Text(
                  unit!,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF59E0B),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SuggestionDropdown extends StatelessWidget {
  const _SuggestionDropdown({
    required this.suggestions,
    required this.onSelect,
  });

  final List<ProductSuggestion> suggestions;
  final ValueChanged<ProductSuggestion> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 3),
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDBE0E6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: suggestions.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: Color(0xFFDBE0E6)),
        itemBuilder: (_, i) {
          final p = suggestions[i];
          return InkWell(
            onTap: () => onSelect(p),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (p.category != null)
                          Text(
                            p.category!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF617589),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (p.currentStock != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        p.stockInfo,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}