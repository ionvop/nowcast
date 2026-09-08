// Helpers for parsing reverse-geocoding responses from the weather API.

/// Extracts the human-readable formatted address from a raw Google geocode
/// payload (as returned by `POST /api/geocode`).
///
/// Returns `null` when the payload is missing, empty, or doesn't expose a
/// formatted address under `results[0].formattedAddress`.
String? addressFromGeocode(dynamic json) {
  if (json is! Map<String, dynamic>) return null;
  final results = json['results'];
  if (results is! List || results.isEmpty) return null;
  final first = results.first;
  if (first is Map<String, dynamic> && first['formattedAddress'] is String) {
    return first['formattedAddress'] as String;
  }
  return null;
}