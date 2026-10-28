import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared_preferences key under which the last resolved position is stored.
const String kCachedPositionKey = 'cached_position';

/// How long a cached position stays usable.
///
/// The floating bubble runs in a foreground service that Android does not
/// treat as "while using the app", so it can never obtain a fresh fix. It
/// therefore relies on the position cached by the last successful foreground
/// lookup. A position older than this is discarded so the bubble does not
/// suggest activities in a city the user left days ago.
const Duration kPositionCacheMaxAge = Duration(hours: 6);

/// Persists [position] so the overlay isolate can reuse it later.
///
/// Best-effort: any failure (no plugin, storage error) is swallowed, because
/// caching must never break a location lookup that otherwise succeeded.
Future<void> cachePosition(Position position) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kCachedPositionKey, jsonEncode(position.toJson()));
  } on Exception {
    // Ignore: the cache is an optimisation, not a requirement.
  }
}

/// Reads the position written by [cachePosition].
///
/// Returns `null` when nothing has been cached, the stored value cannot be
/// decoded, or the position is older than [maxAge].
Future<Position?> readCachedPosition({
  Duration maxAge = kPositionCacheMaxAge,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kCachedPositionKey);
    if (raw == null) return null;

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;

    final position = Position.fromMap(decoded);
    if (DateTime.now().difference(position.timestamp) > maxAge) return null;

    return position;
  } catch (_) {
    // Covers a malformed payload (`FormatException`) as well as a map that is
    // missing the mandatory coordinates (`ArgumentError`, which is an Error
    // rather than an Exception).
    return null;
  }
}
