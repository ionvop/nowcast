import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nowcast/src/api/api_client.dart';
import 'package:nowcast/src/utils/geolocation.dart';
import 'package:nowcast/src/utils/position_cache.dart';

/// A [GeolocatorPlatform] whose individual steps can be made to hang, fail, or
/// succeed, so the timeout and fallback paths in `getPosition()` can be
/// exercised without a device.
class _FakeGeolocator extends GeolocatorPlatform {
  _FakeGeolocator({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.permissionAfterRequest,
    this.requestPermissionHangs = false,
    this.requestPermissionThrowsInProgress = false,
    this.positionHangs = false,
    this.positionThrows = false,
    this.lastKnownPosition,
  });

  /// What [isLocationServiceEnabled] reports.
  final bool serviceEnabled;

  /// What [checkPermission] reports before any request.
  final LocationPermission permission;

  /// What [checkPermission] reports after [requestPermission] was attempted.
  /// Defaults to [permission].
  final LocationPermission? permissionAfterRequest;

  /// When true, [requestPermission] never completes.
  final bool requestPermissionHangs;

  /// When true, [requestPermission] throws
  /// [PermissionRequestInProgressException].
  final bool requestPermissionThrowsInProgress;

  /// When true, [getCurrentPosition] never completes.
  final bool positionHangs;

  /// When true, [getCurrentPosition] throws a [PlatformException], as the
  /// platform does when a background isolate is denied a fresh fix.
  final bool positionThrows;

  /// The value returned by [getLastKnownPosition].
  final Position? lastKnownPosition;

  bool _requested = false;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async {
    if (_requested && permissionAfterRequest != null) {
      return permissionAfterRequest!;
    }
    return permission;
  }

  @override
  Future<LocationPermission> requestPermission() {
    _requested = true;
    if (requestPermissionThrowsInProgress) {
      throw const PermissionRequestInProgressException(null);
    }
    if (requestPermissionHangs) {
      return Completer<LocationPermission>().future;
    }
    return Future<LocationPermission>.value(
      permissionAfterRequest ?? permission,
    );
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    if (positionThrows) {
      throw PlatformException(
        code: 'ERROR_WHILE_ACQUIRING_POSITION',
        message: 'Location can only be used while using the app',
      );
    }
    if (positionHangs) {
      return Completer<Position>().future;
    }
    return Future<Position>.value(_defaultPosition);
  }

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => lastKnownPosition;
}

final Position _defaultPosition = Position(
  latitude: 37.7749,
  longitude: -122.4194,
  timestamp: DateTime.now(),
  accuracy: 5.0,
  altitude: 0.0,
  altitudeAccuracy: 0.0,
  heading: 0.0,
  headingAccuracy: 0.0,
  speed: 0.0,
  speedAccuracy: 0.0,
);

