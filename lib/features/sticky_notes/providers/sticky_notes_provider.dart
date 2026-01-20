// lib/features/sticky_notes/providers/sticky_notes_provider.dart

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/services/api_service.dart';
import '../../../config/api_endpoints.dart';
import '../models/sticky_note_model.dart';

class StickyNotesProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<StickyNoteModel> _notes = [];
  List<StickyNoteModel> get notes => _notes;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  DateTime? _lastUpdated;
  DateTime? get lastUpdated => _lastUpdated;

  /// Fetch all sticky notes for this delivery partner
  Future<void> fetchStickyNotes() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('📝 Fetching sticky notes...');

      final response = await _apiService.dio.get(ApiEndpoints.stickyNotes);

      debugPrint('📦 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data;
        final notesList = data['notes'] as List?;

        if (notesList != null) {
          _notes = notesList
              .map((json) => StickyNoteModel.fromJson(json))
              .toList();
          
          _lastUpdated = DateTime.now();
          debugPrint('✅ Loaded ${_notes.length} sticky notes');
        } else {
          _notes = [];
          debugPrint('⚠️ No notes in response');
        }
      }
    } on DioException catch (e) {
      _error = _handleDioError(e);
      debugPrint('❌ DioException: ${e.type} - ${e.message}');
      _notes = [];
    } catch (e) {
      _error = 'Unexpected error: ${e.toString()}';
      debugPrint('❌ Unexpected error: $e');
      _notes = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new sticky note
  Future<bool> createStickyNote(StickyNoteModel note) async {
    try {
      debugPrint('📝 Creating sticky note...');

      final response = await _apiService.dio.post(
        ApiEndpoints.stickyNotes,
        data: {
          'customerId': note.customerId,
          'customerName': note.customerName,
          'shopName': note.shopName,
          'items': note.items.map((item) => item.toJson()).toList(),
        },
      );

      debugPrint('📦 Create response: ${response.statusCode}');

      if (response.statusCode == 201) {
        final createdNote = StickyNoteModel.fromJson(response.data);
        _notes.insert(0, createdNote);
        _lastUpdated = DateTime.now();
        notifyListeners();
        debugPrint('✅ Sticky note created successfully');
        return true;
      }

      return false;
    } on DioException catch (e) {
      debugPrint('❌ Create error: ${e.type} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('❌ Unexpected create error: $e');
      return false;
    }
  }

  /// Update an existing sticky note
  Future<bool> updateStickyNote(String noteId, StickyNoteModel note) async {
    try {
      debugPrint('📝 Updating sticky note: $noteId');

      final response = await _apiService.dio.put(
        ApiEndpoints.stickyNotes,
        data: {
          'noteId': noteId,
          'customerId': note.customerId,
          'customerName': note.customerName,
          'shopName': note.shopName,
          'items': note.items.map((item) => item.toJson()).toList(),
        },
      );

      debugPrint('📦 Update response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final updatedNote = StickyNoteModel.fromJson(response.data);
        final index = _notes.indexWhere((n) => n.id == noteId);
        
        if (index != -1) {
          _notes[index] = updatedNote;
          _lastUpdated = DateTime.now();
          notifyListeners();
          debugPrint('✅ Sticky note updated successfully');
          return true;
        }
      }

      return false;
    } on DioException catch (e) {
      debugPrint('❌ Update error: ${e.type} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('❌ Unexpected update error: $e');
      return false;
    }
  }

  /// Delete a sticky note
  Future<bool> deleteStickyNote(String noteId) async {
    try {
      debugPrint('📝 Deleting sticky note: $noteId');

      final response = await _apiService.dio.delete(
        ApiEndpoints.stickyNotes,
        data: {'noteId': noteId},
      );

      debugPrint('📦 Delete response: ${response.statusCode}');

      if (response.statusCode == 200) {
        _notes.removeWhere((n) => n.id == noteId);
        _lastUpdated = DateTime.now();
        notifyListeners();
        debugPrint('✅ Sticky note deleted successfully');
        return true;
      }

      return false;
    } on DioException catch (e) {
      debugPrint('❌ Delete error: ${e.type} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('❌ Unexpected delete error: $e');
      return false;
    }
  }

  /// Get sticky note by ID
  StickyNoteModel? getStickyNoteById(String id) {
    try {
      return _notes.firstWhere((note) => note.id == id);
    } catch (e) {
      debugPrint('⚠️ Sticky note not found: $id');
      return null;
    }
  }

  /// Filter notes by search query
  List<StickyNoteModel> filterNotes(String query) {
    if (query.isEmpty) return _notes;

    final lowerQuery = query.toLowerCase();
    return _notes.where((note) {
      return note.customerName.toLowerCase().contains(lowerQuery) ||
          note.shopName.toLowerCase().contains(lowerQuery) ||
          note.items.any((item) =>
              item.productName.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  /// Group notes by time (Today, Yesterday, This Week, Older)
  Map<String, List<StickyNoteModel>> getGroupedNotes() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisWeekStart = today.subtract(Duration(days: now.weekday - 1));

    final grouped = <String, List<StickyNoteModel>>{
      'today': [],
      'yesterday': [],
      'this_week': [],
      'older': [],
    };

    for (final note in _notes) {
      final noteDate = DateTime(
        note.createdAt.year,
        note.createdAt.month,
        note.createdAt.day,
      );

      if (noteDate == today) {
        grouped['today']!.add(note);
      } else if (noteDate == yesterday) {
        grouped['yesterday']!.add(note);
      } else if (noteDate.isAfter(thisWeekStart) ||
          noteDate.isAtSameMomentAs(thisWeekStart)) {
        grouped['this_week']!.add(note);
      } else {
        grouped['older']!.add(note);
      }
    }

    return grouped;
  }

  /// Get statistics
  int get totalNotes => _notes.length;
  
  int get todayNotes {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    return _notes.where((note) {
      final noteDate = DateTime(
        note.createdAt.year,
        note.createdAt.month,
        note.createdAt.day,
      );
      return noteDate == todayDate;
    }).length;
  }

  int get thisWeekNotes {
    final now = DateTime.now();
    final thisWeekStart = now.subtract(Duration(days: now.weekday - 1));
    return _notes.where((note) => note.createdAt.isAfter(thisWeekStart)).length;
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Handle Dio errors
  String _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please check your internet.';

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 401) {
          return 'Unauthorized. Please login again.';
        } else if (statusCode == 404) {
          return 'No sticky notes found.';
        } else if (statusCode == 500) {
          return 'Server error. Please try again later.';
        }
        return 'Failed to load sticky notes (Error $statusCode)';

      case DioExceptionType.cancel:
        return 'Request was cancelled.';

      case DioExceptionType.connectionError:
        return 'No internet connection.';

      default:
        return 'Failed to load sticky notes.';
    }
  }
}