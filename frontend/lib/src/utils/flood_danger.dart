import '../config/flood_danger_config.dart';
import '../models/weather_location.dart';
import 'heat_danger.dart' show haversineKm;

/// Whether [location] predicts heavy rain and is within [maxDistanceKm] of
/// [userLat]/[userLon].
///
/// Returns `false` when the reading has no QPF or probability of
/// precipitation, when its QPF does not strictly exceed [qpfThresholdMm],
/// when its probability of precipitation does not strictly exceed
/// [popThresholdPercent], or when it is farther than [maxDistanceKm] away.
bool isFloodDangerLocation(
  WeatherLocation location, {
  required double userLat,
  required double userLon,
  double maxDistanceKm = FloodDangerConfig.distanceKm,
  double qpfThresholdMm = FloodDangerConfig.qpfThresholdMm,
  int popThresholdPercent = FloodDangerConfig.popThresholdPercent,
}) {
  final qpf = location.data?.precipitationQpfQuantity;
  final pop = location.data?.precipitationPercent;
  if (qpf == null || qpf <= qpfThresholdMm) return false;
  if (pop == null || pop <= popThresholdPercent) return false;
  final distance = haversineKm(
    userLat,
    userLon,
    location.latitude,
    location.longitude,
  );
  return distance <= maxDistanceKm;
}

/// Returns the nearest [WeatherLocation] that predicts heavy rain and is
/// within [maxDistanceKm] of the user's position, or `null` when none
/// qualifies.
WeatherLocation? findNearestFloodDanger(
  List<WeatherLocation> locations, {
  required double userLat,
  required double userLon,
  double maxDistanceKm = FloodDangerConfig.distanceKm,
  double qpfThresholdMm = FloodDangerConfig.qpfThresholdMm,
  int popThresholdPercent = FloodDangerConfig.popThresholdPercent,
}) {
  WeatherLocation? nearest;
  double? nearestDistance;

  for (final location in locations) {
    if (!isFloodDangerLocation(
          location,
          userLat: userLat,
          userLon: userLon,
          maxDistanceKm: maxDistanceKm,
          qpfThresholdMm: qpfThresholdMm,
          popThresholdPercent: popThresholdPercent,
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