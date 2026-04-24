// lib/features/sticky_notes/widgets/customer_autocomplete_field.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sticky_note_model.dart';
import '../providers/sticky_note_form_provider.dart';

class CustomerAutocompleteField extends StatefulWidget {
  const CustomerAutocompleteField({super.key});

  @override
  State<CustomerAutocompleteField> createState() =>
      _CustomerAutocompleteFieldState();
}

class _CustomerAutocompleteFieldState extends State<CustomerAutocompleteField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _showDropdown = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _showDropdown = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSelect(CustomerSuggestion customer, StickyNoteFormProvider provider) {
    provider.selectCustomer(customer);
    _controller.text = customer.displayName;
    _focusNode.unfocus();
    setState(() => _showDropdown = false);
  }

  void _onClear(StickyNoteFormProvider provider) {
    provider.clearCustomer();
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StickyNoteFormProvider>(
      builder: (context, provider, _) {
        final hasSelection = provider.selectedCustomer != null;

        if (hasSelection) {
          return _SelectedCustomerCard(
            customer: provider.selectedCustomer!,
            onClear: () => _onClear(provider),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF111418),
              ),
              decoration: InputDecoration(
                hintText: 'Search customer or shop...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade400,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 20,
                  color: Color(0xFF617589),
                ),
                suffixIcon: provider.isSearchingCustomers
                    ? Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.all(14),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF2B8CEE),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFDBE0E6)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF2B8CEE),
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onChanged: provider.searchCustomers,
              textInputAction: TextInputAction.next,
            ),

            // Dropdown
            if (_showDropdown && provider.customerSuggestions.isNotEmpty)
              _CustomerDropdown(
                suggestions: provider.customerSuggestions,
                onSelect: (c) => _onSelect(c, provider),
              ),
          ],
        );
      },
    );
  }
}

// ─── Selected Customer Card ─────────────────────────────────────────────────

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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2B8CEE).withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2B8CEE).withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF2B8CEE).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.storefront,
              color: Color(0xFF2B8CEE),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.shopName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111418),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  customer.name,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF617589),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onClear,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Customer Dropdown ──────────────────────────────────────────────────────

class _CustomerDropdown extends StatelessWidget {
  const _CustomerDropdown({
    required this.suggestions,
    required this.onSelect,
  });

  final List<CustomerSuggestion> suggestions;
  final ValueChanged<CustomerSuggestion> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDBE0E6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxHeight: 260),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final customer = suggestions[index];
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSelect(customer),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
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
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2B8CEE).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.storefront_outlined,
                          color: Color(0xFF2B8CEE),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer.shopName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111418),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${customer.name} • ${customer.shopAddress}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: Color(0xFF617589),
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
  }
}