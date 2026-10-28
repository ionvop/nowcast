import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nowcast/src/services/heat_alert_controller.dart';
import 'package:nowcast/src/services/notification_permission.dart';
import 'package:nowcast/src/widgets/notifications_section.dart';

/// Permission platform whose answers are scripted per test.
class _FakePermissionPlatform extends NotificationPermissionPlatform {
  _FakePermissionPlatform({this.enabled = false, this.grantOnRequest = false});

  bool enabled;
  bool grantOnRequest;
  int openSettingsCount = 0;

  @override
  bool get isSupported => true;

  @override
  Future<bool> areNotificationsEnabled() async => enabled;

  @override
  Future<bool> requestPermission() async {
    if (grantOnRequest) enabled = true;
    return grantOnRequest;
  }

  @override
  Future<void> openSettings() async {
    openSettingsCount++;
  }
}

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

  testWidgets('tapping the master switch requests the OS permission',
      (WidgetTester tester) async {
    final platform = _FakePermissionPlatform(grantOnRequest: true);
    final controller = HeatAlertController(
      nativeServiceAvailable: false,
      notificationPermission: NotificationPermission(platform: platform),
    );
    await pumpSection(tester, controller);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(platform.enabled, isTrue);
    expect(controller.isNotificationsEnabled, isTrue);
  });

  testWidgets('reverts the toggle and offers settings when permission is denied',
      (WidgetTester tester) async {
    final platform = _FakePermissionPlatform();
    final controller = HeatAlertController(
      nativeServiceAvailable: false,
      notificationPermission: NotificationPermission(platform: platform),
    );
    await pumpSection(tester, controller);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(controller.isNotificationsEnabled, isFalse);
    expect(find.text('Heat alert'), findsNothing);
    expect(find.textContaining('Notifications are blocked'), findsOneWidget);

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    expect(platform.openSettingsCount, 1);
  });

  testWidgets('shows the blocked warning when enabled but blocked by the OS',
      (WidgetTester tester) async {
    final platform = _FakePermissionPlatform(enabled: true);
    final controller = HeatAlertController(
      nativeServiceAvailable: false,
      notificationPermission: NotificationPermission(platform: platform),
    );
    await controller.enableNotifications();
    // Simulate the user revoking the permission in the system settings.
    platform.enabled = false;
    await controller.refreshPermissionState();
    await pumpSection(tester, controller);

    expect(controller.areNotificationsBlocked, isTrue);
    expect(find.text('Notifications are blocked'), findsOneWidget);
  });
}
