// lib/core/utils/date_utils.dart
// Canonical time-formatting utility. All screens and models use this —
// the duplicate methods in StickyNoteModel and DeliveredOrdersScreen
// have been deleted in favour of this single implementation.

import 'package:intl/intl.dart';

class AppDateUtils {
  AppDateUtils._();

  // ─── Conversion ───────────────────────────────────────────────────────────

  /// Converts a UTC DateTime to the device's local timezone.
  static DateTime utcToLocal(DateTime utcDate) => utcDate.toLocal();

  // ─── Formatters ───────────────────────────────────────────────────────────

  static String formatToLocal(DateTime utcDate, String format) {
    return DateFormat(format).format(utcToLocal(utcDate));
  }

  /// e.g. "January 18, 2026 • 02:30 PM"
  static String formatFullDateTime(DateTime utcDate) {
    return formatToLocal(utcDate, 'MMMM dd, yyyy • hh:mm a');
  }

  /// e.g. "Jan 18, 02:30 PM"
  static String formatShortDateTime(DateTime utcDate) {
    return formatToLocal(utcDate, 'MMM dd, hh:mm a');
  }

  /// e.g. "02:30 PM"
  static String formatTime(DateTime utcDate) {
    return formatToLocal(utcDate, 'hh:mm a');
  }

  /// e.g. "Jan 18"
  static String formatShortDate(DateTime utcDate) {
    return formatToLocal(utcDate, 'MMM dd');
  }

  // ─── Date checks ─────────────────────────────────────────────────────────

  static bool isToday(DateTime utcDate) {
    final local = utcToLocal(utcDate);
    final now = DateTime.now();
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }

  static bool isYesterday(DateTime utcDate) {
    final local = utcToLocal(utcDate);
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day;
  }

  // ─── Relative time ───────────────────────────────────────────────────────

  /// Returns a human-readable relative time string, e.g.:
  ///   "Just now", "3 minutes ago", "2 hours ago", "5 days ago", "Jan 18, 2026"
  ///
  /// Previously duplicated in:
  ///   • StickyNoteModel.getRelativeTime()   → deleted, use this
  ///   • DeliveredOrdersScreen._getRelativeTime()  → deleted, use this
  static String getRelativeTime(DateTime utcDate) {
    final local = utcToLocal(utcDate);
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return '$m ${m == 1 ? 'minute' : 'minutes'} ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h ${h == 1 ? 'hour' : 'hours'} ago';
    }
    if (diff.inDays < 7) {
      final d = diff.inDays;
      return '$d ${d == 1 ? 'day' : 'days'} ago';
    }
    return DateFormat('MMM dd, yyyy').format(local);
  }

  /// Shows "Today, 02:30 PM" / "Yesterday, 02:30 PM" / "Jan 18, 02:30 PM"
  static String getSmartDateDisplay(DateTime utcDate) {
    if (isToday(utcDate)) return 'Today, ${formatTime(utcDate)}';
    if (isYesterday(utcDate)) return 'Yesterday, ${formatTime(utcDate)}';
    return formatShortDateTime(utcDate);
  }
}