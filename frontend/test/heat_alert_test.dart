import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nowcast/src/models/weather.dart';
import 'package:nowcast/src/services/heat_alert_controller.dart';
import 'package:nowcast/src/services/heat_alert_service.dart';
import 'package:nowcast/src/widgets/health_reminder_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('determineHeatAlertStatus', () {
    const threshold = 32.0;

    test('danger when current heat index exceeds the threshold', () {
      expect(
        determineHeatAlertStatus(
          currentHeatIndexC: 33.5,
          forecastHeatIndexesC: const <double?>[30, 31],
          thresholdC: threshold,
        ),
        HeatAlertStatus.danger,
      );
    });

    test('warning when only the forecast exceeds the threshold', () {
      expect(
        determineHeatAlertStatus(
          currentHeatIndexC: 30,
          forecastHeatIndexesC: const <double?>[29, 34, 31],
          thresholdC: threshold,
        ),
        HeatAlertStatus.warning,
      );
    });

    test('safe when nothing exceeds the threshold', () {
      expect(
        determineHeatAlertStatus(
          currentHeatIndexC: 28,
          forecastHeatIndexesC: const <double?>[29, 31, 30],
          thresholdC: threshold,
        ),
        HeatAlertStatus.safe,
      );
    });

    test('safe when equal to the threshold (strictly greater required)', () {
      expect(
        determineHeatAlertStatus(
          currentHeatIndexC: 32,
          forecastHeatIndexesC: const <double?>[32],
          thresholdC: threshold,
        ),
        HeatAlertStatus.safe,
      );
    });

    test('safe when readings are null or the forecast is empty', () {
      expect(
        determineHeatAlertStatus(
          currentHeatIndexC: null,
          forecastHeatIndexesC: const <double?>[],
          thresholdC: threshold,
        ),
        HeatAlertStatus.safe,
      );
    });

    test('safe when only null forecast entries exist', () {
      expect(
        determineHeatAlertStatus(
          currentHeatIndexC: 25,
          forecastHeatIndexesC: const <double?>[null, null],
          thresholdC: threshold,
        ),
        HeatAlertStatus.safe,
      );
    });
  });

  group('HeatAlertController persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    // Use a controller with the native service disabled so tests don't touch
    // the platform background-service bridge.
    HeatAlertController makeController() =>
        HeatAlertController(nativeServiceAvailable: false);

    test('defaults to disabled with the default threshold', () {
      final controller = HeatAlertController(nativeServiceAvailable: false);
      expect(controller.isEnabled, isFalse);
      expect(controller.threshold, kDefaultHeatAlertThreshold);
      expect(controller.isInitialized, isFalse);
    });

    test('persists enabled and threshold and restores them on init', () async {
      final controller = makeController();

      await controller.setThreshold(35);
      await controller.enable();

      expect(controller.isEnabled, isTrue);
      expect(controller.threshold, 35);

      // A fresh controller (simulating a new app launch) restores the state.
      final restored = makeController();
      expect(restored.isEnabled, isFalse);
      await restored.init();
      expect(restored.isEnabled, isTrue);
      expect(restored.threshold, 35);
    });

    test('disable turns alerts off and persists it', () async {
      final controller = makeController();
      await controller.enable();
      await controller.disable();

      expect(controller.isEnabled, isFalse);

      final restored = makeController();
      await restored.init();
      expect(restored.isEnabled, isFalse);
    });

    test('setThreshold does nothing when value is unchanged', () async {
      final controller = makeController();
      var notified = 0;
      controller.addListener(() => notified++);

      await controller.setThreshold(controller.threshold);
      expect(notified, 0);
    });
  });

  group('HealthReminder.isNeutral', () {
    Weather makeWeather({
      int? precipitationPercent,
      int? uvIndex,
      double? heatIndexC,
      int? relativeHumidity,
    }) {
      return Weather(
        condition: const WeatherCondition(iconBaseUri: '', description: ''),
        temperatureC: 20,
        feelsLikeC: 20,
        heatIndexC: heatIndexC,
        uvIndex: uvIndex,
        precipitationPercent: precipitationPercent,
        relativeHumidity: relativeHumidity,
        conditionType: '',
      );
    }

    test('neutral when conditions are pleasant', () {
      final reminder = determineHealthReminder(makeWeather());
      expect(reminder.isNeutral, isTrue);
      expect(reminder.title, 'Enjoy the weather');
    });

    test('not neutral when a real reminder applies', () {
      final reminder = determineHealthReminder(
        makeWeather(precipitationPercent: 85),
      );
      expect(reminder.isNeutral, isFalse);
      expect(reminder.title, 'Flood risk');
    });
  });

  group('check interval selection', () {
    test('production interval is 15 minutes', () {
      expect(kHeatAlertCheckInterval, const Duration(minutes: 15));
    });

    test('test interval is 15 seconds', () {
      expect(kTestHeatAlertCheckInterval, const Duration(seconds: 15));
    });
  });
}
