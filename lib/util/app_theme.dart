import 'package:flutter/material.dart';

/// Centralized design tokens for DreamSync.
///
/// Every screen should use these instead of hardcoding colors.
/// Usage: `AppTheme.bg(context)`, `AppTheme.accent`, etc.
class AppTheme {
  AppTheme._();

  // ─── Brand colors (constant, no context needed) ─────────────────────────
  static const Color accent = Color(0xFF3B82F6);
  static const Color accentDark = Color(0xFF1E3A8A);
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);

  // ─── Semantic colors (need context for dark/light) ──────────────────────

  /// Scaffold / page background
  static Color bg(BuildContext context) =>
      _isDark(context) ? const Color(0xFF0F172A) : const Color(0xFFF3F3F5);

  /// Card / elevated surface
  static Color card(BuildContext context) =>
      _isDark(context) ? const Color(0xFF1E293B) : Colors.white;

  /// Subtle surface (input fields, chips, secondary containers)
  static Color surface(BuildContext context) =>
      _isDark(context) ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);

  /// Primary text
  static Color text(BuildContext context) =>
      _isDark(context) ? Colors.white : const Color(0xFF1E293B);

  /// Secondary / subtitle text
  static Color subText(BuildContext context) =>
      _isDark(context) ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  /// Divider / border
  static Color border(BuildContext context) =>
      _isDark(context) ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);

  /// Card shadow
  static Color shadow(BuildContext context) =>
      Colors.black.withOpacity(_isDark(context) ? 0.20 : 0.05);

  // ─── Standard radii ─────────────────────────────────────────────────────
  static const double radiusS = 8;
  static const double radiusM = 12;
  static const double radiusL = 16;
  static const double radiusXL = 20;
  static const double radiusRound = 24;

  // ─── Standard card decoration ───────────────────────────────────────────
  static BoxDecoration cardDecoration(BuildContext context) {
    return BoxDecoration(
      color: card(context),
      borderRadius: BorderRadius.circular(radiusXL),
      boxShadow: [
        BoxShadow(
          color: shadow(context),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  /// Card with custom border (e.g. highlighted cards)
  static BoxDecoration cardDecorationWithBorder(
      BuildContext context, {
        Color? borderColor,
      }) {
    return BoxDecoration(
      color: card(context),
      borderRadius: BorderRadius.circular(radiusXL),
      border: Border.all(
        color: borderColor ?? AppTheme.border(context),
      ),
      boxShadow: [
        BoxShadow(
          color: shadow(context),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────
  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static bool isDark(BuildContext context) => _isDark(context);
}