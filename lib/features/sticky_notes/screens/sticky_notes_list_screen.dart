// lib/features/sticky_notes/screens/sticky_notes_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sticky_notes_provider.dart';
import '../models/sticky_note_model.dart';
import 'sticky_note_form_screen.dart';
import 'sticky_note_detail_screen.dart';
import '../../../core/utils/date_utils.dart';

class StickyNotesListScreen extends StatefulWidget {
  const StickyNotesListScreen({super.key});

  @override
  State<StickyNotesListScreen> createState() => _StickyNotesListScreenState();
}

class _StickyNotesListScreenState extends State<StickyNotesListScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StickyNotesProvider>().fetchStickyNotes();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshNotes() async {
    await context.read<StickyNotesProvider>().fetchStickyNotes();
  }

  void _filterNotes(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _filterNotes('');
  }

  void _navigateToCreate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const StickyNoteFormScreen(mode: FormMode.create),
      ),
    );

    if (result == true && mounted) {
      _refreshNotes();
    }
  }

  void _navigateToDetail(StickyNoteModel note) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StickyNoteDetailScreen(note: note),
      ),
    );
  }

  void _navigateToEdit(StickyNoteModel note) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StickyNoteFormScreen(
          mode: FormMode.edit,
          existingNote: note,
        ),
      ),
    );

    if (result == true && mounted) {
      _refreshNotes();
    }
  }

  void _confirmDelete(StickyNoteModel note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Sticky Note?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete the sticky note for ${note.shopName}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteNote(note);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteNote(StickyNoteModel note) async {
    final provider = context.read<StickyNotesProvider>();
    final success = await provider.deleteStickyNote(note.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Sticky note deleted successfully'
                : 'Failed to delete sticky note',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
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
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(
          'Sticky Notes',
          style: TextStyle(
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
      body: Consumer<StickyNotesProvider>(
        builder: (context, provider, _) {
          final groupedNotes = provider.getGroupedNotes();
          final isEmpty = !provider.isLoading && provider.totalNotes == 0;

          return RefreshIndicator(
            onRefresh: _refreshNotes,
            color: const Color(0xFF2B8CEE),
            child: isEmpty && !provider.isLoading
                ? _buildEmptyStateWithScroll()
                : _buildNotesList(provider, groupedNotes),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreate,
        backgroundColor: const Color(0xFF2B8CEE),
        elevation: 4,
        icon: const Icon(Icons.add, size: 20),
        label: const Text(
          'New Note',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildEmptyStateWithScroll() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              children: [
                _buildSearchBar(),
                SizedBox(height: constraints.maxHeight * 0.25),
                _emptyState(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotesList(
    StickyNotesProvider provider,
    Map<String, List<StickyNoteModel>> groupedNotes,
  ) {
    return Column(
      children: [
        _buildSearchBar(),

        // Statistics Cards
        if (!provider.isLoading && provider.totalNotes > 0)
          _buildStatistics(provider),

        // Error Message
        if (provider.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      provider.error!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => provider.clearError(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),

        // Notes List
        Expanded(
          child: provider.isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF2B8CEE),
                  ),
                )
              : _buildGroupedNotesList(groupedNotes),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDBE0E6)),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _filterNotes,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Search sticky notes...',
            hintStyle: TextStyle(
              color: const Color(0xFF617589),
              fontSize: 16,
            ),
            prefixIcon: const Icon(
              Icons.search,
              color: Color(0xFF617589),
              size: 24,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: _clearSearch,
                    color: const Color(0xFF617589),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatistics(StickyNotesProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: _statCard(
              'Today',
              provider.todayNotes.toString(),
              Icons.today_outlined,
              const Color(0xFF2B8CEE),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _statCard(
              'This Week',
              provider.thisWeekNotes.toString(),
              Icons.date_range_outlined,
              const Color(0xFF10B981),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _statCard(
              'Total',
              provider.totalNotes.toString(),
              Icons.sticky_note_2_outlined,
              const Color(0xFFF59E0B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDBE0E6)),
      ),
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
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
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

  Widget _buildGroupedNotesList(Map<String, List<StickyNoteModel>> groupedNotes) {
    final filteredGroups = <String, List<StickyNoteModel>>{};
    
    if (_searchQuery.isEmpty) {
      filteredGroups.addAll(groupedNotes);
    } else {
      final lowerQuery = _searchQuery.toLowerCase();
      for (final entry in groupedNotes.entries) {
        final filtered = entry.value.where((note) {
          return note.customerName.toLowerCase().contains(lowerQuery) ||
              note.shopName.toLowerCase().contains(lowerQuery) ||
              note.items.any((item) => 
                item.productName.toLowerCase().contains(lowerQuery));
        }).toList();
        
        if (filtered.isNotEmpty) {
          filteredGroups[entry.key] = filtered;
        }
      }
    }

    if (filteredGroups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 72,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                'No results for "$_searchQuery"',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Try different keywords',
                style: TextStyle(
                  color: Color(0xFF617589),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        if (filteredGroups['today']?.isNotEmpty ?? false)
          _buildNoteGroup('Today', filteredGroups['today']!),
        if (filteredGroups['yesterday']?.isNotEmpty ?? false)
          _buildNoteGroup('Yesterday', filteredGroups['yesterday']!),
        if (filteredGroups['this_week']?.isNotEmpty ?? false)
          _buildNoteGroup('This Week', filteredGroups['this_week']!),
        if (filteredGroups['older']?.isNotEmpty ?? false)
          _buildNoteGroup('Older', filteredGroups['older']!),
      ],
    );
  }

  Widget _buildNoteGroup(String title, List<StickyNoteModel> notes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF617589),
              letterSpacing: 0.8,
            ),
          ),
        ),
        ...notes.map((note) => _noteCard(note)),
      ],
    );
  }

  Widget _noteCard(StickyNoteModel note) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDBE0E6)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToDetail(note),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            note.shopName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111418),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            note.customerName,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF617589),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 14,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${note.totalBoxes}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${note.items.length} items',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      AppDateUtils.getRelativeTime(note.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _navigateToEdit(note),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2B8CEE),
                          side: const BorderSide(color: Color(0xFF2B8CEE)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _confirmDelete(note),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.all(10),
                        minimumSize: const Size(48, 48),
                      ),
                      child: const Icon(Icons.delete_outline, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sticky_note_2_outlined,
            size: 72,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            'No sticky notes yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try adjusting your search'
                : 'Tap the + button to create your first note',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF617589),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}