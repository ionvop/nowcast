import 'weather.dart';

/// A single hour in the 6-hour forecast, as returned by the Google Weather
/// API (via the Laravel proxy). Parsed defensively.
class ForecastHour {
  const ForecastHour({
    required this.hour24,
    required this.condition,
    required this.temperatureC,
  });

  /// Hour of day in 24-hour format (0-23), from `displayDateTime.hours`.
  final int hour24;

  final WeatherCondition condition;

  /// Forecast temperature in degrees Celsius.
  final double? temperatureC;

  factory ForecastHour.fromJson(Map<String, dynamic> json) {
    final display = json['displayDateTime'];
    final condition = json['weatherCondition'];
    return ForecastHour(
      hour24: display is Map<String, dynamic> && display['hours'] is num
          ? (display['hours'] as num).toInt()
          : 0,
      condition: condition is Map<String, dynamic>
          ? WeatherCondition.fromJson(condition)
          : const WeatherCondition(iconBaseUri: '', description: ''),
      temperatureC: _degrees(json['temperature']),
    );
  }

  static double? _degrees(dynamic value) {
    if (value is Map<String, dynamic> && value['degrees'] is num) {
      return (value['degrees'] as num).toDouble();
    }
    return null;
  }
}

/// The full 6-hour forecast response.
class Forecast {
  const Forecast({required this.hours});

  final List<ForecastHour> hours;

  factory Forecast.fromJson(Map<String, dynamic> json) {
    final raw = json['forecastHours'];
    final list = raw is List ? raw : const <dynamic>[];
    return Forecast(
      hours: list
          .whereType<Map<String, dynamic>>()
          .map(ForecastHour.fromJson)
          .toList(),
    );
  }
}
