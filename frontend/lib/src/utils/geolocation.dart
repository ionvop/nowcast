import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../api/api_client.dart';

/// How long a single geolocation step (service check, permission check,
/// permission request, or position fix) may take before it is abandoned.
///
/// Without a bound, a permission dialog that never reports back — e.g. the
/// Android activity is recreated while it is open, or the user picked "Ask
/// every time" — or a cold GPS fix that never arrives leaves the caller
/// waiting forever. That surfaces as a permanent "Loading geolocation…"
/// spinner until the app is restarted.
const Duration kLocationTimeout = Duration(seconds: 15);

/// Resolves the device's current location, requesting and validating the
/// necessary permissions.
///
/// [subject] is used in the user-facing error messages when location access
/// cannot be granted (e.g. `'weather'` → "…see your local weather").
///
/// Every step is bounded by [timeout] so a wedged permission dialog or a GPS
/// fix that never arrives surfaces a [NetworkException] — and therefore a
/// "Try again" action — instead of hanging indefinitely. When the fresh fix
/// times out, the last known position is used as a fallback.
Future<Position> getPosition({
  String subject = 'this data',
  Duration timeout = kLocationTimeout,
}) async {
  final bool serviceEnabled;
  try {
    serviceEnabled =
        await Geolocator.isLocationServiceEnabled().timeout(timeout);
  } on TimeoutException {
    throw NetworkException(_disabledMessage(subject));
  }
  if (!serviceEnabled) {
    throw NetworkException(_disabledMessage(subject));
  }

  var permission = await _checkPermission(timeout);
  if (permission == LocationPermission.denied) {
    permission = await _requestPermission(timeout, subject);
  }
  if (permission == LocationPermission.denied) {
    throw NetworkException(_deniedMessage(subject));
  }
  if (permission == LocationPermission.deniedForever) {
    throw NetworkException(_deniedForeverMessage(subject));
  }

  return _currentPosition(timeout, subject);
}

/// Reads the current permission, treating a timeout as "not yet granted" so
/// the caller falls through to requesting it.
Future<LocationPermission> _checkPermission(Duration timeout) async {
  try {
    return await Geolocator.checkPermission().timeout(timeout);
  } on TimeoutException {
    return LocationPermission.denied;
  }
}

/// Requests location permission, bounded by [timeout].
///
/// When the request never reports back (a timeout, or a request already in
/// progress) the permission is re-checked: the user may have granted access
/// while the dialog was open. If it is still denied, a [NetworkException]
/// asks the user to tap "Try again" rather than leaving the UI stuck.
Future<LocationPermission> _requestPermission(
  Duration timeout,
  String subject,
) async {
  try {
    return await Geolocator.requestPermission().timeout(timeout);
  } on TimeoutException {
    // Fall through to the re-check below.
  } on PermissionRequestInProgressException {
    // An earlier request is still pending; re-check instead of waiting.
  }

  final permission = await _checkPermission(timeout);
  if (permission == LocationPermission.denied) {
    throw NetworkException(
      'Couldn\'t confirm location permission. If you granted access, tap '
      'Try again to see your local $subject.',
    );
  }
  return permission;
}

/// Obtains a fresh position fix, falling back to the last known position when
/// the fix times out.
Future<Position> _currentPosition(Duration timeout, String subject) async {
  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(timeLimit: timeout),
    ).timeout(timeout);
  } on TimeoutException {
    // Fall through to the cached position below.
  } on LocationServiceDisabledException {
    throw NetworkException(_disabledMessage(subject));
  } on PermissionDeniedException {
    throw NetworkException(_deniedMessage(subject));
  }

  final lastKnown = await _lastKnownPosition(timeout);
  if (lastKnown != null) return lastKnown;

  throw NetworkException(
    'Couldn\'t determine your location. Make sure you have a clear view of '
    'the sky and tap Try again to see your local $subject.',
  );
}

/// Reads the cached position, returning `null` when it is unavailable.
Future<Position?> _lastKnownPosition(Duration timeout) async {
  try {
    return await Geolocator.getLastKnownPosition().timeout(timeout);
  } on Exception {
    return null;
  }
}

String _disabledMessage(String subject) =>
    'Location services are disabled. Please enable them to see your '
    'local $subject.';

String _deniedMessage(String subject) =>
    'Location permission was denied. Grant location access to see your '
    'local $subject.';

String _deniedForeverMessage(String subject) =>
    'Location permission is permanently denied. Enable it in your '
    'device settings to see your local $subject.';

/// Resolves the device's current location **without ever prompting** for
/// permission, returning `null` when it cannot be determined.
///
/// This is the variant used by the floating bubble, which runs in the overlay
/// isolate where there is no foreground `Activity` to host a permission
/// dialog. It returns `null` when location services are disabled or the
/// permission has not already been granted, and falls back to the last known
/// position when a fresh fix times out.
///
/// Every step is bounded by [timeout] so a wedged platform call cannot stall
/// the caller indefinitely.
Future<Position?> getPositionSilently({
  Duration timeout = const Duration(seconds: 10),
}) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled().timeout(timeout)) {
      return null;
    }
    final permission = await Geolocator.checkPermission().timeout(timeout);
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(timeLimit: timeout),
      ).timeout(timeout);
    } on Exception {
      return await Geolocator.getLastKnownPosition().timeout(timeout);
    }
  } on Exception {
    return null;
  }
}
