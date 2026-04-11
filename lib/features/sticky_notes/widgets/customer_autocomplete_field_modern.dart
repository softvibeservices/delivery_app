// lib/features/sticky_notes/widgets/customer_autocomplete_field_modern.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<StickyNoteFormProvider>();
      if (provider.selectedCustomer != null) {
        _controller.text = provider.selectedCustomer!.displayName;
      }
    });

    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        setState(() => _showSuggestions = false);
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Field
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _focusNode.hasFocus
                      ? const Color(0xFF2B8CEE).withValues(alpha: 0.5)
                      : const Color(0xFFDBE0E6),
                ),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Search customer name...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF617589),
                    fontSize: 16,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF617589),
                    size: 24,
                  ),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _controller.clear();
                            provider.clearCustomer();
                            setState(() => _showSuggestions = false);
                          },
                          color: const Color(0xFF617589),
                        )
                      : (provider.isSearchingCustomers
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF2B8CEE),
                                ),
                              ),
                            )
                          : null),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                onChanged: (value) {
                  provider.searchCustomers(value);
                  setState(() {
                    _showSuggestions = value.isNotEmpty;
                  });
                },
                onTap: () {
                  if (_controller.text.isNotEmpty) {
                    setState(() => _showSuggestions = true);
                  }
                },
              ),
            ),

            // Suggestions Dropdown
            if (_showSuggestions && provider.customerSuggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                constraints: const BoxConstraints(maxHeight: 240),
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
                  itemCount: provider.customerSuggestions.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    color: Color(0xFFDBE0E6),
                  ),
                  itemBuilder: (context, index) {
                    final customer = provider.customerSuggestions[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.store,
                          color: Color(0xFFF59E0B),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        customer.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            customer.shopName,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF617589),
                            ),
                          ),
                          if (customer.primaryContact != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              customer.primaryContact!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF617589),
                              ),
                            ),
                          ],
                        ],
                      ),
                      onTap: () {
                        provider.selectCustomer(customer);
                        _controller.text = customer.displayName;
                        setState(() => _showSuggestions = false);
                        _focusNode.unfocus();
                      },
                    );
                  },
                ),
              ),

            // Selected Customer Card
            if (provider.selectedCustomer != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Color(0xFF10B981),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            provider.selectedCustomer!.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            provider.selectedCustomer!.shopName,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF059669),
                            ),
                          ),
                          if (provider.selectedCustomer!.primaryContact != null)
                            Text(
                              provider.selectedCustomer!.primaryContact!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF059669),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () {
                        provider.clearCustomer();
                        _controller.clear();
                        setState(() => _showSuggestions = false);
                      },
                      color: const Color(0xFF059669),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}