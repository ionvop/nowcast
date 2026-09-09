import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nowcast/src/models/weather.dart';
import 'package:nowcast/src/models/weather_location.dart';
import 'package:nowcast/src/services/heat_danger_cooldown.dart';
import 'package:nowcast/src/utils/flood_danger.dart';

WeatherLocation _location({
  required double latitude,
  required double longitude,
  double? qpfMm,
  int? popPercent,
}) {
  return WeatherLocation(
    latitude: latitude,
    longitude: longitude,
    data: qpfMm == null && popPercent == null
        ? null
        : Weather(
            condition: const WeatherCondition(
              iconBaseUri: '',
              description: '',
            ),
            temperatureC: 20,
            feelsLikeC: 20,
            precipitationQpfQuantity: qpfMm,
            precipitationPercent: popPercent,
          ),
  );
}

void main() {
  group('isFloodDangerLocation', () {
    const userLat = 0.0;
    const userLon = 0.0;

    test('true when within distance and above both thresholds', () {
      final loc = _location(
        latitude: 0.01,
        longitude: 0,
        qpfMm: 35,
        popPercent: 60,
      );
      expect(
        isFloodDangerLocation(
          loc,
          userLat: userLat,
          userLon: userLon,
          maxDistanceKm: 5,
          qpfThresholdMm: 30,
          popThresholdPercent: 50,
        ),
        isTrue,
      );
    });

    test('false when QPF is at or below threshold', () {
      final loc = _location(
        latitude: 0.01,
        longitude: 0,
        qpfMm: 30,
        popPercent: 60,
      );
      expect(
        isFloodDangerLocation(
          loc,
          userLat: userLat,
          userLon: userLon,
          maxDistanceKm: 5,
          qpfThresholdMm: 30,
          popThresholdPercent: 50,
        ),
        isFalse,
      );
    });

    test('false when probability of precipitation is at or below threshold',
        () {
      final loc = _location(
        latitude: 0.01,
        longitude: 0,
        qpfMm: 35,
        popPercent: 50,
      );
      expect(
        isFloodDangerLocation(
          loc,
          userLat: userLat,
          userLon: userLon,
          maxDistanceKm: 5,
          qpfThresholdMm: 30,
          popThresholdPercent: 50,
        ),
        isFalse,
      );
    });

    test('false when beyond distance', () {
      final loc = _location(
        latitude: 1.0,
        longitude: 0,
        qpfMm: 35,
        popPercent: 60,
      );
      expect(
        isFloodDangerLocation(
          loc,
          userLat: userLat,
          userLon: userLon,
          maxDistanceKm: 5,
          qpfThresholdMm: 30,
          popThresholdPercent: 50,
        ),
        isFalse,
      );
    });

    test('false when QPF is null', () {
      final loc = _location(
        latitude: 0.01,
        longitude: 0,
        qpfMm: null,
        popPercent: 60,
      );
      expect(
        isFloodDangerLocation(
          loc,
          userLat: userLat,
          userLon: userLon,
          maxDistanceKm: 5,
          qpfThresholdMm: 30,
          popThresholdPercent: 50,
        ),
        isFalse,
      );
    });

    test('false when probability of precipitation is null', () {
      final loc = _location(
        latitude: 0.01,
        longitude: 0,
        qpfMm: 35,
        popPercent: null,
      );
      expect(
        isFloodDangerLocation(
          loc,
          userLat: userLat,
          userLon: userLon,
          maxDistanceKm: 5,
          qpfThresholdMm: 30,
          popThresholdPercent: 50,
        ),
        isFalse,
      );
    });
  });

  group('findNearestFloodDanger', () {
    test('returns null when no location qualifies', () {
      final result = findNearestFloodDanger(
        <WeatherLocation>[
          _location(latitude: 0.01, longitude: 0, qpfMm: 20, popPercent: 60),
          _location(latitude: 1.0, longitude: 0, qpfMm: 35, popPercent: 60),
        ],
        userLat: 0,
        userLon: 0,
        maxDistanceKm: 5,
        qpfThresholdMm: 30,
        popThresholdPercent: 50,
      );
      expect(result, isNull);
    });

    test('returns the nearest qualifying location', () {
      final far = _location(latitude: 0.03, longitude: 0, qpfMm: 35, popPercent: 60);
      final near = _location(latitude: 0.01, longitude: 0, qpfMm: 35, popPercent: 60);
      final result = findNearestFloodDanger(
        <WeatherLocation>[far, near],
        userLat: 0,
        userLon: 0,
        maxDistanceKm: 5,
        qpfThresholdMm: 30,
        popThresholdPercent: 50,
      );
      expect(result, same(near));
    });
  });

  group('shared cooldown with heat danger', () {
    test('flood dialog is suppressed while heat cooldown is active', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      var now = DateTime(2026, 9, 9, 12, 0);
      final cooldown = HeatDangerCooldown(
        prefs: prefs,
        now: () => now,
      );
      // Showing the heat dialog records the shared last-shown timestamp.
      await cooldown.recordShown();
      // 1 hour later — still within the shared 2-hour cooldown.
      now = DateTime(2026, 9, 9, 13, 0);
      expect(await cooldown.canShow(), isFalse);
    });

    test('flood dialog can show again after the shared cooldown elapses',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      var now = DateTime(2026, 9, 9, 12, 0);
      final cooldown = HeatDangerCooldown(
        prefs: prefs,
        now: () => now,
      );
      await cooldown.recordShown();
      // 3 hours later — past the shared 2-hour cooldown.
      now = DateTime(2026, 9, 9, 15, 0);
      expect(await cooldown.canShow(), isTrue);
    });
  });
}