import 'package:flutter/foundation.dart' show kIsWeb;

/// Provides the build-time **client-side** Google Maps API key.
///
/// This key is distinct from the server's `GOOGLE_MAPS_KEY` (which must never
/// be compiled into the app). It is passed via
/// `--dart-define=GOOGLE_MAPS_CLIENT_KEY=...` and configured per platform
/// (web JS script tag, Android `<meta-data>`, iOS `AppDelegate`).
class PlatformMapsAdapter {
  PlatformMapsAdapter();

  static const String clientKey = String.fromEnvironment(
    'GOOGLE_MAPS_CLIENT_KEY',
  );

  /// Whether a client key is configured.
  bool get hasKey => clientKey.isNotEmpty;

  /// Human-readable platform name for error messages.
  String get platformName => kIsWeb ? 'web' : 'native';
}