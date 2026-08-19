import 'package:geolocator/geolocator.dart';

import '../api/api_client.dart';

/// Resolves the device's current location, requesting and validating the
/// necessary permissions.
///
/// [subject] is used in the user-facing error messages when location access
/// cannot be granted (e.g. `'weather'` → "…see your local weather").
Future<Position> getPosition({String subject = 'this data'}) async {
  var serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw NetworkException(
      'Location services are disabled. Please enable them to see your '
      'local $subject.',
    );
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied) {
    throw NetworkException(
      'Location permission was denied. Grant location access to see your '
      'local $subject.',
    );
  }
  if (permission == LocationPermission.deniedForever) {
    throw NetworkException(
      'Location permission is permanently denied. Enable it in your '
      'device settings to see your local $subject.',
    );
  }

  return Geolocator.getCurrentPosition();
}