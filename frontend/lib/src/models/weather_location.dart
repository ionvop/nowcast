import 'weather.dart';

/// A single crowd-sourced weather reading on the map, as returned by the
/// Laravel proxy API. Parsed defensively.
///
/// Unlike the deprecated [HeatLocation], the `data` field holds the **entire**
/// Google current-conditions payload, so the client can read any weather field
/// it needs (temperature, feels-like, heat index, humidity, wind, etc.).
///
/// The API returns two slightly different shapes depending on the endpoint:
/// - `POST /api/weather-locations` returns snake_case fields
///   (`created_at`, `updated_at`).
/// - `POST /api/analyze-weather-location` returns camelCase fields
///   (`createdAt`).
///
/// [WeatherLocation.fromJson] accepts both so the same model can back the
/// pre-existing markers and the freshly analyzed one.
class WeatherLocation {
  const WeatherLocation({
    this.id,
    this.data,
    required this.latitude,
    required this.longitude,
    this.createdAt,
  });

  /// Database id, when present (from `weather-locations`).
  final int? id;

  /// The full Google current-conditions payload, when present. May be `null`
  /// when the payload is missing or could not be parsed.
  final Weather? data;

  final double latitude;

  final double longitude;

  /// When the reading was recorded, when present.
  final DateTime? createdAt;

  factory WeatherLocation.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return WeatherLocation(
      id: _int(json['id']),
      data: data is Map<String, dynamic> ? Weather.fromJson(data) : null,
      latitude: _double(json['latitude']) ?? 0,
      longitude: _double(json['longitude']) ?? 0,
      createdAt: _dateTime(json['createdAt'] ?? json['created_at']),
    );
  }

  static int? _int(dynamic value) => value is num ? value.toInt() : null;

  static double? _double(dynamic value) => value is num ? value.toDouble() : null;

  static DateTime? _dateTime(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value);
    }
    if (value is num) {
      // Unix seconds (legacy `time` field).
      return DateTime.fromMillisecondsSinceEpoch(value.toInt() * 1000);
    }
    return null;
  }
}
