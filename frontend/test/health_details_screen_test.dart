import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nowcast/src/api/api_client.dart';
import 'package:nowcast/src/auth/auth_controller.dart';
import 'package:nowcast/src/models/health_profile.dart';
import 'package:nowcast/src/screens/health_details_screen.dart';
import 'package:nowcast/src/services/health_profile_controller.dart';

/// Records the bodies sent to `PUT /api/profile/health`.
class RecordingProfileApi {
  RecordingProfileApi({this.initialProfile, this.statusCode = 200});

  final HealthProfile? initialProfile;
  final int statusCode;
  final List<Map<String, dynamic>> puts = <Map<String, dynamic>>[];
  int deletes = 0;

  HealthProfileController build() {
    final mock = MockClient((http.Request request) async {
      if (request.method == 'DELETE') {
        deletes++;
        return http.Response(
          jsonEncode(<String, dynamic>{'message': 'Health profile deleted.'}),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      if (request.method == 'PUT') {
        final decoded = jsonDecode(request.body);
        if (decoded is Map<String, dynamic>) puts.add(decoded);
        return http.Response(
          jsonEncode(<String, dynamic>{'profile': decoded}),
          statusCode,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode(<String, dynamic>{'profile': initialProfile?.toJson()}),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    return HealthProfileController(
      api: ApiClient(client: mock, baseUrl: 'http://example.com/api'),
      auth: AuthController(initialToken: 'test-token'),
    );
  }
}

Widget wrap(HealthProfileController controller) {
  return MaterialApp(home: HealthDetailsScreen(controller: controller));
}

/// Gives the test a viewport tall enough to render the whole form.
///
/// The form is taller than the default 800x600 surface, so anything below the
/// fold would be disposed by the [ListView] and become untappable — including
/// the validation messages shown at the top after a failed save.
void useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Taps the save button.
Future<void> tapSave(WidgetTester tester) async {
  await tester.tap(find.text('Save details'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('requires an age before saving', (tester) async {
    useTallViewport(tester);
    final api = RecordingProfileApi();
    final controller = api.build();

    await tester.pumpWidget(wrap(controller));
    await tester.pumpAndSettle();

    await tapSave(tester);

    expect(find.text('Enter your age.'), findsOneWidget);
    expect(api.puts, isEmpty);
  });

  testWidgets('rejects an out-of-range age', (tester) async {
    useTallViewport(tester);
    final api = RecordingProfileApi();
    final controller = api.build();

    await tester.pumpWidget(wrap(controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '200');
    await tapSave(tester);

    expect(find.text('Enter an age between 1 and 120.'), findsOneWidget);
    expect(api.puts, isEmpty);
  });

  testWidgets('requires a biological sex before saving', (tester) async {
    useTallViewport(tester);
    final api = RecordingProfileApi();
    final controller = api.build();

    await tester.pumpWidget(wrap(controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '30');
    await tapSave(tester);

    expect(
      find.text('Select a biological sex to continue.'),
      findsOneWidget,
    );
    expect(api.puts, isEmpty);
  });

  testWidgets('saves the required fields and pops true', (tester) async {
    useTallViewport(tester);
    final api = RecordingProfileApi();
    final controller = api.build();

    bool? popped;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              popped = await Navigator.of(context).push<bool>(
                MaterialPageRoute<bool>(
                  builder: (_) => HealthDetailsScreen(controller: controller),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '68');
    await tester.tap(find.text('Female'));
    await tester.pumpAndSettle();

    await tapSave(tester);

    expect(api.puts, hasLength(1));
    expect(api.puts.single['age'], 68);
    expect(api.puts.single['biologicalSex'], 'female');
    expect(popped, isTrue);
  });

  testWidgets('saves selected conditions and lifestyle', (tester) async {
    useTallViewport(tester);
    final api = RecordingProfileApi();
    final controller = api.build();

    await tester.pumpWidget(wrap(controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '68');
    await tester.tap(find.text('Female'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cardiovascular disease'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Works outdoors'));
    await tester.pumpAndSettle();

    await tapSave(tester);

    expect(api.puts, hasLength(1));
    expect(api.puts.single['conditions'], <String>['cardiovascular']);
    expect(api.puts.single['lifestyle'], <String>['outdoor_worker']);
  });

  testWidgets('prefills the form from an existing profile', (tester) async {
    useTallViewport(tester);
    final api = RecordingProfileApi(
      initialProfile: const HealthProfile(
        age: 55,
        biologicalSex: 'other',
        heightCm: 170,
        weightKg: 68.5,
        activityLevel: 'moderate',
        conditions: <String>['kidney'],
      ),
    );
    final controller = api.build();
    await controller.load();

    await tester.pumpWidget(wrap(controller));
    await tester.pumpAndSettle();

    expect(find.text('55'), findsOneWidget);
    expect(find.text('170'), findsOneWidget);
    expect(find.text('68.5'), findsOneWidget);
    // The selected condition chip is rendered as selected.
    final chip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Kidney disease'),
    );
    expect(chip.selected, isTrue);
  });

  testWidgets('clearing asks for confirmation and deletes the profile', (
    tester,
  ) async {
    useTallViewport(tester);
    final api = RecordingProfileApi(
      initialProfile: const HealthProfile(age: 55, biologicalSex: 'male'),
    );
    final controller = api.build();
    await controller.load();

    await tester.pumpWidget(wrap(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Clear health details?'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(api.deletes, 1);
  });

  testWidgets('cancelling the clear dialog keeps the profile', (tester) async {
    useTallViewport(tester);
    final api = RecordingProfileApi(
      initialProfile: const HealthProfile(age: 55, biologicalSex: 'male'),
    );
    final controller = api.build();
    await controller.load();

    await tester.pumpWidget(wrap(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(api.deletes, 0);
  });

  testWidgets('reserves the system navigation bar inset', (tester) async {
    // This screen is a pushed route, so it must inset its own bottom edge;
    // otherwise the last field and the Save button sit under the system
    // navigation bar.
    useTallViewport(tester);
    tester.view.viewPadding = const FakeViewPadding(bottom: 34);
    tester.view.padding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.reset);

    final api = RecordingProfileApi();
    final controller = api.build();

    await tester.pumpWidget(wrap(controller));
    await tester.pumpAndSettle();

    final listRect = tester.getRect(find.byType(ListView));
    expect(
      listRect.bottom,
      moreOrLessEquals(2400 - 34, epsilon: 0.5),
      reason: 'The form must stop above the system navigation bar.',
    );
  });
}
