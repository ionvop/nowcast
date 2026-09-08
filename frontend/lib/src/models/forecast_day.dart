import 'weather.dart';

/// A single day in the daily forecast, as returned by the Google Weather API
/// (via the Laravel proxy). Parsed defensively.
class ForecastDay {
  const ForecastDay({
    required this.date,
    required this.condition,
    this.maxTemperatureC,
    this.minTemperatureC,
    this.feelsLikeMaxC,
    this.feelsLikeMinC,
    this.maxHeatIndexC,
    this.precipitationPercent,
  });

  /// The calendar date this forecast applies to, from `displayDate`.
  final DateTime date;

  /// Daytime weather condition, from `daytimeForecast.weatherCondition`.
  final WeatherCondition condition;

  /// Forecast maximum temperature in degrees Celsius.
  final double? maxTemperatureC;

  /// Forecast minimum temperature in degrees Celsius.
  final double? minTemperatureC;

  /// Feels-like maximum temperature in degrees Celsius.
  final double? feelsLikeMaxC;

  /// Feels-like minimum temperature in degrees Celsius.
  final double? feelsLikeMinC;

  /// Maximum heat index in degrees Celsius.
  final double? maxHeatIndexC;

  /// Probability of precipitation as a percentage (0-100). Null when absent.
  final int? precipitationPercent;

  factory ForecastDay.fromJson(Map<String, dynamic> json) {
    final display = json['displayDate'];
    final daytime = json['daytimeForecast'];
    final condition = daytime is Map<String, dynamic>
        ? daytime['weatherCondition']
        : null;
    return ForecastDay(
      date: _date(display),
      condition: condition is Map<String, dynamic>
          ? WeatherCondition.fromJson(condition)
          : const WeatherCondition(iconBaseUri: '', description: ''),
      maxTemperatureC: _degrees(json['maxTemperature']),
      minTemperatureC: _degrees(json['minTemperature']),
      feelsLikeMaxC: _degrees(json['feelsLikeMaxTemperature']),
      feelsLikeMinC: _degrees(json['feelsLikeMinTemperature']),
      maxHeatIndexC: _degrees(json['maxHeatIndex']),
      precipitationPercent: _precipitationPercent(daytime),
    );
  }

  static DateTime _date(dynamic value) {
    if (value is Map<String, dynamic> &&
        value['year'] is num &&
        value['month'] is num &&
        value['day'] is num) {
      return DateTime(
        (value['year'] as num).toInt(),
        (value['month'] as num).toInt(),
        (value['day'] as num).toInt(),
      );
    }
    return DateTime(1970);
  }

  static double? _degrees(dynamic value) {
    if (value is Map<String, dynamic> && value['degrees'] is num) {
      return (value['degrees'] as num).toDouble();
    }
    return null;
  }

  static int? _precipitationPercent(dynamic daytime) {
    if (daytime is Map<String, dynamic>) {
      final precipitation = daytime['precipitation'];
      if (precipitation is Map<String, dynamic>) {
        final probability = precipitation['probability'];
        if (probability is Map<String, dynamic> &&
            probability['percent'] is num) {
          return (probability['percent'] as num).toInt();
        }
      }
    }
    return null;
  }
}

/// The full daily forecast response.
class DailyForecast {
  const DailyForecast({required this.days});

  final List<ForecastDay> days;

  factory DailyForecast.fromJson(Map<String, dynamic> json) {
    final raw = json['forecastDays'];
    final list = raw is List ? raw : const <dynamic>[];
    return DailyForecast(
      days: list
          .whereType<Map<String, dynamic>>()
          .map(ForecastDay.fromJson)
          .toList(),
    );
  }
}
