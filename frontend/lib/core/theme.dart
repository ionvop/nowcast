import 'package:flutter/material.dart';

/// Central theme for Nowcast.
///
/// Theme color: `#0af` (light blue), header bar uses the theme color with
/// white text/icons. Background: light blue-grey `#eef` for content; white
/// for bottom nav and cards. Cards and buttons use `1rem`-ish rounded corners
/// (12.0 logical px) with a 1px theme-colored border.
class AppTheme {
  AppTheme._();

  /// Primary theme color (light blue).
  static const Color primary = Color(0xFF00AAFF);

  /// Content background (light blue-grey).
  static const Color background = Color(0xFFEEEEFF);

  /// Secondary / muted text grey.
  static const Color mutedGrey = Color(0xFF555555);

  /// Corner radius used for cards and buttons (~1rem).
  static const double radius = 12.0;

  /// Border used for cards (1px theme-colored).
  static const Color cardBorder = Color(0xFF00AAFF);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(seedColor: primary);
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme.copyWith(primary: primary),
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: primary.withValues(alpha: 0.15),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight:
                states.contains(WidgetState.selected)
                    ? FontWeight.bold
                    : FontWeight.normal,
            color: states.contains(WidgetState.selected)
                ? primary
                : mutedGrey,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? primary
                : mutedGrey,
          ),
        ),
      ),
    );
  }
}
