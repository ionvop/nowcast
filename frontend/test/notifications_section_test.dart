import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nowcast/src/services/heat_alert_controller.dart';
import 'package:nowcast/src/widgets/notifications_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpSection(
    WidgetTester tester,
    HeatAlertController controller,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationsSection(controller: controller),
        ),
      ),
    );
  }

  testWidgets('hides sub-toggles while the master toggle is off',
      (WidgetTester tester) async {
    final controller = HeatAlertController(nativeServiceAvailable: false);
    await pumpSection(tester, controller);

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Heat alert'), findsNothing);
    expect(find.text('Health reminder'), findsNothing);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('reveals both sub-toggles when the master toggle is on',
      (WidgetTester tester) async {
    final controller = HeatAlertController(nativeServiceAvailable: false);
    await controller.enableNotifications();
    await pumpSection(tester, controller);

    expect(find.text('Heat alert'), findsOneWidget);
    expect(find.text('Health reminder'), findsOneWidget);
    // The threshold slider shows because the heat-alert sub-toggle defaults on.
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('hides the threshold slider when the heat-alert sub-toggle is off',
      (WidgetTester tester) async {
    final controller = HeatAlertController(nativeServiceAvailable: false);
    await controller.enableNotifications();
    await controller.setHeatAlertEnabled(false);
    await pumpSection(tester, controller);

    expect(find.text('Heat alert'), findsOneWidget);
    expect(find.text('Health reminder'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('tapping the master switch enables notifications',
      (WidgetTester tester) async {
    final controller = HeatAlertController(nativeServiceAvailable: false);
    await pumpSection(tester, controller);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(controller.isNotificationsEnabled, isTrue);
    expect(find.text('Heat alert'), findsOneWidget);
    expect(find.text('Health reminder'), findsOneWidget);
  });
}
