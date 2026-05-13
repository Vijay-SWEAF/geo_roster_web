import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

class AppUtils {
  AppUtils._();

  /// Format a DateTime to a human-readable relative time (e.g. "3 hours ago")
  static String timeAgo(DateTime dateTime) =>
      timeago.format(dateTime, locale: 'en');

  /// Format a DateTime to a readable date string
  static String formatDate(DateTime dateTime, {String pattern = 'd MMM yyyy'}) =>
      DateFormat(pattern).format(dateTime);

  /// Format a DateTime to date + time
  static String formatDateTime(DateTime dateTime) =>
      DateFormat('d MMM yyyy, h:mm a').format(dateTime);

  /// Capitalize first letter of a string
  static String capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  /// Convert snake_case to Title Case for display
  static String snakeToTitle(String s) =>
      s.split('_').map(capitalize).join(' ');

  /// Validate phone number (simple check)
  static bool isValidPhone(String phone) =>
      RegExp(r'^\+?[0-9]{10,13}$').hasMatch(phone.trim());

  /// Validate email
  static bool isValidEmail(String email) =>
      RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email.trim());

  /// Show a snackbar message
  static void showSnack(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFF9B2226) : const Color(0xFF2D6A4F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Check if a post contains auto-flag keywords
  static bool containsFlagKeywords(String text, List<String> keywords) {
    final lower = text.toLowerCase();
    return keywords.any((k) => lower.contains(k.toLowerCase()));
  }

  /// Normalize a village/community label into a stable key string.
  static String villageKey(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}
