import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nowcast/src/api/api_client.dart';
import 'package:nowcast/src/auth/auth_controller.dart';
import 'package:nowcast/src/models/health_profile.dart';
import 'package:nowcast/src/models/health_risk_assessment.dart';
import 'package:nowcast/src/services/health_profile_controller.dart';
import 'package:nowcast/src/services/health_risk_cache.dart';
import 'package:nowcast/src/widgets/health_risk_section.dart';

/// A minimal raw current-conditions payload (see API §5.1).
Map<String, dynamic> conditionsJson() {
  return <String, dynamic>{
    'temperature': <String, dynamic>{'degrees': 36.0, 'unit': 'CELSIUS'},
    'relativeHumidity': 70,
  };
}

/// A complete assessment payload as returned by `POST /api/ai/health-risk`.
Map<String, dynamic> assessmentJson() {
  return <String, dynamic>{
    'riskScore': 62,
    'riskLevel': 'very_high',
    'thresholdC': 38.0,
    'thresholdLabel': 'Clinical fever threshold',
    'summary': 'Heat strain is likely this afternoon.',
    'uncertainty': 'Humidity is forecast with moderate confidence.',
    'keyFindings': <String>['Peak risk is between 14:00 and 16:00.'],
    'recommendations': <String>['Avoid strenuous outdoor work at midday.'],
    'hourly': <Map<String, dynamic>>[
      <String, dynamic>{
        'hourIndex': 0,
        'hour': 12,
        'probability': 0.25,
        'coreTempMedianC': 37.4,
        'coreTempP10C': 37.1,
        'coreTempP90C': 37.8,
      },
      <String, dynamic>{
        'hourIndex': 1,
        'hour': 13,
        'probability': 0.55,
        'coreTempMedianC': 37.9,
        'coreTempP10C': 37.5,
        'coreTempP90C': 38.3,
      },
    ],
  };
}

/// A signed-in auth controller that never touches the network.
AuthController signedInAuth() {
  return AuthController(initialToken: 'test-token');
}

/// A profile controller backed by a fake API that always reports [profile].
HealthProfileController profileControllerWith(HealthProfile? profile) {
  final mock = MockClient((http.Request request) async {
    return http.Response(
      jsonEncode(<String, dynamic>{
        'profile': profile?.toJson(),
      }),
      200,
      headers: <String, String>{'content-type': 'application/json'},
    );
  });
  return HealthProfileController(
    api: ApiClient(client: mock, baseUrl: 'http://example.com/api'),
    auth: signedInAuth(),
  );
}

/// Records the bodies posted to the health-risk endpoint.
class RecordingApi {
  RecordingApi({this.response, this.statusCode = 200});

  final Map<String, dynamic>? response;
  final int statusCode;
  final List<Map<String, dynamic>> bodies = <Map<String, dynamic>>[];

