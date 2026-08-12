import 'package:flutter/foundation.dart' show kIsWeb;

/// Resolves the OAuth callback / redirect on the current platform and
/// extracts the Sanctum token.
///
/// - **Web**: the token arrives in the URL fragment (`#token=...` or
///   `#error=1`) after the server-side redirect.
/// - **Native**: the token arrives via a custom scheme / universal link deep
///   link (handled in Phase 8). On web this adapter never performs a native
///   deep-link read.
class OAuthReturnAdapter {
  OAuthReturnAdapter();

  /// Reads the token (or error flag) from the current browser URL fragment.
  /// Returns null when no auth fragment is present.
  ///
  /// Only meaningful on web. On native, token extraction is wired to deep-link
  /// routing separately (Phase 8).
  Map<String, String>? readFragment() {
    if (!kIsWeb) return null;

    String? href;
    try {
      href = Uri.base.toString();
    } catch (_) {
      return null;
    }

    final hashIndex = href.indexOf('#');
    if (hashIndex < 0) return null;
    final fragment = href.substring(hashIndex + 1);
    if (fragment.isEmpty) return null;

    final params = <String, String>{};
    for (final pair in fragment.split('&')) {
      if (pair.isEmpty) continue;
      final idx = pair.indexOf('=');
      if (idx < 0) {
        params[pair] = '';
      } else {
        params[pair.substring(0, idx)] =
            Uri.decodeComponent(pair.substring(idx + 1));
      }
    }
    if (params.containsKey('token') || params.containsKey('error')) {
      return params;
    }
    return null;
  }
}
