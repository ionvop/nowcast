import 'dart:math' as math;

import '../config/heat_danger_config.dart';
import '../models/weather_location.dart';

/// Great-circle (haversine) distance between two coordinates, in
/// kilometres. Uses the mean Earth radius (6371 km).
double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const double earthRadiusKm = 6371.0;
  final dLat = _toRadians(lat2 - lat1);
  final dLon = _toRadians(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(lat1)) *
          math.cos(_toRadians(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusKm * c;
}

double _toRadians(double degrees) => degrees * math.pi / 180.0;

/// Whether [location] is dangerously hot and within [maxDistanceKm] of
/// [userLat]/[userLon].
///
/// Returns `false` when the reading has no heat index, when its heat index
/// does not strictly exceed [thresholdC], or when it is farther than
/// [maxDistanceKm] away.

bool isDangerousLocation(
  WeatherLocation location, {
  required double userLat,
  required double userLon,
  double maxDistanceKm = HeatDangerConfig.distanceKm,
  double thresholdC = HeatDangerConfig.thresholdC,
}) {
  final heatIndex = location.data?.heatIndexC;
  if (heatIndex == null || heatIndex <= thresholdC) return false;
  final distance = haversineKm(
    userLat,
    userLon,
    location.latitude,
    location.longitude,
  );
  return distance <= maxDistanceKm;
}

/// Returns the nearest [WeatherLocation] that is dangerously hot and within
/// [maxDistanceKm] of the user's position, or `null` when none qualifies.

WeatherLocation? findNearestDanger(
  List<WeatherLocation> locations, {
  required double userLat,
  required double userLon,
  double maxDistanceKm = HeatDangerConfig.distanceKm,
  double thresholdC = HeatDangerConfig.thresholdC,
}) {
  WeatherLocation? nearest;
  double? nearestDistance;

  for (final location in locations) {
    if (!isDangerousLocation(
          location,
          userLat: userLat,
          userLon: userLon,
          maxDistanceKm: maxDistanceKm,
          thresholdC: thresholdC,
        )) {
      continue;
    }
    final distance = haversineKm(
      userLat,
      userLon,
      location.latitude,
      location.longitude,
    );
    if (nearestDistance == null || distance < nearestDistance) {
      nearest = location;
      nearestDistance = distance;
    }
  }
  return nearest;
}