// lib/features/sticky_notes/screens/sticky_note_form_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sticky_note_model.dart';
import '../providers/sticky_note_form_provider.dart';
import '../providers/sticky_notes_provider.dart';
import '../widgets/customer_autocomplete_field.dart';
import '../widgets/product_row_widget.dart';

enum FormMode { create, edit }

class StickyNoteFormScreen extends StatefulWidget {
  final FormMode mode;
  final StickyNoteModel? existingNote;

  const StickyNoteFormScreen({
    super.key,
    required this.mode,
    this.existingNote,
  });

  @override
  State<StickyNoteFormScreen> createState() => _StickyNoteFormScreenState();
}

class _StickyNoteFormScreenState extends State<StickyNoteFormScreen> {
  static const _kBrand = Color(0xFF2B8CEE);
  static const _kBorder = Color(0xFFDBE0E6);

  final ScrollController _scrollController = ScrollController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<StickyNoteFormProvider>();
    if (widget.mode == FormMode.edit && widget.existingNote != null) {
      provider.initializeForEdit(widget.existingNote!);
    } else {
      provider.resetForm();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    if (widget.mode == FormMode.create) {
      context.read<StickyNoteFormProvider>().resetForm();
    }
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;

    final formProvider = context.read<StickyNoteFormProvider>();
    if (!formProvider.isFormValid()) {
      _showSnack(formProvider.error ?? 'Please fill all required fields', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final notesProvider = context.read<StickyNotesProvider>();
      final note = formProvider.buildStickyNote(
        existingId: widget.existingNote?.id,
      );

      final success = widget.mode == FormMode.create
          ? await notesProvider.createStickyNote(note)
          : await notesProvider.updateStickyNote(widget.existingNote!.id, note);

      if (!mounted) return;

      if (success) {
        _showSnack(
          widget.mode == FormMode.create ? 'Note created' : 'Note updated',
        );
        Navigator.pop(context, true);
      } else {
        _showSnack('Failed to save. Please try again.', isError: true);
      }
    } catch (e) {
      if (mounted) _showSnack('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.mode == FormMode.create ? 'New Sticky Note' : 'Edit Note',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kBorder),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(label: 'CUSTOMER'),
                  const SizedBox(height: 8),
                  const CustomerAutocompleteField(),
                  const SizedBox(height: 20),

                  _SectionLabel(label: 'PRODUCTS'),
                  const SizedBox(height: 8),

                  Consumer<StickyNoteFormProvider>(
                    builder: (_, provider, __) {
                      return Column(
                        children: [
                          ...List.generate(
                            provider.productRows.length,
                            (i) => ProductRowWidget(
                              key: ValueKey('product_row_$i'),
                              rowIndex: i,
                              row: provider.productRows[i],
                              canRemove: provider.productRows.length > 1,
                              onRemove: () => provider.removeProductRow(i),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _AddRowButton(
                            onTap: () {
                              provider.addRow();
                              _scrollToBottom();
                            },
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Summary Card
                  Consumer<StickyNoteFormProvider>(
                    builder: (_, provider, __) => _SummaryCard(
                      totalQty: provider.totalQuantity,
                      totalBoxes: provider.totalBoxes,
                      validRows: provider.validRowCount,
                    ),
                  ),

                  SizedBox(height: 80 + bottomPadding),
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: _kBorder)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPadding),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: _SaveButton(
                      isSaving: _isSaving,
                      label: widget.mode == FormMode.create
                          ? 'Create Note'
                          : 'Update Note',
                      onTap: _handleSave,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Label ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF617589),
        letterSpacing: 0.8,
      ),
    );
  }
}

// ─── Add Row Button ─────────────────────────────────────────────────────────

class _AddRowButton extends StatelessWidget {
  const _AddRowButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFDBE0E6)),
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 18, color: Color(0xFF2B8CEE)),
              SizedBox(width: 8),
              Text(
                'Add Product',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2B8CEE),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Summary Card ───────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totalQty,
    required this.totalBoxes,
    required this.validRows,
  });

  final int totalQty;
  final int totalBoxes;
  final int validRows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDBE0E6)),
      ),
      child: Row(
        children: [
          _SummaryItem(
            icon: Icons.shopping_bag_outlined,
            value: '$validRows',
            label: 'Products',
            color: const Color(0xFF2B8CEE),
          ),
          const _Divider(),
          _SummaryItem(
            icon: Icons.pin_outlined,
            value: '$totalQty',
            label: 'Total Qty',
            color: const Color(0xFF10B981),
          ),
          const _Divider(),
          _SummaryItem(
            icon: Icons.inventory_2_outlined,
            value: '$totalBoxes',
            label: 'Boxes',
            color: const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF617589),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: 1,
      color: const Color(0xFFDBE0E6),
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

// ─── Save Button ────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.isSaving,
    required this.label,
    required this.onTap,
  });

  final bool isSaving;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isSaving ? null : onTap,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF2B8CEE),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
      child: isSaving
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}