/// A short timeout so the hanging paths resolve quickly in tests.
const Duration _shortTimeout = Duration(milliseconds: 20);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('getPosition', () {
    test('returns the current position when everything succeeds', () async {
      GeolocatorPlatform.instance = _FakeGeolocator();

      final position = await getPosition(timeout: _shortTimeout);

      expect(position.latitude, closeTo(37.7749, 1e-6));
      expect(position.longitude, closeTo(-122.4194, 1e-6));
    });

    test('throws when location services are disabled', () async {
      GeolocatorPlatform.instance = _FakeGeolocator(serviceEnabled: false);

      await expectLater(
        getPosition(subject: 'weather', timeout: _shortTimeout),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.message,
            'message',
            contains('Location services are disabled'),
          ),
        ),
      );
    });

    test('throws when permission is permanently denied', () async {
      GeolocatorPlatform.instance = _FakeGeolocator(
        permission: LocationPermission.deniedForever,
      );

      await expectLater(
        getPosition(subject: 'weather', timeout: _shortTimeout),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.message,
            'message',
            contains('permanently denied'),
          ),
        ),
      );
    });

    test('throws when the user denies the permission request', () async {
      GeolocatorPlatform.instance = _FakeGeolocator(
        permission: LocationPermission.denied,
        permissionAfterRequest: LocationPermission.denied,
      );

      await expectLater(
        getPosition(subject: 'weather', timeout: _shortTimeout),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.message,
            'message',
            contains('Location permission was denied'),
          ),
        ),
      );
    });

    test('continues when the permission request hangs but access was granted',
        () async {
      // The dialog never reports back, but the permission was granted while it
      // was open — the re-check must pick that up instead of hanging.
      GeolocatorPlatform.instance = _FakeGeolocator(
        permission: LocationPermission.denied,
        permissionAfterRequest: LocationPermission.whileInUse,
        requestPermissionHangs: true,
      );

      final position = await getPosition(timeout: _shortTimeout);

      expect(position.latitude, closeTo(37.7749, 1e-6));
    });

    test('throws when the permission request hangs and access stays denied',
        () async {
      GeolocatorPlatform.instance = _FakeGeolocator(
        permission: LocationPermission.denied,
        permissionAfterRequest: LocationPermission.denied,
        requestPermissionHangs: true,
      );

      await expectLater(
        getPosition(subject: 'weather', timeout: _shortTimeout),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.message,
            'message',
            contains('Couldn\'t confirm location permission'),
          ),
        ),
      );
    });

    test('re-checks permission when a request is already in progress',
        () async {
      GeolocatorPlatform.instance = _FakeGeolocator(
        permission: LocationPermission.denied,
        permissionAfterRequest: LocationPermission.whileInUse,
        requestPermissionThrowsInProgress: true,
      );

      final position = await getPosition(timeout: _shortTimeout);

      expect(position.latitude, closeTo(37.7749, 1e-6));
    });

    test('falls back to the last known position when the fix times out',
        () async {
      final cached = Position(
        latitude: 51.5074,
        longitude: -0.1278,
        timestamp: DateTime.now(),
        accuracy: 20.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
      GeolocatorPlatform.instance = _FakeGeolocator(
        positionHangs: true,
        lastKnownPosition: cached,
      );

      final position = await getPosition(timeout: _shortTimeout);

      expect(position.latitude, closeTo(51.5074, 1e-6));
      expect(position.longitude, closeTo(-0.1278, 1e-6));
    });

    test('throws when the fix times out and no cached position exists',
        () async {
      GeolocatorPlatform.instance = _FakeGeolocator(positionHangs: true);

      await expectLater(
        getPosition(subject: 'weather', timeout: _shortTimeout),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.message,
            'message',
            contains('Couldn\'t determine your location'),
          ),
        ),
      );
    });

    test('writes the resolved position to the app-level cache', () async {
      GeolocatorPlatform.instance = _FakeGeolocator();

      await getPosition(timeout: _shortTimeout);

      final cached = await readCachedPosition();
      expect(cached, isNotNull);
      expect(cached!.latitude, closeTo(37.7749, 1e-6));
    });

    test('falls back to the app-level cache when the fix is rejected',
        () async {
      // Simulates a background isolate: the platform refuses a fresh fix and
      // has no OS-level last known position either.
      await cachePosition(
        Position(
          latitude: 35.6762,
          longitude: 139.6503,
          timestamp: DateTime.now(),
          accuracy: 30.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        ),
      );
      GeolocatorPlatform.instance = _FakeGeolocator(positionThrows: true);

      final position = await getPosition(timeout: _shortTimeout);

      expect(position.latitude, closeTo(35.6762, 1e-6));
      expect(position.longitude, closeTo(139.6503, 1e-6));
    });
  });

  group('getPositionSilently', () {
    test('returns the current position when permission is already granted',
        () async {
      GeolocatorPlatform.instance = _FakeGeolocator();

      final position = await getPositionSilently(timeout: _shortTimeout);

      expect(position, isNotNull);
      expect(position!.latitude, closeTo(37.7749, 1e-6));
    });

    test('returns null when permission is denied', () async {
      GeolocatorPlatform.instance = _FakeGeolocator(
        permission: LocationPermission.denied,
      );

      expect(await getPositionSilently(timeout: _shortTimeout), isNull);
    });

    test('returns null when location services are disabled', () async {
      GeolocatorPlatform.instance = _FakeGeolocator(serviceEnabled: false);

      expect(await getPositionSilently(timeout: _shortTimeout), isNull);
    });

    test('falls back to the last known position when the fix times out',
        () async {
      final cached = Position(
        latitude: 48.8566,
        longitude: 2.3522,
        timestamp: DateTime.now(),
        accuracy: 20.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
      GeolocatorPlatform.instance = _FakeGeolocator(
        positionHangs: true,
        lastKnownPosition: cached,
      );

      final position = await getPositionSilently(timeout: _shortTimeout);

      expect(position, isNotNull);
      expect(position!.latitude, closeTo(48.8566, 1e-6));
    });

    test('returns null when the fix times out and nothing is cached',
        () async {
      GeolocatorPlatform.instance = _FakeGeolocator(positionHangs: true);

      expect(await getPositionSilently(timeout: _shortTimeout), isNull);
    });

    test('returns the app-level cache without touching the platform',
        () async {
      await cachePosition(
        Position(
          latitude: 48.8566,
          longitude: 2.3522,
          timestamp: DateTime.now(),
          accuracy: 20.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        ),
      );
      // Permission denied and services disabled: the platform would return
      // null, so a non-null result can only come from the cache.
      GeolocatorPlatform.instance = _FakeGeolocator(
        serviceEnabled: false,
        permission: LocationPermission.denied,
      );

      final position = await getPositionSilently(timeout: _shortTimeout);

      expect(position, isNotNull);
      expect(position!.latitude, closeTo(48.8566, 1e-6));
    });

    test('returns the app-level cache when the fix is rejected', () async {
      await cachePosition(
        Position(
          latitude: 52.52,
          longitude: 13.405,
          timestamp: DateTime.now(),
          accuracy: 20.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        ),
      );
      GeolocatorPlatform.instance = _FakeGeolocator(positionThrows: true);

      final position = await getPositionSilently(timeout: _shortTimeout);

      expect(position, isNotNull);
      expect(position!.latitude, closeTo(52.52, 1e-6));
    });
  });
}
