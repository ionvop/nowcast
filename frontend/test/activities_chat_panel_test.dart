import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:nowcast/src/api/api_client.dart';
import 'package:nowcast/src/overlay/activities_chat_panel.dart';

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

/// A minimal raw current-conditions payload (see API §5.1).
Map<String, dynamic> _conditionsJson() {
  return <String, dynamic>{
    'temperature': <String, dynamic>{'degrees': 18.0, 'unit': 'CELSIUS'},
    'weatherCondition': <String, dynamic>{
      'description': <String, dynamic>{'text': 'Partly cloudy'},
      'type': 'CLOUDY',
    },
  };
}

/// A canned §5.21 success response.
Map<String, dynamic> _suggestionsJson() {
  return <String, dynamic>{
    'suggestions': <Map<String, dynamic>>[
      <String, dynamic>{
        'name': 'Golden Gate Park',
        'category': 'outdoor',
        'description': 'A large urban park with gardens and trails.',
        'reason': 'Mild temperatures make a stroll comfortable.',
        'url': 'https://www.goldengatepark.org/',
      },
      <String, dynamic>{
        'name': 'SFMOMA',
        'category': 'cultural',
        'description': 'A modern art museum in downtown San Francisco.',
        'reason': 'Rain is expected, so an indoor activity fits.',
      },
    ],
  };
}

/// Mock client that serves the weather, geocode, and ai/activities endpoints.
http.Client _mockClient({
  required Map<String, dynamic> activitiesJson,
  void Function(Map<String, dynamic> body)? onActivities,
}) {
  return MockClient((http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/weather')) {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'currentConditions': _conditionsJson(),
          'hourlyForecast': <String, dynamic>{'forecastHours': <dynamic>[]},
          'dailyForecast': <String, dynamic>{'forecastDays': <dynamic>[]},
        }),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    }
    if (path.endsWith('/geocode')) {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'results': <Map<String, dynamic>>[
            <String, dynamic>{'formattedAddress': 'San Francisco'},
          ],
        }),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    }
    if (path.endsWith('/ai/activities')) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      onActivities?.call(body);
      return http.Response(
        jsonEncode(activitiesJson),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    }
    return http.Response('{"message":"Not found."}', 404);
  });
}

ApiClient _api(http.Client client) =>
    ApiClient(client: client, baseUrl: 'http://example.com/api');

Widget _wrap(ApiClient api) {
  return MaterialApp(
    home: Scaffold(
      body: ActivitiesChatPanel(
        onMinimize: () {},
        onClose: () {},
        api: api,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Stub the geolocator platform so `getPosition()` resolves instantly.
    GeolocatorPlatform.instance = FakeGeolocator();
  });

  group('ActivitySuggestion.fromJson', () {
    test('parses all fields', () {
      final s = ActivitySuggestion.fromJson(<String, dynamic>{
        'name': 'Park',
        'category': 'outdoor',
        'description': 'A park.',
        'reason': 'Nice weather.',
        'url': 'https://example.com',
      });
      expect(s.name, 'Park');
      expect(s.category, 'outdoor');
      expect(s.description, 'A park.');
      expect(s.reason, 'Nice weather.');
      expect(s.url, 'https://example.com');
    });

    test('defaults missing fields and omits url', () {
      final s = ActivitySuggestion.fromJson(<String, dynamic>{});
      expect(s.name, '');
      expect(s.category, 'other');
      expect(s.description, '');
      expect(s.reason, '');
      expect(s.url, isNull);
    });
  });

  group('ActivitiesChatPanel', () {
    testWidgets('renders suggestions from ai/activities', (tester) async {
      Map<String, dynamic>? requestBody;
      final client = _mockClient(
        activitiesJson: _suggestionsJson(),
        onActivities: (body) => requestBody = body,
      );

      await tester.pumpWidget(_wrap(_api(client)));
      await tester.pumpAndSettle();

      expect(requestBody, isNotNull);
      expect(requestBody!['currentConditions'], _conditionsJson());
      expect(requestBody!['latitude'], isNotNull);
      expect(requestBody!['longitude'], isNotNull);
      expect(requestBody!['placeName'], 'San Francisco');

      expect(find.text('Golden Gate Park'), findsOneWidget);
      expect(find.text('SFMOMA'), findsOneWidget);
      expect(find.text('outdoor'), findsOneWidget);
      expect(find.text('cultural'), findsOneWidget);
      expect(
        find.text('Mild temperatures make a stroll comfortable.'),
        findsOneWidget,
      );
      expect(find.text('Suggestions near San Francisco'), findsOneWidget);
    });

    testWidgets('shows retry UI on API failure', (tester) async {
      final failing = MockClient((http.Request request) async {
        final path = request.url.path;
        if (path.endsWith('/ai/activities')) {
          return http.Response('{"message":"Upstream error."}', 502);
        }
        if (path.endsWith('/weather')) {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'currentConditions': _conditionsJson(),
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response('{"message":"Not found."}', 404);
      });

      await tester.pumpWidget(_wrap(_api(failing)));
      await tester.pumpAndSettle();

      expect(find.text('Upstream error.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('shows empty message when no suggestions', (tester) async {
      final client = _mockClient(
        activitiesJson: <String, dynamic>{'suggestions': <dynamic>[]},
      );

      await tester.pumpWidget(_wrap(_api(client)));
      await tester.pumpAndSettle();

      expect(find.text('No suggestions right now.'), findsOneWidget);
    });
  });
}
