import 'package:flutter/foundation.dart'
    show kIsWeb;
import 'dart:io' show Platform;

/// Provides the active API base URL for the current platform.
///
/// - Web: `/api` (reverse proxy serves the Flutter build and the API under
///   `/api`).
/// - Android emulator: `http://10.0.2.2:8000/api`.
/// - iOS simulator / real device / production: `https://yourdomain.com/api`.
///
/// A `--dart-define=API_BASE_URL=...` override wins on any platform.
class BaseUrlAdapter {
  BaseUrlAdapter();

  static const String _override = String.fromEnvironment('API_BASE_URL');

  static String get _defaultNativeUrl {
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api';
    }
    return 'https://yourdomain.com/api';
  }

  /// The active base URL (no trailing slash).
  String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (kIsWeb) return '/api';
    return _defaultNativeUrl;
  }
}