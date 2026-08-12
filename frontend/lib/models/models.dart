import 'package:flutter/foundation.dart';

/// Defensive helpers for reading nested raw Google payloads.
double? _num(Map<String, dynamic> json, List<String> path) {
  dynamic cur = json;
  for (final key in path) {
    if (cur is! Map) return null;
    cur = cur[key];
  }
  if (cur is num) return cur.toDouble();
  if (cur is String) return double.tryParse(cur);
  return null;
}

String? _str(Map<String, dynamic> json, List<String> path) {
  dynamic cur = json;
  for (final key in path) {
    if (cur is! Map) return null;
    cur = cur[key];
  }
  return cur is String ? cur : null;
}

/// Raw Google current-conditions payload.
@immutable
class Weather {
  const Weather({
    this.description,
    this.iconBaseUri,
    this.temperature,
    this.feelsLike,
    this.dewPoint,
    this.heatIndex,
    this.windChill,
    this.relativeHumidity,
  });

  factory Weather.fromJson(Map<String, dynamic> json) {
    return Weather(
      description: _str(json, ['weatherCondition', 'description', 'text']),
      iconBaseUri: _str(json, ['weatherCondition', 'iconBaseUri']),
      temperature: _num(json, ['temperature', 'degrees']),
      feelsLike: _num(json, ['feelsLikeTemperature', 'degrees']),
      dewPoint: _num(json, ['dewPoint', 'degrees']),
      heatIndex: _num(json, ['heatIndex', 'degrees']),
      windChill: _num(json, ['windChill', 'degrees']),
      relativeHumidity: _num(json, ['relativeHumidity']),
    );
  }

  final String? description;
  final String? iconBaseUri;
  final double? temperature;
  final double? feelsLike;
  final double? dewPoint;
  final double? heatIndex;
  final double? windChill;
  final double? relativeHumidity;
}

/// A single hourly forecast hour from the raw Google forecast payload.
@immutable
class ForecastHour {
  const ForecastHour({
    this.startTime,
    this.hour24,
    this.description,
    this.iconBaseUri,
    this.temperature,
    this.feelsLike,
    this.dewPoint,
    this.heatIndex,
    this.windChill,
    this.wetBulb,
  });

  factory ForecastHour.fromJson(Map<String, dynamic> json) {
    final start = _str(json, ['interval', 'startTime']);
    DateTime? startTime;
    if (start != null) {
      startTime = DateTime.tryParse(start);
    }
    final hour24 = _num(json, ['displayDateTime', 'hours'])?.toInt();
    return ForecastHour(
      startTime: startTime,
      hour24: hour24,
      description: _str(json, ['weatherCondition', 'description', 'text']),
      iconBaseUri: _str(json, ['weatherCondition', 'iconBaseUri']),
      temperature: _num(json, ['temperature', 'degrees']),
      feelsLike: _num(json, ['feelsLikeTemperature', 'degrees']),
      dewPoint: _num(json, ['dewPoint', 'degrees']),
      heatIndex: _num(json, ['heatIndex', 'degrees']),
      windChill: _num(json, ['windChill', 'degrees']),
      wetBulb: _num(json, ['wetBulbTemperature', 'degrees']),
    );
  }

  final DateTime? startTime;
  final int? hour24;
  final String? description;
  final String? iconBaseUri;
  final double? temperature;
  final double? feelsLike;
  final double? dewPoint;
  final double? heatIndex;
  final double? windChill;
  final double? wetBulb;

  /// A safe hour for display: falls back to the UTC hour of startTime.
  int get displayHour => hour24 ?? (startTime?.toUtc().hour ?? 0);
}

/// Result of a heat-location analysis / a stored heat reading.
@immutable
class HeatLocation {
  const HeatLocation({
    this.id,
    required this.heatIndex,
    required this.latitude,
    required this.longitude,
    this.createdAt,
  });

  factory HeatLocation.fromJson(Map<String, dynamic> json) {
    return HeatLocation(
      id: json['id'] as int?,
      heatIndex: (json['heat_index'] as num?)?.toDouble(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      createdAt: json['created_at'] as String? ?? json['createdAt'] as String?,
    );
  }

  final int? id;
  final double? heatIndex;
  final double latitude;
  final double longitude;
  final String? createdAt;
}

/// Author embedded in posts.
@immutable
class User {
  const User({
    required this.id,
    this.name,
    this.email,
    this.avatar,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String?,
      email: json['email'] as String?,
      avatar: json['avatar'] as String?,
    );
  }

  final int id;
  final String? name;
  final String? email;
  final String? avatar;
}

/// A community post with its embedded author.
@immutable
class Post {
  const Post({
    required this.id,
    required this.content,
    this.address,
    this.latitude,
    this.longitude,
    this.createdAt,
    this.user,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: (json['id'] as num?)?.toInt() ?? 0,
      content: json['content'] as String? ?? '',
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      createdAt: json['created_at'] as String?,
      user: json['user'] is Map<String, dynamic>
          ? User.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }

  final int id;
  final String content;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? createdAt;
  final User? user;

  DateTime? get createdDateTime {
    final c = createdAt;
    return c == null ? null : DateTime.tryParse(c);
  }
}
