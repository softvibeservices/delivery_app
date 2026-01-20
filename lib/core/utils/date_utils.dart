// lib/core/utils/date_utils.dart

import 'package:intl/intl.dart';

class AppDateUtils {
  /// Converts UTC DateTime to local Indian timezone (IST)
  /// IST is UTC+5:30
  static DateTime utcToLocal(DateTime utcDate) {
    // Convert to local time (device timezone)
    return utcDate.toLocal();
  }

  /// Formats a UTC date to IST display format
  static String formatToIST(DateTime utcDate, String format) {
    final localDate = utcToLocal(utcDate);
    return DateFormat(format).format(localDate);
  }

  /// Get relative time string in IST
  static String getRelativeTime(DateTime utcDate) {
    final localDate = utcToLocal(utcDate);
    final now = DateTime.now();
    final difference = now.difference(localDate);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(localDate);
    }
  }

  /// Format for display: "January 18, 2026 • 02:30 PM"
  static String formatFullDateTime(DateTime utcDate) {
    return formatToIST(utcDate, 'MMMM dd, yyyy • hh:mm a');
  }

  /// Format for display: "Jan 18, 02:30 PM"
  static String formatShortDateTime(DateTime utcDate) {
    return formatToIST(utcDate, 'MMM dd, hh:mm a');
  }

  /// Format for display: "02:30 PM"
  static String formatTime(DateTime utcDate) {
    return formatToIST(utcDate, 'hh:mm a');
  }

  /// Format for display: "Jan 18"
  static String formatShortDate(DateTime utcDate) {
    return formatToIST(utcDate, 'MMM dd');
  }

  /// Check if date is today in local timezone
  static bool isToday(DateTime utcDate) {
    final localDate = utcToLocal(utcDate);
    final now = DateTime.now();
    return localDate.year == now.year &&
        localDate.month == now.month &&
        localDate.day == now.day;
  }

  /// Check if date is yesterday in local timezone
  static bool isYesterday(DateTime utcDate) {
    final localDate = utcToLocal(utcDate);
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return localDate.year == yesterday.year &&
        localDate.month == yesterday.month &&
        localDate.day == yesterday.day;
  }

  /// Get display text for date with relative handling
  static String getSmartDateDisplay(DateTime utcDate) {
    if (isToday(utcDate)) {
      return 'Today, ${formatTime(utcDate)}';
    } else if (isYesterday(utcDate)) {
      return 'Yesterday, ${formatTime(utcDate)}';
    } else {
      return formatShortDateTime(utcDate);
    }
  }
}