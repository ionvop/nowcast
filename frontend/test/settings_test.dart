import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nowcast/src/services/settings_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsController time-format default', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('defaults to 12-hour when no preference is stored', () async {
      final controller = SettingsController();
      await controller.init();
      expect(controller.is24Hour, isFalse);
    });

    test('applies the device default when no preference is stored', () async {
      final controller = SettingsController();
      await controller.init();
      controller.applyDeviceDefault(true);
      expect(controller.is24Hour, isTrue);
    });

    test('device default is a no-op once a preference is stored', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        k24HourKey: false,
      });
      final controller = SettingsController();
      await controller.init();
      // Even though the device uses 24-hour format, the stored 12-hour
      // preference must win.
      controller.applyDeviceDefault(true);
      expect(controller.is24Hour, isFalse);
    });

    test('device default is applied only once', () async {
      final controller = SettingsController();
      await controller.init();
      controller.applyDeviceDefault(true);
      controller.applyDeviceDefault(false);
      // The first application wins; later calls are ignored.
      expect(controller.is24Hour, isTrue);
    });

    test('set24Hour persists and init restores the stored value', () async {
      final controller = SettingsController();
      await controller.init();
      await controller.set24Hour(true);
      expect(controller.is24Hour, isTrue);

      // A fresh controller restores the persisted preference.
      final restored = SettingsController();
      await restored.init();
      expect(restored.is24Hour, isTrue);
      // A stored preference means the device default is ignored.
      restored.applyDeviceDefault(false);
      expect(restored.is24Hour, isTrue);
    });
  });
}
