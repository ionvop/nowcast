import 'package:geolocator/geolocator.dart';

/// Result of a location request, describing the outcome for the UI.
class LocationResult {
  const LocationResult._({this.lat, this.lng, this.denied = false});

  final double? lat;
  final double? lng;
  final bool denied;

  bool get available => lat != null && lng != null;
}

/// Thin wrapper around geolocator for the current device location.
class LocationService {
  const LocationService();

  /// Requests location permission (if needed) and returns the device position.
  ///
  /// Returns a [LocationResult] with `denied = true` if permission was denied.
  Future<LocationResult> getCurrentLocation() async {
    bool serviceEnabled;
    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return const LocationResult._(denied: true);
    }
    if (!serviceEnabled) {
      return const LocationResult._(denied: true);
    }

    LocationPermission permission;
    try {
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
    } catch (_) {
      return const LocationResult._(denied: true);
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return const LocationResult._(denied: true);
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return LocationResult._(lat: position.latitude, lng: position.longitude);
    } catch (_) {
      return const LocationResult._(denied: true);
    }
  }
}
