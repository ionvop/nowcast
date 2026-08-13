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
  });

  final WeatherCondition condition;

  /// Current temperature in degrees Celsius.
  final double? temperatureC;

  /// Feels-like temperature in degrees Celsius.
  final double? feelsLikeC;

  factory Weather.fromJson(Map<String, dynamic> json) {
    final condition = json['weatherCondition'];
    return Weather(
      condition: condition is Map<String, dynamic>
          ? WeatherCondition.fromJson(condition)
          : const WeatherCondition(iconBaseUri: '', description: ''),
      temperatureC: _degrees(json['temperature']),
      feelsLikeC: _degrees(json['feelsLikeTemperature']),
    );
  }

  /// Extracts `.degrees` from a nested `{ "degrees": ..., "unit": ... }` map.
  static double? _degrees(dynamic value) {
    if (value is Map<String, dynamic> && value['degrees'] is num) {
      return (value['degrees'] as num).toDouble();
    }
    return null;
  }
}
