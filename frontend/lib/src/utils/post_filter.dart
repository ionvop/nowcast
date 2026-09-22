import '../models/post.dart';

/// Filters a list of posts by a free-text search query.
///
/// Matching is case-insensitive and AND-based: the trimmed query is split into
/// words and a post is kept only when every word appears in its content, author
/// name, or tagged address. An empty or blank query returns all posts.
List<Post> filterPosts(List<Post> posts, String query) {
  final words = query
      .trim()
      .toLowerCase()
      .split(' ')
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return posts;
  return posts.where((post) {
    final content = post.content.toLowerCase();
    final author = post.user.name.toLowerCase();
    final address = (post.address ?? '').toLowerCase();
    return words.every(
      (word) =>
          content.contains(word) ||
          author.contains(word) ||
          address.contains(word),
    );
  }).toList();
}
