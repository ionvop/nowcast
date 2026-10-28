import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nowcast/src/services/notification_permission.dart';

/// Fake platform whose answers are scripted per test.
class _FakePermissionPlatform extends NotificationPermissionPlatform {
  _FakePermissionPlatform({
    this.supported = true,
    this.enabled = false,
    this.grantOnRequest = false,
  });

  final bool supported;
  bool enabled;
  bool grantOnRequest;

  int requestCount = 0;
  int openSettingsCount = 0;

  @override
  bool get isSupported => supported;

  @override
  Future<bool> areNotificationsEnabled() async => enabled;

  @override
  Future<bool> requestPermission() async {
    requestCount++;
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

  group('NotificationPermission.check', () {
    test('reports granted when the OS allows notifications', () async {
      final platform = _FakePermissionPlatform(enabled: true);
      final permission = NotificationPermission(platform: platform);

      expect(await permission.check(), NotificationPermissionStatus.granted);
    });

    test('reports denied before the user has ever been asked', () async {
      final platform = _FakePermissionPlatform();
      final permission = NotificationPermission(platform: platform);

      expect(await permission.check(), NotificationPermissionStatus.denied);
    });

    test('reports permanentlyDenied once a request has been recorded',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kNotificationPermissionRequestedKey: true,
      });
      final platform = _FakePermissionPlatform();
      final permission = NotificationPermission(platform: platform);

      expect(
        await permission.check(),
        NotificationPermissionStatus.permanentlyDenied,
      );
    });

    test('reports unsupported on platforms without a permission', () async {
      final platform = _FakePermissionPlatform(supported: false);
      final permission = NotificationPermission(platform: platform);

      expect(
        await permission.check(),
        NotificationPermissionStatus.unsupported,
      );
    });
  });

  group('NotificationPermission.request', () {
    test('returns granted and records the request when the user allows',
        () async {
      final platform = _FakePermissionPlatform(grantOnRequest: true);
      final permission = NotificationPermission(platform: platform);

      expect(await permission.request(), NotificationPermissionStatus.granted);
      expect(platform.requestCount, 1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kNotificationPermissionRequestedKey), isTrue);
    });

    test('returns denied on the first refusal', () async {
      final platform = _FakePermissionPlatform();
      final permission = NotificationPermission(platform: platform);

      expect(await permission.request(), NotificationPermissionStatus.denied);
    });

    test('returns permanentlyDenied on a later refusal', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kNotificationPermissionRequestedKey: true,
      });
      final platform = _FakePermissionPlatform();
      final permission = NotificationPermission(platform: platform);

      expect(
        await permission.request(),
        NotificationPermissionStatus.permanentlyDenied,
      );
    });

    test('does not prompt when notifications are already allowed', () async {
      final platform = _FakePermissionPlatform(enabled: true);
      final permission = NotificationPermission(platform: platform);

      expect(await permission.request(), NotificationPermissionStatus.granted);
      expect(platform.requestCount, 0);
    });

    test('does not prompt on unsupported platforms', () async {
      final platform = _FakePermissionPlatform(supported: false);
      final permission = NotificationPermission(platform: platform);

      expect(
        await permission.request(),
        NotificationPermissionStatus.unsupported,
      );
      expect(platform.requestCount, 0);
    });
  });

  test('openSettings delegates to the platform', () async {
    final platform = _FakePermissionPlatform();
    final permission = NotificationPermission(platform: platform);

    await permission.openSettings();

    expect(platform.openSettingsCount, 1);
  });
}
