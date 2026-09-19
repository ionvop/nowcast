import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:nowcast/src/api/api_client.dart';
import 'package:nowcast/src/screens/heat_screen.dart';

/// A fake geolocator platform so `getPosition()` works in widget tests.
class FakeGeolocator extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    return Future<Position>.value(
      Position(
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
      ),
    );
  }
}

/// Builds a raw hourly forecast response with [count] hours.
Map<String, dynamic> hourlyJson(int count) {
  return <String, dynamic>{
    'forecastHours': List<Map<String, dynamic>>.generate(count, (i) {
      return <String, dynamic>{
        'displayDateTime': <String, dynamic>{
          'year': 2026,
          'month': 9,
          'day': 8,
          'hours': 9 + i,
        },
        'weatherCondition': <String, dynamic>{
          'iconBaseUri': 'https://maps.gstatic.com/weather/v1/sunny',
          'description': <String, dynamic>{'text': 'Sunny', 'languageCode': 'en'},
        },
        'temperature': <String, dynamic>{'degrees': 20.0 + i, 'unit': 'CELSIUS'},
        'feelsLikeTemperature': <String, dynamic>{
          'degrees': 21.0 + i,
          'unit': 'CELSIUS',
        },
        'dewPoint': <String, dynamic>{'degrees': 10.0, 'unit': 'CELSIUS'},
        'heatIndex': <String, dynamic>{'degrees': 22.0, 'unit': 'CELSIUS'},
        'windChill': <String, dynamic>{'degrees': 19.0, 'unit': 'CELSIUS'},
        'wetBulbTemperature': <String, dynamic>{
          'degrees': 18.0,
          'unit': 'CELSIUS',
        },
        'uvIndex': 1 + i,
      };
    }),
  };
}

/// Builds a raw daily forecast response with [count] days.
Map<String, dynamic> dailyJson(int count) {
  return <String, dynamic>{
    'forecastDays': List<Map<String, dynamic>>.generate(count, (i) {
      return <String, dynamic>{
        'displayDate': <String, dynamic>{
          'year': 2026,
          'month': 9,
          'day': 8 + i,
        },
        'daytimeForecast': <String, dynamic>{
          'weatherCondition': <String, dynamic>{
            'iconBaseUri': 'https://maps.gstatic.com/weather/v1/sunny',
            'description': <String, dynamic>{
              'text': 'Sunny',
              'languageCode': 'en',
            },
          },
          'uvIndex': 3 + i,
          'precipitation': <String, dynamic>{
            'probability': <String, dynamic>{'percent': 5, 'type': 'RAIN'},
          },
        },
        'maxTemperature': <String, dynamic>{
          'degrees': 25.0 + i,
          'unit': 'CELSIUS',
        },
        'minTemperature': <String, dynamic>{
          'degrees': 15.0 + i,
          'unit': 'CELSIUS',
        },
        'feelsLikeMaxTemperature': <String, dynamic>{
          'degrees': 26.0 + i,
          'unit': 'CELSIUS',
        },
        'feelsLikeMinTemperature': <String, dynamic>{
          'degrees': 14.0 + i,
          'unit': 'CELSIUS',
        },
        'maxHeatIndex': <String, dynamic>{
          'degrees': 27.0 + i,
          'unit': 'CELSIUS',
        },
      };
    }),
  };
}

