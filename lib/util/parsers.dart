/// Shared parsing and formatting utilities used across models, viewmodels, and services.
///
/// Eliminates duplicate _toInt, _toDouble, _dateKey, _formatMinutes, etc.
/// that were copy-pasted across 15+ files.
class Parsers {
  Parsers._();

  // ─── Type conversion ───────────────────────────────────────────────────

  /// Safely converts any dynamic value to int.
  /// Handles null, int, double, num, and String.
  static int toInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  /// Safely converts any dynamic value to double.
  /// Handles null, double, int, num, and String.
  static double toDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  /// Safely converts any dynamic value to bool.
  static bool toBool(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is int) return value == 1;
    final text = value.toString().toLowerCase().trim();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return fallback;
  }

  // ─── Date formatting ──────────────────────────────────────────────────

  /// Returns a date string in 'YYYY-MM-DD' format.
  static String dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Returns today's date as 'YYYY-MM-DD'.
  static String todayKey() => dateKey(DateTime.now());

  /// Normalizes a raw date string to 'YYYY-MM-DD' (first 10 chars).
  static String normalizeDateKey(String rawDate) =>
      rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;

  // ─── Time formatting ──────────────────────────────────────────────────

  /// Formats total minutes as 'Xh Ym'.
  static String formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h ${m}m';
  }

  /// Formats total screen time minutes as 'Xh Ym' or 'Ym'.
  static String formatScreenTime(int totalMinutes) {
    if (totalMinutes <= 0) return '0m';
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  /// Parses a 'HH:MM:SS' time string into hour and minute.
  static ({int hour, int minute}) parseTime(dynamic input) {
    final timeStr = (input ?? '00:00:00').toString();
    final parts = timeStr.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return (hour: hour, minute: minute);
  }
}