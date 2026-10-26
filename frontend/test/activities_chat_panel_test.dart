import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:nowcast/src/api/api_client.dart';
import 'package:nowcast/src/overlay/activities_chat_panel.dart';

/// A fake geolocator platform so `getPositionSilently()` works in widget tests.
class FakeGeolocator extends GeolocatorPlatform {
  FakeGeolocator({this.permission = LocationPermission.whileInUse});

  /// The permission reported by [checkPermission]. Set to
  /// [LocationPermission.denied] to simulate a location that cannot be
  /// resolved without prompting.
  final LocationPermission permission;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

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

/// The raw hourly forecast payload (API §5.2).
Map<String, dynamic> _hourlyJson() {
  return <String, dynamic>{
    'forecastHours': <Map<String, dynamic>>[
      <String, dynamic>{'interval': <String, dynamic>{'startTime': 'now'}},
    ],
  };
}

/// The raw daily forecast payload (API §5.3).
Map<String, dynamic> _dailyJson() {
  return <String, dynamic>{
    'forecastDays': <Map<String, dynamic>>[
      <String, dynamic>{'displayDate': <String, dynamic>{'year': 2026}},
    ],
  };
}

/// Mock client that serves the weather, forecast, geocode, and ai/activities
/// endpoints.
///
/// `/weather` returns the **raw Google current-conditions object** at the top
/// level, exactly like the real API (§5.1). Returning a `currentConditions`
/// wrapper here would hide the payload-shape bug this suite guards against.
http.Client _mockClient({
  required Map<String, dynamic> activitiesJson,
  void Function(Map<String, dynamic> body)? onActivities,
}) {
  return MockClient((http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/weather')) {
      return http.Response(
        jsonEncode(_conditionsJson()),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    }
    if (path.endsWith('/forecast/daily')) {
      return http.Response(
        jsonEncode(_dailyJson()),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    }
    if (path.endsWith('/forecast')) {
      return http.Response(
        jsonEncode(_hourlyJson()),
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

Widget _wrap(
  ApiClient api, {
  Duration? loadTimeout,
  ActivitiesSuggestionsController? controller,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ActivitiesChatPanel(
        onMinimize: () {},
        onClose: () {},
        api: api,
        controller: controller,
        loadTimeout: loadTimeout ?? ActivitiesChatPanel.defaultLoadTimeout,
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
      // The whole raw /weather payload is forwarded as `currentConditions`
      // (API §5.1) — not a nested `currentConditions` key, which never exists.
      expect(requestBody!['currentConditions'], _conditionsJson());
      expect(requestBody!['hourlyForecast'], _hourlyJson());
      expect(requestBody!['dailyForecast'], _dailyJson());
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
            jsonEncode(_conditionsJson()),
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

    testWidgets('times out after the deadline and offers a retry',
        (tester) async {
      // A client whose ai/activities call never completes.
      final hanging = MockClient((http.Request request) async {
        final path = request.url.path;
        if (path.endsWith('/ai/activities')) {
          return Completer<http.Response>().future;
        }
        if (path.endsWith('/weather')) {
          return http.Response(
            jsonEncode(_conditionsJson()),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response('{"message":"Not found."}', 404);
      });

      await tester.pumpWidget(
        _wrap(_api(hanging), loadTimeout: const Duration(seconds: 30)),
      );
      await tester.pump();

      // Still loading before the deadline.
      expect(find.text('Finding things to do near you…'), findsOneWidget);

      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();

      expect(
        find.text('This is taking longer than expected. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Finding things to do near you…'), findsNothing);
    });

    testWidgets('shows a retryable error when location is unavailable',
        (tester) async {
      // Permission denied → getPositionSilently() returns null.
      GeolocatorPlatform.instance =
          FakeGeolocator(permission: LocationPermission.denied);

      var activitiesCalls = 0;
      final client = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/ai/activities')) {
          activitiesCalls++;
        }
        return http.Response('{"message":"Not found."}', 404);
      });

      await tester.pumpWidget(_wrap(_api(client)));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Could not determine your location'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      // No AI request is attempted without a location.
      expect(activitiesCalls, 0);
    });

    testWidgets('retry after a timeout loads the suggestions', (tester) async {
      var attempts = 0;
      final flaky = MockClient((http.Request request) async {
        final path = request.url.path;
        if (path.endsWith('/ai/activities')) {
          attempts++;
          if (attempts == 1) return Completer<http.Response>().future;
          return http.Response(
            jsonEncode(_suggestionsJson()),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        if (path.endsWith('/weather')) {
          return http.Response(
            jsonEncode(_conditionsJson()),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        if (path.endsWith('/forecast/daily')) {
          return http.Response(
            jsonEncode(_dailyJson()),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        if (path.endsWith('/forecast')) {
          return http.Response(
            jsonEncode(_hourlyJson()),
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
        return http.Response('{"message":"Not found."}', 404);
      });

      await tester.pumpWidget(
        _wrap(_api(flaky), loadTimeout: const Duration(seconds: 30)),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Golden Gate Park'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('does not refetch when the panel is re-expanded',
        (tester) async {
      var activitiesCalls = 0;
      final client = _mockClient(
        activitiesJson: _suggestionsJson(),
        onActivities: (_) => activitiesCalls++,
      );
      final controller = ActivitiesSuggestionsController(api: _api(client));
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrap(_api(client), controller: controller));
      await tester.pumpAndSettle();
      expect(activitiesCalls, 1);
      expect(find.text('Golden Gate Park'), findsOneWidget);

      // Collapse: the overlay host swaps the panel for the bubble, which
      // destroys the panel's State but keeps the controller.
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      // Re-expand with the same controller: results are reused, no refetch.
      await tester.pumpWidget(_wrap(_api(client), controller: controller));
      await tester.pumpAndSettle();

      expect(activitiesCalls, 1);
      expect(find.text('Golden Gate Park'), findsOneWidget);
      expect(find.text('Suggestions near San Francisco'), findsOneWidget);
    });

    testWidgets('does not refetch while a fetch is still running',
        (tester) async {
      var activitiesCalls = 0;
      final hanging = MockClient((http.Request request) async {
        final path = request.url.path;
        if (path.endsWith('/ai/activities')) {
          activitiesCalls++;
          return Completer<http.Response>().future;
        }
        if (path.endsWith('/weather')) {
          return http.Response(
            jsonEncode(_conditionsJson()),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response('{"message":"Not found."}', 404);
      });
      final controller = ActivitiesSuggestionsController(api: _api(hanging));
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrap(_api(hanging), controller: controller));
      await tester.pump();
      expect(activitiesCalls, 1);

      // Collapse and re-expand while the first attempt is still in flight.
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();
      await tester.pumpWidget(_wrap(_api(hanging), controller: controller));
      await tester.pump();

      expect(activitiesCalls, 1);
      expect(find.text('Finding things to do near you…'), findsOneWidget);

      // Let the in-flight attempt time out so no timers are left pending.
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
    });

    testWidgets('regenerate keeps the old list and then replaces it',
        (tester) async {
      var activitiesCalls = 0;
      final second = Completer<http.Response>();
      final client = MockClient((http.Request request) async {
        final path = request.url.path;
        if (path.endsWith('/ai/activities')) {
          activitiesCalls++;
          if (activitiesCalls == 1) {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'suggestions': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'name': 'Golden Gate Park',
                    'category': 'outdoor',
                    'description': 'A park.',
                    'reason': 'Nice weather.',
                  },
                ],
              }),
              200,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }
          return second.future;
        }
        if (path.endsWith('/weather')) {
          return http.Response(
            jsonEncode(_conditionsJson()),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response('{"message":"Not found."}', 404);
      });

      await tester.pumpWidget(_wrap(_api(client)));
      await tester.pumpAndSettle();
      expect(find.text('Golden Gate Park'), findsOneWidget);

      await tester.tap(find.text('Regenerate'));
      await tester.pump();

      // The previous list stays visible while the new attempt runs.
      expect(find.text('Golden Gate Park'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Finding things to do near you…'), findsNothing);

      second.complete(
        http.Response(
          jsonEncode(<String, dynamic>{
            'suggestions': <Map<String, dynamic>>[
              <String, dynamic>{
                'name': 'Dolores Park',
                'category': 'outdoor',
                'description': 'A park.',
                'reason': 'Nice weather.',
              },
            ],
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        ),
      );
      await tester.pumpAndSettle();

      expect(activitiesCalls, 2);
      expect(find.text('Dolores Park'), findsOneWidget);
      expect(find.text('Golden Gate Park'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('offers regenerate when there are no suggestions',
        (tester) async {
      var activitiesCalls = 0;
      final client = _mockClient(
        activitiesJson: <String, dynamic>{'suggestions': <dynamic>[]},
        onActivities: (_) => activitiesCalls++,
      );

      await tester.pumpWidget(_wrap(_api(client)));
      await tester.pumpAndSettle();

      expect(find.text('No suggestions right now.'), findsOneWidget);
      expect(find.text('Regenerate'), findsOneWidget);

      await tester.tap(find.text('Regenerate'));
      await tester.pumpAndSettle();

      expect(activitiesCalls, 2);
    });
  });
}
