import 'package:flutter_test/flutter_test.dart';

import 'package:nowcast/src/models/weather_location.dart';

void main() {
  group('WeatherLocation.fromJson', () {
    test('parses the weather-locations (list) shape', () {
      final location = WeatherLocation.fromJson(<String, dynamic>{
        'id': 1,
        'data': <String, dynamic>{
          'temperature': <String, dynamic>{'degrees': 28.5, 'unit': 'CELSIUS'},
          'feelsLikeTemperature': <String, dynamic>{
            'degrees': 31.2,
            'unit': 'CELSIUS',
          },
          'heatIndex': <String, dynamic>{'degrees': 33.0, 'unit': 'CELSIUS'},
        },
        'latitude': 40.7128,
        'longitude': -74.006,
        'created_at': '2026-08-12T12:00:00.000000Z',
        'updated_at': '2026-08-12T12:00:00.000000Z',
      });

      expect(location.id, 1);
      expect(location.latitude, 40.7128);
      expect(location.longitude, -74.006);
      expect(location.createdAt, DateTime.parse('2026-08-12T12:00:00.000000Z'));
      expect(location.data, isNotNull);
      expect(location.data!.heatIndexC, 33.0);
      expect(location.data!.temperatureC, 28.5);
      expect(location.data!.feelsLikeC, 31.2);
    });

    test('parses the analyze-weather-location (camelCase) shape', () {
      final location = WeatherLocation.fromJson(<String, dynamic>{
        'data': <String, dynamic>{
          'temperature': <String, dynamic>{'degrees': 28.5, 'unit': 'CELSIUS'},
          'feelsLikeTemperature': <String, dynamic>{
            'degrees': 31.2,
            'unit': 'CELSIUS',
          },
          'heatIndex': <String, dynamic>{'degrees': 33.0, 'unit': 'CELSIUS'},
        },
        'latitude': 40.7128,
        'longitude': -74.006,
        'createdAt': '2026-08-12T12:00:00.000000Z',
      });

      expect(location.id, isNull);
      expect(location.latitude, 40.7128);
      expect(location.longitude, -74.006);
      expect(location.createdAt, DateTime.parse('2026-08-12T12:00:00.000000Z'));
      expect(location.data!.heatIndexC, 33.0);
    });

    test('falls back to feelsLikeTemperature when heatIndex is absent', () {
      final location = WeatherLocation.fromJson(<String, dynamic>{
        'data': <String, dynamic>{
          'temperature': <String, dynamic>{'degrees': 28.5, 'unit': 'CELSIUS'},
          'feelsLikeTemperature': <String, dynamic>{
            'degrees': 31.2,
            'unit': 'CELSIUS',
          },
        },
        'latitude': 40.7128,
        'longitude': -74.006,
        'created_at': '2026-08-12T12:00:00.000000Z',
      });

      expect(location.data!.heatIndexC, isNull);
      expect(location.data!.feelsLikeC, 31.2);
    });

    test('handles a missing data payload', () {
      final location = WeatherLocation.fromJson(<String, dynamic>{
        'latitude': 40.7128,
        'longitude': -74.006,
        'created_at': '2026-08-12T12:00:00.000000Z',
      });

      expect(location.data, isNull);
      expect(location.latitude, 40.7128);
      expect(location.longitude, -74.006);
    });

    test('defaults latitude/longitude to 0 when absent', () {
      final location = WeatherLocation.fromJson(<String, dynamic>{});

      expect(location.latitude, 0);
      expect(location.longitude, 0);
      expect(location.data, isNull);
      expect(location.createdAt, isNull);
    });
  });
}