import 'package:flutter/material.dart';

/// Central theme definition for the Nowcast app.
///
/// Mirrors the visual identity of the legacy web app: a bright sky-blue
/// accent (`#0AF`), a very light blue-gray content background (`#EEF`), white
/// cards with rounded corners, and a light-only color scheme.
abstract final class AppTheme {
  /// Primary accent used across the app (header, nav, buttons).
  static const Color seed = Color(0xFF00AAFF);

  /// Light content background (matches the legacy `#EEF`).
  static const Color background = Color(0xFFEEEEFF);

  /// Card / surface color (white).
  static const Color surface = Color(0xFFFFFFFF);

  /// Dark content background.
  static const Color darkBackground = Color(0xFF121212);

  /// Dark card / surface color.
  static const Color darkSurface = Color(0xFF1E1E1E);

  /// Build the app-wide [ThemeData] for light mode, matching the legacy web
  /// app's visual identity.
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: seed);

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: seed,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: seed.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? seed : const Color(0xFF555555),
            );
          },
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? seed : const Color(0xFF555555),
            );
          },
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: seed,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  /// Build the app-wide [ThemeData] for dark mode.
  ///
  /// Uses the same sky-blue accent as light mode but with a dark scaffold and
  /// surface so the app is comfortable to use in low-light conditions.
  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        indicatorColor: seed.withValues(alpha: 0.24),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? seed : Colors.white70,
            );
          },
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? seed : Colors.white70,
            );
          },
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: seed,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
