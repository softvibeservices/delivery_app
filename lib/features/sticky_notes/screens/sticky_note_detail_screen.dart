// lib/features/sticky_notes/screens/sticky_note_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sticky_note_model.dart';
import 'sticky_note_form_screen.dart';
import '../../../core/utils/date_utils.dart';

class StickyNoteDetailScreen extends StatelessWidget {
  final StickyNoteModel note;

  const StickyNoteDetailScreen({
    super.key,
    required this.note,
  });

  void _navigateToEdit(BuildContext context) async {
    final nav = Navigator.of(context);
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StickyNoteFormScreen(
          mode: FormMode.edit,
          existingNote: note,
        ),
      ),
    );

    if (result == true) {
        nav.pop(true);
      }
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          'Sticky Note Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: -0.015 * 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _navigateToEdit(context),
            tooltip: 'Edit',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFFDBE0E6),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDBE0E6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.store,
                          color: Color(0xFFF59E0B),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              note.shopName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              note.customerName,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF617589),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFDBE0E6)),
                  const SizedBox(height: 12),
                  _infoRow(
                    Icons.access_time,
                    'Created ${AppDateUtils.getRelativeTime(note.createdAt)}',
                  ),
                  const SizedBox(height: 8),
                  _infoRow(
                    Icons.calendar_today_outlined,
                    DateFormat('MMM dd, yyyy • hh:mm a').format(note.createdAt),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _summaryCard(
                    Icons.shopping_bag_outlined,
                    note.items.length.toString(),
                    'Items',
                    const Color(0xFF2B8CEE),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _summaryCard(
                    Icons.pin_outlined,
                    note.totalQuantity.toString(),
                    'Total Qty',
                    const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _summaryCard(
                    Icons.inventory_2_outlined,
                    note.totalBoxes.toString(),
                    'Boxes',
                    const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Products Header
            const Text(
              'PRODUCTS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF617589),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),

            // Products List
            ...note.items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _productCard(item, index + 1);
            }),

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomSheet: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFDBE0E6)),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: () => _navigateToEdit(context),
              icon: const Icon(Icons.edit_outlined),
              label: const Text(
                'Edit Sticky Note',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2B8CEE),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF617589),
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDBE0E6)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF617589),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _productCard(StickyNoteItem item, int index) {
    final isBox = item.unit == 'box';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDBE0E6)),
      ),
      child: Row(
        children: [
          // Product Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isBox
                  ? const Color(0xFFFEF3C7)
                  : const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isBox ? Icons.inventory_2_outlined : Icons.category_outlined,
              color: isBox
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF2B8CEE),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Product Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$index',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.productName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (item.unit != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Unit: ${item.unit}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF617589),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Quantity Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isBox
                  ? const Color(0xFFFEF3C7)
                  : const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isBox
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF2B8CEE),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.pin,
                  size: 16,
                  color: isBox
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF2B8CEE),
                ),
                const SizedBox(width: 4),
                Text(
                  '${item.quantity}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isBox
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF2B8CEE),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}