/// A single crowd-sourced heat reading on the map, as returned by the
/// Laravel proxy API. Parsed defensively.
///
/// The API returns two slightly different shapes depending on the endpoint:
/// - `POST /api/heat-locations` returns snake_case fields
///   (`heat_index`, `created_at`, `updated_at`).
/// - `POST /api/analyze-heat-location` returns camelCase fields
///   (`heatIndex`, `createdAt`).
///
/// [HeatLocation.fromJson] accepts both so the same model can back the
/// pre-existing markers and the freshly analyzed one.
class HeatLocation {
  const HeatLocation({
    this.id,
    required this.heatIndex,
    required this.latitude,
    required this.longitude,
    this.createdAt,
  });

  /// Database id, when present (from `heat-locations`).
  final int? id;

  /// Heat index in degrees Celsius. May be `null` when the value could not
  /// be calculated (data license restrictions / local market protections).
  final double? heatIndex;

  final double latitude;

  final double longitude;

  /// When the reading was recorded, when present.
  final DateTime? createdAt;

  factory HeatLocation.fromJson(Map<String, dynamic> json) {
    return HeatLocation(
      id: _int(json['id']),
      heatIndex: _double(json['heatIndex'] ?? json['heat_index']),
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