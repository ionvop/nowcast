import 'user.dart';

/// A community post, as returned by the posts endpoints.
///
/// Parsed defensively (see [User.fromJson]) so the model tolerates missing or
/// null fields without crashing. The API embeds the author as a `user` object
/// with `id`, `name` and `avatar`.
class Post {
  const Post({
    this.id,
    this.userId,
    required this.content,
    this.address,
    this.latitude,
    this.longitude,
    this.createdAt,
    this.updatedAt,
    required this.user,
  });

  /// Database id, when present.
  final int? id;

  /// Id of the authoring user, when present.
  final int? userId;

  /// The post's text content.
  final String content;

  /// Reverse-geocoded address, only present when the author opted in.
  final String? address;

  /// Latitude of the tagged location, when present.
  final double? latitude;

  /// Longitude of the tagged location, when present.
  final double? longitude;

  /// When the post was created, when present.
  final DateTime? createdAt;

  /// When the post was last updated, when present.
  final DateTime? updatedAt;

  /// The embedded author.
  final User user;

  factory Post.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    return Post(
      id: _int(json['id']),
      userId: _int(json['user_id']),
      content: _string(json['content']) ?? '',
      address: _string(json['address']),
      latitude: _double(json['latitude']),
      longitude: _double(json['longitude']),
      createdAt: _dateTime(json['createdAt'] ?? json['created_at']),
      updatedAt: _dateTime(json['updatedAt'] ?? json['updated_at']),
      user: userJson is Map<String, dynamic>
          ? User.fromJson(userJson)
          : const User(name: '', email: ''),
    );
  }

  static int? _int(dynamic value) => value is num ? value.toInt() : null;

  static double? _double(dynamic value) => value is num ? value.toDouble() : null;

  static String? _string(dynamic value) => value is String ? value : null;

  static DateTime? _dateTime(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value);
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt() * 1000);
    }
    return null;
  }
}
