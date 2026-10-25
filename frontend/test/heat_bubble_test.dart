import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:nowcast/src/api/api_client.dart';
import 'package:nowcast/src/overlay/heat_bubble.dart';
import 'package:nowcast/src/theme/app_theme.dart';
import 'package:nowcast/src/utils/heat_color.dart';

/// A fake geolocator platform so `getPositionSilently()` works in tests.
class FakeGeolocator extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    return Future<Position>.value(_position);
  }

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => _position;

  static final Position _position = Position(
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
}

/// A minimal raw current-conditions payload (see API §5.1).
Map<String, dynamic> _weatherJson({
  required String iconBaseUri,
  double heatIndex = 33.0,
}) {
  return <String, dynamic>{
    'weatherCondition': <String, dynamic>{
      'iconBaseUri': iconBaseUri,
      'description': <String, dynamic>{'text': 'Sunny'},
      'type': 'CLEAR',
    },
    'temperature': <String, dynamic>{'degrees': 30.0, 'unit': 'CELSIUS'},
    'heatIndex': <String, dynamic>{'degrees': heatIndex, 'unit': 'CELSIUS'},
  };
}

const String _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
    '<circle cx="12" cy="12" r="10" fill="#FFCC00"/></svg>';

/// Serves `/weather` and `/weather/icon`, counting weather requests.
http.Client _mockClient({
  required Map<String, dynamic> weatherJson,
  int Function()? onWeather,
}) {
  return MockClient((http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/weather/icon')) {
      return http.Response(
        _svg,
        200,
        headers: <String, String>{'content-type': 'image/svg+xml'},
      );
    }
    if (path.endsWith('/weather')) {
      onWeather?.call();
      return http.Response(
        jsonEncode(weatherJson),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    }
    return http.Response('{"message":"Not found."}', 404);
  });
}

ApiClient _api(http.Client client) =>
    ApiClient(client: client, baseUrl: 'http://example.com/api');

/// Finds the bubble's outer decorated container.
Container _bubbleContainer(WidgetTester tester) {
  return tester.widget<Container>(
    find
        .descendant(
          of: find.byType(HeatBubble),
          matching: find.byType(Container),
        )
        .first,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GeolocatorPlatform.instance = FakeGeolocator();
  });

  testWidgets('falls back to the blue AI circle when weather fails', (
    tester,
  ) async {
    final client = MockClient((http.Request request) async {
      return http.Response('{"message":"Server error."}', 500);
    });

    await tester.pumpWidget(MaterialApp(home: HeatBubble(api: _api(client))));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    final decoration = _bubbleContainer(tester).decoration! as BoxDecoration;
    expect(decoration.color, AppTheme.seed);
  });

  testWidgets('shows the heat color and weather glyph on success', (
    tester,
  ) async {
    final client = _mockClient(
      weatherJson: _weatherJson(
        iconBaseUri: 'https://maps.gstatic.com/weather/v1/sunny_bubble_a',
        heatIndex: 33.0,
      ),
    );

    await tester.pumpWidget(MaterialApp(home: HeatBubble(api: _api(client))));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.auto_awesome), findsNothing);
    expect(find.byType(SvgPicture), findsOneWidget);

    final decoration = _bubbleContainer(tester).decoration! as BoxDecoration;
    expect(decoration.color, getHeatIndexColor(33.0));
    expect(decoration.shape, BoxShape.circle);
  });

  testWidgets('refreshes on the configured interval', (tester) async {
    var weatherRequests = 0;
    final client = _mockClient(
      weatherJson: _weatherJson(
        iconBaseUri: 'https://maps.gstatic.com/weather/v1/sunny_bubble_b',
      ),
      onWeather: () => weatherRequests++,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HeatBubble(
          api: _api(client),
          refreshInterval: const Duration(milliseconds: 100),
        ),
      ),
    );
    // Let the initial fetch complete without advancing past the interval.
    await tester.pump();
    await tester.pump();
    expect(weatherRequests, 1);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(weatherRequests, 2);

    // Stop the periodic timer before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('stays on the fallback when location is unavailable', (
    tester,
  ) async {
    var weatherRequests = 0;
    final client = _mockClient(
      weatherJson: _weatherJson(
        iconBaseUri: 'https://maps.gstatic.com/weather/v1/sunny_bubble_c',
      ),
      onWeather: () => weatherRequests++,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HeatBubble(api: _api(client), positionResolver: () async => null),
      ),
    );
    await tester.pumpAndSettle();

    expect(weatherRequests, 0);
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
  });
}