  ApiClient build() {
    final mock = MockClient((http.Request request) async {
      if (request.body.isNotEmpty) {
        final decoded = jsonDecode(request.body);
        if (decoded is Map<String, dynamic>) bodies.add(decoded);
      }
      return http.Response(
        jsonEncode(response ?? assessmentJson()),
        statusCode,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });
    return ApiClient(client: mock, baseUrl: 'http://example.com/api');
  }
}

Widget wrap({
  required AuthController auth,
  required HealthProfileController profiles,
  required HealthRiskCache cache,
  ApiClient? api,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: HealthRiskSection(
          currentConditions: conditionsJson(),
          api: api,
          auth: auth,
          profileController: profiles,
          cache: cache,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('prompts a signed-out user to sign in', (tester) async {
    await tester.pumpWidget(
      wrap(
        auth: AuthController(initialToken: null),
        profiles: profileControllerWith(null),
        cache: HealthRiskCache(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Health risk'), findsOneWidget);
    expect(
      find.textContaining('combine your health details'),
      findsOneWidget,
    );
    expect(find.text('Generate assessment'), findsNothing);
  });

  testWidgets('prompts for health details when no profile exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        auth: signedInAuth(),
        profiles: profileControllerWith(null),
        cache: HealthRiskCache(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add health details'), findsOneWidget);
    expect(find.text('Generate assessment'), findsNothing);
  });

  testWidgets('offers to generate when a profile exists', (tester) async {
    await tester.pumpWidget(
      wrap(
        auth: signedInAuth(),
        profiles: profileControllerWith(
          const HealthProfile(age: 68, biologicalSex: 'female'),
        ),
        cache: HealthRiskCache(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Generate assessment'), findsOneWidget);
    // The saved profile is summarized above the button.
    expect(find.textContaining('68 years'), findsOneWidget);
  });

  testWidgets('generating renders the score, charts, and summary', (
    tester,
  ) async {
    final api = RecordingApi();

    await tester.pumpWidget(
      wrap(
        auth: signedInAuth(),
        profiles: profileControllerWith(
          const HealthProfile(age: 68, biologicalSex: 'female'),
        ),
        cache: HealthRiskCache(),
        api: api.build(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generate assessment'));
    await tester.pumpAndSettle();

    // Score and level.
    expect(find.text('62'), findsOneWidget);
    expect(find.text('Very high'), findsOneWidget);
    expect(find.textContaining('Clinical fever threshold'), findsWidgets);

    // Both charts.
    expect(find.byType(LineChart), findsNWidgets(2));

    // Written analysis.
    expect(
      find.text('Heat strain is likely this afternoon.'),
      findsOneWidget,
    );
    expect(
      find.text('Humidity is forecast with moderate confidence.'),
      findsOneWidget,
    );
    expect(find.text('Key findings'), findsOneWidget);
    expect(find.text('What to do'), findsOneWidget);

    // The generation date is shown.
    expect(find.textContaining('Generated'), findsOneWidget);
  });

  testWidgets('generating sends the weather payloads and the auth token', (
    tester,
  ) async {
    final api = RecordingApi();

    await tester.pumpWidget(
      wrap(
        auth: signedInAuth(),
        profiles: profileControllerWith(
          const HealthProfile(age: 68, biologicalSex: 'female'),
        ),
        cache: HealthRiskCache(),
        api: api.build(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generate assessment'));
    await tester.pumpAndSettle();

    expect(api.bodies, hasLength(1));
    expect(api.bodies.single['currentConditions'], isNotNull);
    // No previous assessment on the first run.
    expect(api.bodies.single.containsKey('previousAssessment'), isFalse);
  });

  testWidgets('regenerating sends the previous assessment as context', (
    tester,
  ) async {
    final api = RecordingApi();

    await tester.pumpWidget(
      wrap(
        auth: signedInAuth(),
        profiles: profileControllerWith(
          const HealthProfile(age: 68, biologicalSex: 'female'),
        ),
        cache: HealthRiskCache(),
        api: api.build(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generate assessment'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Update'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();

    expect(api.bodies, hasLength(2));
    final previous = api.bodies.last['previousAssessment'];
    expect(previous, isA<Map<String, dynamic>>());
    expect((previous as Map<String, dynamic>)['riskScore'], 62);
    expect(previous['generatedAt'], isNotNull);
  });

  testWidgets('a cached assessment is restored on mount', (tester) async {
    final cache = HealthRiskCache();
    await cache.write(HealthRiskAssessment.fromJson(assessmentJson()));

    await tester.pumpWidget(
      wrap(
        auth: signedInAuth(),
        profiles: profileControllerWith(
          const HealthProfile(age: 68, biologicalSex: 'female'),
        ),
        cache: cache,
      ),
    );
    await tester.pumpAndSettle();

    // The cached result renders without pressing generate.
    expect(find.text('62'), findsOneWidget);
    expect(find.text('Generate assessment'), findsNothing);
    expect(find.textContaining('Generated'), findsOneWidget);
  });

  testWidgets('clearing removes the assessment and the cache', (tester) async {
    final cache = HealthRiskCache();
    await cache.write(HealthRiskAssessment.fromJson(assessmentJson()));

    await tester.pumpWidget(
      wrap(
        auth: signedInAuth(),
        profiles: profileControllerWith(
          const HealthProfile(age: 68, biologicalSex: 'female'),
        ),
        cache: cache,
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Clear'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('62'), findsNothing);
    expect(find.text('Generate assessment'), findsOneWidget);
    expect(await cache.read(), isNull);
  });

  testWidgets('shows an inline error when generation fails', (tester) async {
    final api = RecordingApi(
      response: <String, dynamic>{'message': 'AI service is unavailable.'},
      statusCode: 502,
    );

    await tester.pumpWidget(
      wrap(
        auth: signedInAuth(),
        profiles: profileControllerWith(
          const HealthProfile(age: 68, biologicalSex: 'female'),
        ),
        cache: HealthRiskCache(),
        api: api.build(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generate assessment'));
    await tester.pumpAndSettle();

    expect(find.text('AI service is unavailable.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
