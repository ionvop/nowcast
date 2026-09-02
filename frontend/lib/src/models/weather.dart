/// A weather condition as returned by the Google Weather API (via the
/// Laravel proxy). Parsed defensively because the raw payload may vary.
class WeatherCondition {
  const WeatherCondition({required this.iconBaseUri, required this.description});

  /// Base URI for the weather icon, e.g. `https://maps.gstatic.com/weather/v1/sunny`.
  /// Append `.svg` (or `_dark.svg`) to build the full icon URL.
  final String iconBaseUri;

  /// Human-readable condition text, e.g. "Sunny".
  final String description;

  factory WeatherCondition.fromJson(Map<String, dynamic> json) {
    final iconBaseUri = json['iconBaseUri'];
    final description = json['description'];
    return WeatherCondition(
      iconBaseUri: iconBaseUri is String ? iconBaseUri : '',
      description: description is Map<String, dynamic> &&
              description['text'] is String
          ? description['text'] as String
          : '',
    );
  }
}

/// Current weather conditions for a coordinate.
class Weather {
  const Weather({
    required this.condition,
    required this.temperatureC,
    required this.feelsLikeC,
    this.heatIndexC,
    this.uvIndex,
    this.precipitationPercent,
    this.relativeHumidity,
    this.conditionType = '',
  });

  final WeatherCondition condition;

  /// Current temperature in degrees Celsius.
  final double? temperatureC;

  /// Feels-like temperature in degrees Celsius.
  final double? feelsLikeC;

  /// Current heat index in degrees Celsius.
  final double? heatIndexC;

  /// Current UV index (0–11+). Null when the API did not report it.
  final int? uvIndex;

  /// Probability of precipitation as a percentage (0–100). Null when absent.
  final int? precipitationPercent;

  /// Relative humidity as a percentage (0–100). Null when absent.
  final int? relativeHumidity;

  /// Machine-readable condition type, e.g. `CLEAR`, `RAIN`, `SNOW`.
  final String conditionType;

  factory Weather.fromJson(Map<String, dynamic> json) {
    final condition = json['weatherCondition'];
    return Weather(
      condition: condition is Map<String, dynamic>
          ? WeatherCondition.fromJson(condition)
          : const WeatherCondition(iconBaseUri: '', description: ''),
      temperatureC: _degrees(json['temperature']),
      feelsLikeC: _degrees(json['feelsLikeTemperature']),
      heatIndexC: _degrees(json['heatIndex']),
      uvIndex: _int(json['uvIndex']),
      precipitationPercent: _precipitationPercent(json['precipitation']),
      relativeHumidity: _int(json['relativeHumidity']),
      conditionType: _conditionType(condition),
    );
  }

  /// Extracts `.degrees` from a nested `{ "degrees": ..., "unit": ... }` map.
  static double? _degrees(dynamic value) {
    if (value is Map<String, dynamic> && value['degrees'] is num) {
      return (value['degrees'] as num).toDouble();
    }
    return null;
  }

  /// Reads a plain integer value, returning null when absent or non-numeric.
  static int? _int(dynamic value) {
    if (value is num) return value.toInt();
    return null;
  }

  /// Extracts `precipitation.probability.percent` from the nested map.
  static int? _precipitationPercent(dynamic value) {
    if (value is Map<String, dynamic>) {
      final probability = value['probability'];
      if (probability is Map<String, dynamic>) {
        final percent = probability['percent'];
        if (percent is num) return percent.toInt();
      }
    }
    return null;
  }

  /// Reads the `type` field from the `weatherCondition` map.
  static String _conditionType(dynamic condition) {
    if (condition is Map<String, dynamic> && condition['type'] is String) {
      return condition['type'] as String;
    }
    return '';
  }
}
