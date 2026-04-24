// lib/features/sticky_notes/widgets/product_row_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/sticky_note_model.dart';
import '../providers/sticky_note_form_provider.dart';

class ProductRowWidget extends StatefulWidget {
  const ProductRowWidget({
    super.key,
    required this.rowIndex,
    required this.row,
    required this.canRemove,
    required this.onRemove,
  });

  final int rowIndex;
  final ProductRow row;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  State<ProductRowWidget> createState() => _ProductRowWidgetState();
}

class _ProductRowWidgetState extends State<ProductRowWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  final _productFocus = FocusNode();
  final _qtyFocus = FocusNode();
  final _productController = TextEditingController();
  final _qtyController = TextEditingController();

  bool _showSuggestions = false;
  bool _isFieldFocused = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

    _productController.text = widget.row.productName;
    _qtyController.text = widget.row.quantity;

    _productFocus.addListener(_onFocusChange);
    _qtyFocus.addListener(_onFocusChange);

    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant ProductRowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.row.productName != widget.row.productName &&
        _productController.text != widget.row.productName) {
      _productController.text = widget.row.productName;
    }
    if (oldWidget.row.quantity != widget.row.quantity &&
        _qtyController.text != widget.row.quantity) {
      _qtyController.text = widget.row.quantity;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _productFocus.dispose();
    _qtyFocus.dispose();
    _productController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFieldFocused = _productFocus.hasFocus || _qtyFocus.hasFocus;
      _showSuggestions = _productFocus.hasFocus;
    });
  }

  void _updateProductName(String value) {
    final provider = context.read<StickyNoteFormProvider>();
    provider.updateProductRow(
      widget.rowIndex,
      ProductRow(
        productId: widget.row.productId,
        productName: value,
        quantity: widget.row.quantity,
        unit: widget.row.unit,
      ),
    );
    if (value.trim().length >= 2) {
      provider.searchProducts(widget.rowIndex, value);
    }
  }

  void _selectProduct(ProductSuggestion product) {
    final provider = context.read<StickyNoteFormProvider>();
    provider.selectProduct(widget.rowIndex, product);
    setState(() => _showSuggestions = false);
    _productFocus.unfocus();
    FocusScope.of(context).requestFocus(_qtyFocus);
  }

  void _updateQuantity(String value) {
    final provider = context.read<StickyNoteFormProvider>();
    provider.updateProductRow(
      widget.rowIndex,
      ProductRow(
        productId: widget.row.productId,
        productName: widget.row.productName,
        quantity: value,
        unit: widget.row.unit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isFieldFocused
                        ? const Color(0xFF2B8CEE).withOpacity(0.5)
                        : const Color(0xFFDBE0E6),
                  ),
                  boxShadow: _isFieldFocused
                      ? [
                          BoxShadow(
                            color: const Color(0xFF2B8CEE).withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 360;

                    return Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product Name Field
                            Expanded(
                              flex: isNarrow ? 2 : 3,
                              child: _ProductField(
                                controller: _productController,
                                focusNode: _productFocus,
                                hint: 'Product name',
                                prefixIcon: Icons.search,
                                onChanged: _updateProductName,
                                onSubmitted: (_) => FocusScope.of(context).requestFocus(_qtyFocus),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Quantity Field
                            SizedBox(
                              width: 72,
                              child: _QtyField(
                                controller: _qtyController,
                                focusNode: _qtyFocus,
                                onChanged: _updateQuantity,
                              ),
                            ),

                            // Remove Button
                            if (widget.canRemove) ...[
                              const SizedBox(width: 6),
                              _RemoveButton(onTap: widget.onRemove),
                            ] else ...[
                              const SizedBox(width: 6),
                              const SizedBox(width: 40), // spacer for alignment
                            ],
                          ],
                        ),

                        // Unit chip
                        if (widget.row.unit != null && widget.row.unit!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _UnitChip(unit: widget.row.unit!),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),

              // Suggestions Overlay
              if (_showSuggestions)
                _SuggestionsDropdown(
                  rowIndex: widget.rowIndex,
                  onSelect: _selectProduct,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Internal Widgets ───────────────────────────────────────────────────────

class _ProductField extends StatelessWidget {
  const _ProductField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.prefixIcon,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData prefixIcon;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Color(0xFF111418),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade400,
        ),
        prefixIcon: Icon(prefixIcon, size: 18, color: const Color(0xFF617589)),
        filled: true,
        fillColor: const Color(0xFFF6F7F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        isDense: true,
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.next,
    );
  }
}

class _QtyField extends StatelessWidget {
  const _QtyField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Color(0xFF111418),
      ),
      decoration: InputDecoration(
        hintText: 'Qty',
        hintStyle: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade400,
        ),
        filled: true,
        fillColor: const Color(0xFFF6F7F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        isDense: true,
      ),
      onChanged: onChanged,
      textInputAction: TextInputAction.done,
    );
  }
}

class _UnitChip extends StatelessWidget {
  const _UnitChip({required this.unit});

  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        unit,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2B8CEE),
        ),
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 40,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.delete_outline,
            size: 20,
            color: Colors.red.shade600,
          ),
        ),
      ),
    );
  }
}

// ─── Suggestions Dropdown ───────────────────────────────────────────────────

class _SuggestionsDropdown extends StatelessWidget {
  const _SuggestionsDropdown({
    required this.rowIndex,
    required this.onSelect,
  });

  final int rowIndex;
  final ValueChanged<ProductSuggestion> onSelect;

  @override
  Widget build(BuildContext context) {
    return Selector<StickyNoteFormProvider, List<ProductSuggestion>>(
      selector: (_, p) => p.getProductSuggestions(rowIndex),
      builder: (context, suggestions, _) {
        if (suggestions.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDBE0E6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          constraints: const BoxConstraints(maxHeight: 220),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final product = suggestions[index];
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onSelect(product),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: index < suggestions.length - 1
                            ? Border(
                                bottom: BorderSide(
                                  color: Colors.grey.shade100,
                                ),
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF111418),
                                  ),
                                ),
                                if (product.category != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    product.category!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (product.currentStock != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F2F4),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${product.currentStock} ${product.unit ?? ''}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF617589),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}