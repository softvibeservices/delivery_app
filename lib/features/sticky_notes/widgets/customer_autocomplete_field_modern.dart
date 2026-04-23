// lib/features/sticky_notes/widgets/customer_autocomplete_field_modern.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sticky_note_model.dart';
import '../providers/sticky_note_form_provider.dart';

class CustomerAutocompleteFieldModern extends StatefulWidget {
  const CustomerAutocompleteFieldModern({super.key});

  @override
  State<CustomerAutocompleteFieldModern> createState() =>
      _CustomerAutocompleteFieldModernState();
}

class _CustomerAutocompleteFieldModernState
    extends State<CustomerAutocompleteFieldModern> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _showSuggestions = false;

  static const _kBrand = Color(0xFF2B8CEE);
  static const _kBorder = Color(0xFFDBE0E6);

  @override
  void initState() {
    super.initState();

    // Restore text if customer already selected (edit mode).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<StickyNoteFormProvider>();
      if (provider.selectedCustomer != null) {
        _controller.text = provider.selectedCustomer!.displayName;
      }
    });

    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && mounted) {
        // Small delay so taps on suggestion items register before hide.
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) setState(() => _showSuggestions = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StickyNoteFormProvider>(
      builder: (context, provider, _) {
        // If a customer is selected, show the confirmation card instead.
        if (provider.selectedCustomer != null) {
          return _SelectedCustomerCard(
            customer: provider.selectedCustomer!,
            onClear: () {
              provider.clearCustomer();
              _controller.clear();
              setState(() => _showSuggestions = false);
            },
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Search input ────────────────────────────────────────────
            _buildSearchField(provider),

            // ── Min-chars hint ──────────────────────────────────────────
            if (_controller.text.isNotEmpty &&
                _controller.text.trim().length < 2)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  'Type at least 2 characters to search',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500),
                ),
              ),

            // ── Loading indicator ───────────────────────────────────────
            if (provider.isSearchingCustomers)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Color(0xFFEEF0F2),
                  color: _kBrand,
                ),
              ),

            // ── Suggestions dropdown ────────────────────────────────────
            if (_showSuggestions &&
                provider.customerSuggestions.isNotEmpty)
              _buildSuggestions(provider),
          ],
        );
      },
    );
  }

  Widget _buildSearchField(StickyNoteFormProvider provider) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _focusNode.hasFocus
              ? _kBrand.withValues(alpha: 0.6)
              : _kBorder,
          width: _focusNode.hasFocus ? 1.5 : 1,
        ),
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search customer name or shop...',
          hintStyle: const TextStyle(
              color: Color(0xFF617589), fontSize: 13),
          prefixIcon: const Icon(Icons.search,
              color: Color(0xFF617589), size: 18),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear,
                      size: 16, color: Color(0xFF617589)),
                  onPressed: () {
                    _controller.clear();
                    provider.clearCustomer();
                    setState(() => _showSuggestions = false);
                  },
                )
              : null,
          border: InputBorder.none,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        ),
        onChanged: (value) {
          provider.searchCustomers(value);
          setState(() {
            _showSuggestions = value.trim().length >= 2;
          });
        },
        onTap: () {
          if (_controller.text.trim().length >= 2) {
            setState(() => _showSuggestions = true);
          }
        },
      ),
    );
  }

  Widget _buildSuggestions(StickyNoteFormProvider provider) {
    return Container(
      margin: const EdgeInsets.only(top: 3),
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: provider.customerSuggestions.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: _kBorder),
        itemBuilder: (_, index) {
          final customer = provider.customerSuggestions[index];
          return InkWell(
            onTap: () {
              provider.selectCustomer(customer);
              _controller.text = customer.displayName;
              setState(() => _showSuggestions = false);
              _focusNode.unfocus();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.store,
                        color: Color(0xFFF59E0B), size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          customer.shopName,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF617589),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (customer.primaryContact != null)
                    Text(
                      customer.primaryContact!,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF617589)),
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

// ─── Selected customer confirmation card ──────────────────────────────────────

class _SelectedCustomerCard extends StatelessWidget {
  const _SelectedCustomerCard({
    required this.customer,
    required this.onClear,
  });

  final CustomerSuggestion customer;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF10B981)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.check_circle,
                color: Color(0xFF10B981), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  customer.shopName,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF059669),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onClear,
            color: const Color(0xFF059669),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}