/// Returns an [ApiClient] whose `post` returns the hourly response for the
/// `forecast` path and the daily response for the `forecast/daily` path.
ApiClient buildApi({int hours = 6, int days = 7}) {
  final mock = MockClient((http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/forecast/daily')) {
      return http.Response(
        jsonEncode(dailyJson(days)),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    }
    return http.Response(
      jsonEncode(hourlyJson(hours)),
      200,
      headers: <String, String>{'content-type': 'application/json'},
    );
  });
  return ApiClient(client: mock, baseUrl: 'http://example.com/api');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GeolocatorPlatform.instance = FakeGeolocator();
  });

  Future<void> pumpHeatScreen(WidgetTester tester, {ApiClient? api}) async {
    await tester.pumpWidget(
      MaterialApp(home: HeatScreen(api: api ?? buildApi())),
    );
    // Let the async _load() complete.
    await tester.pumpAndSettle();
  }

  testWidgets('shows the hourly forecast by default', (tester) async {
    await pumpHeatScreen(tester);

    expect(find.text('Heat Data'), findsOneWidget);
    expect(find.text('Hourly Temperature Forecast'), findsOneWidget);
    expect(find.text('Hourly'), findsOneWidget);
    expect(find.text('Daily'), findsOneWidget);
    // Hourly legend series.
    expect(find.text('Temperature'), findsOneWidget);
    expect(find.text('Feels Like'), findsOneWidget);
    // UV chart (below the fold — scroll to it).
    await tester.scrollUntilVisible(
      find.text('Hourly UV Index'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Hourly UV Index'), findsOneWidget);
    // The UV chart's Y-axis name.
    expect(find.text('UV Index'), findsOneWidget);
  });

  testWidgets('toggling to daily shows the daily forecast', (tester) async {
    await pumpHeatScreen(tester);

    await tester.tap(find.text('Daily'));
    await tester.pumpAndSettle();

    expect(find.text('Daily Temperature Forecast'), findsOneWidget);
    expect(find.text('Hourly Temperature Forecast'), findsNothing);
    // Daily legend series.
    expect(find.text('Max Temp'), findsOneWidget);
    expect(find.text('Min Temp'), findsOneWidget);
    // UV chart (below the fold — scroll to it).
    await tester.scrollUntilVisible(
      find.text('Daily UV Index'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Daily UV Index'), findsOneWidget);
    expect(find.text('Hourly UV Index'), findsNothing);
  });

  testWidgets('toggling back to hourly restores the hourly view', (
    tester,
  ) async {
    await pumpHeatScreen(tester);

    await tester.tap(find.text('Daily'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hourly'));
    await tester.pumpAndSettle();

    expect(find.text('Hourly Temperature Forecast'), findsOneWidget);
    expect(find.text('Daily Temperature Forecast'), findsNothing);
  });

  testWidgets('shows an error when no forecast data is available', (
    tester,
  ) async {
    final mock = MockClient((http.Request request) async {
      return http.Response(
        jsonEncode(<String, dynamic>{}),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });
    final api = ApiClient(client: mock, baseUrl: 'http://example.com/api');

    await pumpHeatScreen(tester, api: api);

    expect(
      find.text('No forecast data is available for your location right now.'),
      findsOneWidget,
    );
  });

  testWidgets('tapping a spot pins the tooltip until tapping elsewhere', (
    tester,
  ) async {
    await pumpHeatScreen(tester);

    // The first hourly chart is the temperature chart. Tap near its center.
    final chart = find.byType(LineChart).first;
    expect(
      tester.widget<LineChart>(chart).data.showingTooltipIndicators,
      isEmpty,
    );

    await tester.tapAt(tester.getCenter(chart));
    await tester.pumpAndSettle();

    // A pinned tooltip appears and persists without holding.
    final pinnedData = tester.widget<LineChart>(chart).data;
    expect(pinnedData.showingTooltipIndicators, isNotEmpty);
    final pinnedSpots =
        pinnedData.showingTooltipIndicators.single.showingSpots;
    expect(pinnedSpots.length, greaterThanOrEqualTo(2)); // multiple series
    // The pinned index is respected on each bar's indicators.
    final pinnedIndex = pinnedSpots.first.spotIndex;
    for (final bar in pinnedData.lineBarsData) {
      expect(bar.showingIndicators, <int>[pinnedIndex]);
    }

    // Tapping elsewhere in the content (here, on the title) clears the
    // pinned tooltip.
    await tester.tapAt(tester.getCenter(find.text('Hourly Temperature Forecast')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<LineChart>(chart).data.showingTooltipIndicators,
      isEmpty,
    );
    for (final bar in tester.widget<LineChart>(chart).data.lineBarsData) {
      expect(bar.showingIndicators, isEmpty);
    }
  });

  testWidgets('tapping a spot on the UV chart pins its tooltip', (
    tester,
  ) async {
    await pumpHeatScreen(tester);

    // Scroll the UV chart into view.
    await tester.scrollUntilVisible(
      find.text('Hourly UV Index'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final uvChart = find.byType(LineChart).last;
    await tester.tapAt(tester.getCenter(uvChart));
    await tester.pumpAndSettle();

    final data = tester.widget<LineChart>(uvChart).data;
    expect(data.showingTooltipIndicators, isNotEmpty);
    final pinnedIndex = data.showingTooltipIndicators.single
        .showingSpots
        .first
        .spotIndex;
    expect(data.lineBarsData.single.showingIndicators, <int>[pinnedIndex]);
  });
}