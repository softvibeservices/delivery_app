// lib/features/sticky_notes/screens/sticky_note_form_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sticky_notes_provider.dart';
import '../providers/sticky_note_form_provider.dart';
import '../models/sticky_note_model.dart';
import '../widgets/customer_autocomplete_field_modern.dart';
import '../widgets/product_row_widget_modern.dart';

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

  late final StickyNoteFormProvider _formProvider;
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _formProvider =
        Provider.of<StickyNoteFormProvider>(context, listen: false);

    if (widget.mode == FormMode.edit && widget.existingNote != null) {
      _formProvider.initializeForEdit(widget.existingNote!);
    } else {
      _formProvider.resetForm();
    }
    _initialized = true;
  }

  @override
  void dispose() {
    if (widget.mode == FormMode.create) {
      _formProvider.resetForm();
    }
    super.dispose();
  }

  // ─── SAVE ─────────────────────────────────────────────────────────────────

  Future<void> _handleSave() async {
    if (_isSaving) return;

    if (!_formProvider.isFormValid()) {
      _showSnack(
        _formProvider.error ?? 'Please fill all required fields',
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final notesProvider = context.read<StickyNotesProvider>();
      final note = _formProvider.buildStickyNote(
        existingId: widget.existingNote?.id,
      );

      final success = widget.mode == FormMode.create
          ? await notesProvider.createStickyNote(note)
          : await notesProvider.updateStickyNote(widget.existingNote!.id, note);

      if (!mounted) return;

      if (success) {
        _showSnack(
          widget.mode == FormMode.create
              ? 'Sticky note created'
              : 'Sticky note updated',
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: _kBrand)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Customer section ────────────────────────────────────
                  _sectionLabel('CUSTOMER'),
                  const SizedBox(height: 8),
                  const CustomerAutocompleteFieldModern(),
                  const SizedBox(height: 16),

                  // ── Products section ────────────────────────────────────
                  _sectionLabel('PRODUCTS'),
                  const SizedBox(height: 8),

                  Consumer<StickyNoteFormProvider>(
                    builder: (_, provider, _) {
                      return Column(
                        children: [
                          // Product rows
                          ...List.generate(
                            provider.productRows.length,
                            (i) => ProductRowWidgetModern(
                              key: ValueKey('row_$i'),
                              rowIndex: i,
                              totalRows: provider.productRows.length,
                              row: provider.productRows[i],
                              onRemove:
                                  provider.productRows.length > 1
                                      ? () => provider.removeProductRow(i)
                                      : null,
                            ),
                          ),

                          // ── Add row button ──────────────────────────────
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: provider.addRow,
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add Row'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _kBrand,
                                    side: const BorderSide(color: _kBorder),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    textStyle: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: provider.addMoreRows,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.grey.shade600,
                                  side: const BorderSide(color: _kBorder),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                                child: const Text('+3',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _buildBottomSheet(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.white,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        widget.mode == FormMode.create
            ? 'New Sticky Note'
            : 'Edit Sticky Note',
        style: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 17),
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: _kBorder),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF617589),
        letterSpacing: 0.8,
      ),
    );
  }

  // ─── BOTTOM SHEET ─────────────────────────────────────────────────────────

  Widget _buildBottomSheet() {
    return Consumer<StickyNoteFormProvider>(
      builder: (_, provider, _) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: _kBorder)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Summary row
                Row(
                  children: [
                    _summaryChip(
                      Icons.inventory_2_outlined,
                      '${provider.validRowCount} types',
                      Colors.blue,
                    ),
                    const SizedBox(width: 10),
                    _summaryChip(
                      Icons.calculate_outlined,
                      '${provider.totalQuantity} units',
                      _kBrand,
                    ),
                    const Spacer(),
                    // Customer chip
                    if (provider.selectedCustomer != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF10B981)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle,
                                color: Color(0xFF10B981), size: 12),
                            const SizedBox(width: 4),
                            Text(
                              provider.selectedCustomer!.shopName,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: FilledButton.styleFrom(
                      backgroundColor: _kBrand,
                      disabledBackgroundColor:
                          Colors.grey.shade300,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                  Colors.white),
                            ),
                          )
                        : Text(
                            widget.mode == FormMode.create
                                ? 'Create Note'
                                : 'Update Note',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _summaryChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color),
        ),
      ],
    );
  }
}