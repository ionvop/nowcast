/// A signed-in user, as returned by `GET /api/profile`.
///
/// Parsed defensively (see [HeatLocation.fromJson]) so the model tolerates
/// missing or null fields without crashing.
class User {
  const User({
    this.id,
    required this.name,
    required this.email,
    this.avatar,
    this.createdAt,
    this.updatedAt,
  });

  /// Database id, when present.
  final int? id;

  /// Display name (e.g. "Jane Doe").
  final String name;

  /// Verified Google / account email.
  final String email;

  /// Avatar as a base64-encoded data URI, e.g.
  /// `"data:image/jpeg;base64,..."`. May be null when the user has no avatar.
  final String? avatar;

  /// When the account was created, when present.
  final DateTime? createdAt;

  /// When the account was last updated, when present.
  final DateTime? updatedAt;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: _int(json['id']),
      name: _string(json['name']) ?? '',
      email: _string(json['email']) ?? '',
      avatar: _string(json['avatar']),
      createdAt: _dateTime(json['createdAt'] ?? json['created_at']),
      updatedAt: _dateTime(json['updatedAt'] ?? json['updated_at']),
    );
  }

  static int? _int(dynamic value) => value is num ? value.toInt() : null;

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