import 'user.dart';

/// A comment on a community post, as returned by the comments endpoints.
///
/// Parsed defensively (see [User.fromJson]) so the model tolerates missing or
/// null fields without crashing. The API embeds the author as a `user` object
/// with `id`, `name` and `avatar`.
class Comment {
  const Comment({
    this.id,
    this.postId,
    this.userId,
    required this.content,
    this.createdAt,
    this.updatedAt,
    required this.user,
  });

  /// Database id, when present.
  final int? id;

  /// Id of the post this comment belongs to, when present.
  final int? postId;

  /// Id of the authoring user, when present.
  final int? userId;

  /// The comment's text content.
  final String content;

  /// When the comment was created, when present.
  final DateTime? createdAt;

  /// When the comment was last updated, when present.
  final DateTime? updatedAt;

  /// The embedded author.
  final User user;

  factory Comment.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    return Comment(
      id: _int(json['id']),
      postId: _int(json['post_id']),
      userId: _int(json['user_id']),
      content: _string(json['content']) ?? '',
      createdAt: _dateTime(json['createdAt'] ?? json['created_at']),
      updatedAt: _dateTime(json['updatedAt'] ?? json['updated_at']),
      user: userJson is Map<String, dynamic>
          ? User.fromJson(userJson)
          : const User(name: '', email: ''),
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
