import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nowcast/src/models/weather.dart';
import 'package:nowcast/src/models/weather_location.dart';
import 'package:nowcast/src/services/heat_danger_cooldown.dart';
import 'package:nowcast/src/utils/heat_danger.dart';

WeatherLocation _location({
  required double latitude,
  required double longitude,
  double? heatIndexC,
}) {
  return WeatherLocation(
    latitude: latitude,
    longitude: longitude,
    data: heatIndexC == null
        ? null
        : Weather(
            condition: const WeatherCondition(
              iconBaseUri: '',
              description: '',
            ),
            temperatureC: heatIndexC,
            feelsLikeC: heatIndexC,
            heatIndexC: heatIndexC,
          ),
  );
}

void main() {
  group('haversineKm', () {
    test('returns ~0 for identical coordinates', () {
      expect(haversineKm(0, 0, 0, 0), closeTo(0, 0.001));
    });

    test('1 degree of latitude is ~111 km', () {
      expect(haversineKm(0, 0, 1, 0), closeTo(111.19, 1.0));
    });

    test('is symmetric', () {
      final a = haversineKm(10, 20, 30, 40);
      final b = haversineKm(30, 40, 10, 20);
      expect(a, closeTo(b, 0.0001));
    });
  });

  group('isDangerousLocation', () {
    const userLat = 0.0;
    const userLon = 0.0;

    test('true when within distance and above threshold', () {
      final loc = _location(latitude: 0.01, longitude: 0, heatIndexC: 41);
      expect(
        isDangerousLocation(
          loc,
          userLat: userLat,
          userLon: userLon,
          maxDistanceKm: 5,
          thresholdC: 40,
        ),
        isTrue,
      );
    });

    test('false when heat index is at or below threshold', () {
      final loc = _location(latitude: 0.01, longitude: 0, heatIndexC: 40);
      expect(
        isDangerousLocation(
          loc,
          userLat: userLat,
          userLon: userLon,
          maxDistanceKm: 5,
          thresholdC: 40,
        ),
        isFalse,
      );
    });

    test('false when beyond distance', () {
      final loc = _location(latitude: 1.0, longitude: 0, heatIndexC: 45);
      expect(
        isDangerousLocation(
          loc,
          userLat: userLat,
          userLon: userLon,
          maxDistanceKm: 5,
          thresholdC: 40,
        ),
        isFalse,
      );
    });

    test('false when heat index is null', () {
      final loc = _location(latitude: 0.01, longitude: 0, heatIndexC: null);
      expect(
        isDangerousLocation(
          loc,
          userLat: userLat,
          userLon: userLon,
          maxDistanceKm: 5,
          thresholdC: 40,
        ),
        isFalse,
      );
    });
  });

  group('findNearestDanger', () {
    test('returns null when no location qualifies', () {
      final result = findNearestDanger(
        <WeatherLocation>[
          _location(latitude: 0.01, longitude: 0, heatIndexC: 30),
          _location(latitude: 1.0, longitude: 0, heatIndexC: 45),
        ],
        userLat: 0,
        userLon: 0,
        maxDistanceKm: 5,
        thresholdC: 40,
      );
      expect(result, isNull);
    });

    test('returns the nearest qualifying location', () {
      final far = _location(latitude: 0.03, longitude: 0, heatIndexC: 45);
      final near = _location(latitude: 0.01, longitude: 0, heatIndexC: 45);
      final result = findNearestDanger(
        <WeatherLocation>[far, near],
        userLat: 0,
        userLon: 0,
        maxDistanceKm: 5,
        thresholdC: 40,
      );
      expect(result, same(near));
    });
  });

  group('HeatDangerCooldown', () {
    test('canShow is true when never shown', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final cooldown = HeatDangerCooldown(prefs: prefs);
      expect(await cooldown.canShow(), isTrue);
    });

    test('canShow is false when shown recently', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      var now = DateTime(2026, 9, 9, 12, 0);
      final cooldown = HeatDangerCooldown(
        prefs: prefs,
        now: () => now,
      );
      await cooldown.recordShown();
      // 1 hour later — still within the 2-hour cooldown.
      now = DateTime(2026, 9, 9, 13, 0);
      expect(await cooldown.canShow(), isFalse);
    });

    test('canShow is true again after the cooldown elapses', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      var now = DateTime(2026, 9, 9, 12, 0);
      final cooldown = HeatDangerCooldown(
        prefs: prefs,
        now: () => now,
      );
      await cooldown.recordShown();
      // 3 hours later — past the 2-hour cooldown.
      now = DateTime(2026, 9, 9, 15, 0);
      expect(await cooldown.canShow(), isTrue);
    });

    test('cooldown persists across instances (survives restart)', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final first = HeatDangerCooldown(
        prefs: prefs,
        now: () => DateTime(2026, 9, 9, 12, 0),
      );
      await first.recordShown();

      // A fresh instance reading the same persisted prefs sees the cooldown.
      final second = HeatDangerCooldown(
        prefs: prefs,
        now: () => DateTime(2026, 9, 9, 13, 0),
      );
      expect(await second.canShow(), isFalse);
    });
  });
}