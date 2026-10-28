import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nowcast/src/utils/position_cache.dart';

Position _position({DateTime? timestamp}) {
  return Position(
    latitude: 37.7749,
    longitude: -122.4194,
    timestamp: timestamp ?? DateTime.now(),
    accuracy: 5.0,
    altitude: 0.0,
    altitudeAccuracy: 0.0,
    heading: 0.0,
    headingAccuracy: 0.0,
    speed: 0.0,
    speedAccuracy: 0.0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('cachePosition / readCachedPosition', () {
    test('round-trips a position', () async {
      await cachePosition(_position());

      final cached = await readCachedPosition();

      expect(cached, isNotNull);
      expect(cached!.latitude, closeTo(37.7749, 1e-6));
      expect(cached.longitude, closeTo(-122.4194, 1e-6));
    });

    test('returns null when nothing has been cached', () async {
      expect(await readCachedPosition(), isNull);
    });

    test('rejects a position older than the max age', () async {
      await cachePosition(
        _position(timestamp: DateTime.now().subtract(const Duration(hours: 7))),
      );

      expect(await readCachedPosition(), isNull);
    });

    test('accepts a position within the max age', () async {
      await cachePosition(
        _position(timestamp: DateTime.now().subtract(const Duration(hours: 5))),
      );

      expect(await readCachedPosition(), isNotNull);
    });

    test('honours a custom max age', () async {
      await cachePosition(
        _position(timestamp: DateTime.now().subtract(const Duration(minutes: 5))),
      );

      expect(
        await readCachedPosition(maxAge: const Duration(minutes: 1)),
        isNull,
      );
    });

    test('returns null when the stored value is not valid JSON', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kCachedPositionKey: 'not json',
      });

      expect(await readCachedPosition(), isNull);
    });

    test('returns null when the stored value is not a map', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kCachedPositionKey: jsonEncode(<String>['nope']),
      });

      expect(await readCachedPosition(), isNull);
    });

    test('returns null when the stored map is missing coordinates', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kCachedPositionKey: jsonEncode(<String, dynamic>{'accuracy': 5.0}),
      });

      expect(await readCachedPosition(), isNull);
    });
  });
}
