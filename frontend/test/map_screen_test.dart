import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import 'package:nowcast/src/api/api_client.dart';
import 'package:nowcast/src/models/weather.dart';
import 'package:nowcast/src/screens/map_screen.dart';
import 'package:nowcast/src/widgets/heat_marker.dart';

const String _svg = '''
<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
  <circle cx="50" cy="50" r="40" fill="orange"/>
</svg>
''';

/// A fake HTTP client that serves the weather-icon SVG for any request.
class _FakeIconClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<Uint8List>.value(Uint8List.fromList(utf8.encode(_svg))),
      200,
      headers: <String, String>{'content-type': 'image/svg+xml'},
    );
  }
}

Weather _weather({String description = '', int? precipitation}) {
  return Weather(
    condition: WeatherCondition(
      iconBaseUri: 'https://maps.gstatic.com/weather/v1/sunny',
      description: description,
    ),
    temperatureC: 30,
    feelsLikeC: 32,
    heatIndexC: 35,
    precipitationPercent: precipitation,
    relativeHumidity: 50,
  );
}

void main() {
  group('buildInfoSnippet', () {
    test('includes weather description and precipitation when available', () {
      final snippet = buildInfoSnippet(
        DateTime(2026, 9, 8, 12, 0),
        _weather(description: 'Partly cloudy', precipitation: 45),
      );
      expect(snippet, contains('Weather: Partly cloudy'));
      expect(snippet, contains('Precipitation: 45%'));
    });

    test('omits precipitation when not reported', () {
      final snippet = buildInfoSnippet(
        DateTime(2026, 9, 8, 12, 0),
        _weather(description: 'Clear', precipitation: null),
      );
      expect(snippet, contains('Weather: Clear'));
      expect(snippet, isNot(contains('Precipitation')));
    });

    test('falls back to Unknown time when createdAt is null', () {
      final snippet = buildInfoSnippet(null, null);
      expect(snippet, contains('Unknown time'));
      expect(snippet, isNot(contains('Weather:')));
      expect(snippet, isNot(contains('Precipitation')));
    });
  });

  group('buildHeatMarkerWithIcon', () {
    test('decodes an SVG picture and builds a marker bitmap in one step',
        () async {
      final api = ApiClient(client: _FakeIconClient());
      final bytes = await api.getBytes(
        'weather/icon',
        query: <String, String>{
          'iconBaseUri': 'https://maps.gstatic.com/weather/v1/sunny.svg',
        },
      );
      final loader = SvgBytesLoader(bytes);
      final info = await vg.loadPicture(loader, null, clipViewbox: true);

      final descriptor = await buildHeatMarkerWithIcon(
        const ui.Color(0xFF4CAF50),
        weatherIcon: info.picture,
        iconSize: info.size,
      );

      // Rasterized into a bytes-backed bitmap (not the default pin).
      expect(descriptor, isNot(equals(BitmapDescriptor.defaultMarker)));
    });
  });
}