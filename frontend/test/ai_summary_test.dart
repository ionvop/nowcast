import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:nowcast/src/api/api_client.dart';
import 'package:nowcast/src/models/ai_summary.dart';
import 'package:nowcast/src/widgets/ai_summary_section.dart';

/// A minimal raw current-conditions payload (see API §5.1).
Map<String, dynamic> _conditionsJson() {
  return <String, dynamic>{
    'temperature': <String, dynamic>{'degrees': 33.0, 'unit': 'CELSIUS'},
    'feelsLikeTemperature': <String, dynamic>{
      'degrees': 38.0,
      'unit': 'CELSIUS',
    },
    'heatIndex': <String, dynamic>{'degrees': 41.0, 'unit': 'CELSIUS'},
    'relativeHumidity': 70,
    'weatherCondition': <String, dynamic>{
      'description': <String, dynamic>{'text': 'Sunny', 'languageCode': 'en'},
      'type': 'CLEAR',
    },
  };
}

/// A raw hourly forecast payload.
Map<String, dynamic> _hourlyJson() {
  return <String, dynamic>{
    'forecastHours': <Map<String, dynamic>>[
      <String, dynamic>{
        'weatherCondition': <String, dynamic>{
          'description': <String, dynamic>{
            'text': 'Sunny',
            'languageCode': 'en',
          },
          'type': 'CLEAR',
        },
      },
    ],
  };
}

/// A raw daily forecast payload.
Map<String, dynamic> _dailyJson() {
  return <String, dynamic>{
    'forecastDays': <Map<String, dynamic>>[
      <String, dynamic>{
        'daytimeForecast': <String, dynamic>{
          'weatherCondition': <String, dynamic>{
            'description': <String, dynamic>{
              'text': 'Partly sunny',
              'languageCode': 'en',
            },
            'type': 'PARTLY_CLOUDY',
          },
        },
      },
    ],
  };
}

/// Builds an [ApiClient] whose `ai/summary` POST returns [summaryJson].
ApiClient _buildApi(Map<String, dynamic> summaryJson) {
  final mock = MockClient((http.Request request) async {
    if (request.url.path.endsWith('/ai/summary')) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      // Verify the section forwards the raw payloads.
      expect(body['currentConditions'], _conditionsJson());
      expect(body['hourlyForecast'], _hourlyJson());
      expect(body['dailyForecast'], _dailyJson());
      return http.Response(
        jsonEncode(summaryJson),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    }
    return http.Response('{"message":"Not found."}', 404);
  });
  return ApiClient(client: mock, baseUrl: 'http://example.com/api');
}

/// Builds an [ApiClient] whose `ai/summary` POST fails with [status].
ApiClient _buildFailingApi({int status = 502}) {
  final mock = MockClient((http.Request request) async {
    if (request.url.path.endsWith('/ai/summary')) {
      return http.Response('{"message":"Upstream error."}', status);
    }
    return http.Response('{"message":"Not found."}', 404);
  });
  return ApiClient(client: mock, baseUrl: 'http://example.com/api');
}

Widget _wrap({required ApiClient api}) {
  return MaterialApp(
    home: Scaffold(
      body: AiSummarySection(
        currentConditions: _conditionsJson(),
        hourlyForecast: _hourlyJson(),
        dailyForecast: _dailyJson(),
        api: api,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiSummary.fromJson', () {
    test('parses all three fields', () {
      final summary = AiSummary.fromJson(<String, dynamic>{
        'summary': 'Hot and humid.',
        'healthAdvice': 'Stay hydrated.',
        'articleUrl': 'https://example.com/article',
      });
      expect(summary.summary, 'Hot and humid.');
      expect(summary.healthAdvice, 'Stay hydrated.');
      expect(summary.articleUrl, 'https://example.com/article');
    });

    test('defaults missing or non-string fields to empty strings', () {
      final summary = AiSummary.fromJson(<String, dynamic>{
        'summary': 42,
        'healthAdvice': null,
      });
      expect(summary.summary, '');
      expect(summary.healthAdvice, '');
      expect(summary.articleUrl, '');
    });
  });

  group('AiSummarySection', () {
    testWidgets('renders summary, advice, and article link on success',
        (tester) async {
      final api = _buildApi(<String, dynamic>{
        'summary': 'Hot and humid with a heat index of 41°C.',
        'healthAdvice': 'Limit strenuous activity and drink water.',
        'articleUrl': 'https://www.cdc.gov/heat/index.html',
      });

      await tester.pumpWidget(_wrap(api: api));
      expect(find.text('AI summary'), findsOneWidget);
      // Loading indicator while the request is in flight.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(
        find.text('Hot and humid with a heat index of 41°C.'),
        findsOneWidget,
      );
      expect(
        find.text('Limit strenuous activity and drink water.'),
        findsOneWidget,
      );
      expect(find.text('Recommended reading'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows a fallback message when the response is empty',
        (tester) async {
      final api = _buildApi(<String, dynamic>{});

      await tester.pumpWidget(_wrap(api: api));
      await tester.pumpAndSettle();

      expect(
        find.text('The AI summary is unavailable right now.'),
        findsOneWidget,
      );
      expect(find.text('Recommended reading'), findsNothing);
    });

    testWidgets('shows a compact error with retry on failure', (tester) async {
      final api = _buildFailingApi(status: 502);

      await tester.pumpWidget(_wrap(api: api));
      await tester.pumpAndSettle();

      expect(find.text('Upstream error.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      // Health reminder / other content is unaffected (no full-page error).
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('retry recovers after a transient failure', (tester) async {
      var calls = 0;
      final mock = MockClient((http.Request request) async {
        if (!request.url.path.endsWith('/ai/summary')) {
          return http.Response('{"message":"Not found."}', 404);
        }
        calls++;
        if (calls == 1) {
          return http.Response('{"message":"Upstream error."}', 502);
        }
        return http.Response(
          jsonEncode(<String, dynamic>{
            'summary': 'Clearing skies.',
            'healthAdvice': 'Enjoy the day.',
            'articleUrl': 'https://example.com/article',
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      await tester.pumpWidget(
        _wrap(api: ApiClient(client: mock, baseUrl: 'http://example.com/api')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Clearing skies.'), findsOneWidget);
      expect(find.text('Enjoy the day.'), findsOneWidget);
      expect(find.text('Recommended reading'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });
  });
}