import 'package:flutter_test/flutter_test.dart';

import 'package:nowcast/src/models/weather.dart';
import 'package:nowcast/src/widgets/health_reminder_section.dart';

void main() {
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

  group('determineHealthReminder', () {
    test('flood risk when precipitation is very high', () {
      final reminder = determineHealthReminder(
        makeWeather(precipitationPercent: 85),
      );
      expect(reminder.title, 'Flood risk');
      expect(reminder.emoji, '🌊');
    });

    test('umbrella when precipitation is moderate', () {
      final reminder = determineHealthReminder(
        makeWeather(precipitationPercent: 50),
      );
      expect(reminder.title, 'Take an umbrella');
      expect(reminder.emoji, '☔');
    });

    test('SPF when UV index is high', () {
      final reminder = determineHealthReminder(makeWeather(uvIndex: 8));
      expect(reminder.title, 'Apply SPF');
      expect(reminder.emoji, '🧴');
    });

    test('stay cool when heat index is high', () {
      final reminder = determineHealthReminder(makeWeather(heatIndexC: 35));
      expect(reminder.title, 'Stay cool');
      expect(reminder.emoji, '🥵');
    });

    test('humidity note when humidity is high', () {
      final reminder = determineHealthReminder(makeWeather(relativeHumidity: 90));
      expect(reminder.title, 'Humid out there');
      expect(reminder.emoji, '💧');
    });

    test('rain takes priority over high UV', () {
      final reminder = determineHealthReminder(
        makeWeather(precipitationPercent: 60, uvIndex: 9),
      );
      expect(reminder.title, 'Take an umbrella');
    });

    test('neutral reminder when weather is null', () {
      final reminder = determineHealthReminder(null);
      expect(reminder.title, 'Enjoy the weather');
    });

    test('neutral reminder when no thresholds are met', () {
      final reminder = determineHealthReminder(
        makeWeather(
          precipitationPercent: 10,
          uvIndex: 2,
          heatIndexC: 25,
          relativeHumidity: 50,
        ),
      );
      expect(reminder.title, 'Enjoy the weather');
    });
  });
}