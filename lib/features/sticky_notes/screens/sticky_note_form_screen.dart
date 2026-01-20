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
  late StickyNoteFormProvider formProvider;
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    formProvider = Provider.of<StickyNoteFormProvider>(context, listen: false);
    
    debugPrint('🔧 Form screen init - Mode: ${widget.mode}');
    
    if (widget.mode == FormMode.edit && widget.existingNote != null) {
      debugPrint('📝 Initializing edit mode with note: ${widget.existingNote!.id}');
      formProvider.initializeForEdit(widget.existingNote!);
      _initialized = true;
    } else {
      debugPrint('📝 Create mode - resetting form');
      formProvider.resetForm();
      _initialized = true;
    }
  }

  @override
  void dispose() {
    debugPrint('🗑️ Disposing form screen');
    if (widget.mode == FormMode.create) {
      formProvider.resetForm();
    }
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;

    if (!formProvider.isFormValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(formProvider.error ?? 'Please fill all required fields'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final notesProvider = context.read<StickyNotesProvider>();
      final note = formProvider.buildStickyNote(
        existingId: widget.existingNote?.id,
      );

      bool success;
      if (widget.mode == FormMode.create) {
        debugPrint('📝 Creating new sticky note');
        success = await notesProvider.createStickyNote(note);
      } else {
        debugPrint('📝 Updating sticky note: ${widget.existingNote!.id}');
        success = await notesProvider.updateStickyNote(
          widget.existingNote!.id,
          note,
        );
      }

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.mode == FormMode.create
                    ? 'Sticky note created successfully'
                    : 'Sticky note updated successfully',
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save sticky note'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        backgroundColor: Color(0xFFF6F7F8),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF2B8CEE),
          ),
        ),
      );
    }

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
          widget.mode == FormMode.create ? 'New Sticky Note' : 'Edit Sticky Note',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: -0.015 * 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFFDBE0E6),
          ),
        ),
      ),
      body: Consumer<StickyNoteFormProvider>(
        builder: (context, provider, _) {
          debugPrint('🔄 Provider rebuild - Rows: ${provider.productRows.length}');
          
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer Section
                      const Text(
                        'Customer',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.015 * 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const CustomerAutocompleteFieldModern(),
                      const SizedBox(height: 24),

                      // Products Section
                      const Text(
                        'Add Products',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.015 * 18,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Product Rows
                      ...List.generate(
                        provider.productRows.length,
                        (index) {
                          final row = provider.productRows[index];
                          debugPrint('🎨 Rendering row $index: ${row.productName} (${row.quantity})');
                          
                          return ProductRowWidgetModern(
                            key: ValueKey('product_row_$index'),
                            rowIndex: index,
                            row: row,
                            onRemove: provider.productRows.length > 1
                                ? () => provider.removeProductRow(index)
                                : null,
                          );
                        },
                      ),

                      // Add More Rows Button
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: provider.addMoreRows,
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text('Add 3 More Rows'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          foregroundColor: const Color(0xFF2B8CEE),
                          side: const BorderSide(color: Color(0xFFDBE0E6)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomSheet: Consumer<StickyNoteFormProvider>(
        builder: (context, provider, _) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(
                top: BorderSide(color: Color(0xFFDBE0E6)),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Summary Row 1
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 20,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Total Item Types',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF617589),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${provider.productRows.where((r) => r.isValid).length} Products',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Summary Row 2
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calculate_outlined,
                            size: 20,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Total Quantity',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF617589),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${provider.totalQuantity} Units',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2B8CEE),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: _isSaving ? null : _handleSave,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2B8CEE),
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              widget.mode == FormMode.create
                                  ? 'Create Sticky Note Order'
                                  : 'Update Sticky Note',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 0.015 * 16,
                              ),
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