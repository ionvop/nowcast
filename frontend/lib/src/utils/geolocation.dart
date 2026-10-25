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

/// Resolves the device's current location **without ever prompting** for
/// permission, returning `null` when it cannot be determined.
///
/// This is the variant used by the floating bubble, which runs in the overlay
/// isolate where there is no foreground `Activity` to host a permission
/// dialog. It returns `null` when location services are disabled or the
/// permission has not already been granted, and falls back to the last known
/// position when a fresh fix times out.
Future<Position?> getPositionSilently({
  Duration timeout = const Duration(seconds: 10),
}) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return null;
    }
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(timeLimit: timeout),
      );
    } on Exception {
      return await Geolocator.getLastKnownPosition();
    }
  } on Exception {
    return null;
  }
}
