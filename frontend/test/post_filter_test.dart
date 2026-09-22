import 'package:flutter_test/flutter_test.dart';

import 'package:nowcast/src/models/post.dart';
import 'package:nowcast/src/models/user.dart';
import 'package:nowcast/src/utils/post_filter.dart';

Post _post(String content, {String? author, String? address}) {
  return Post(
    content: content,
    user: User(name: author ?? 'Jane Doe', email: ''),
    address: address,
  );
}

void main() {
  group('filterPosts', () {
    final posts = <Post>[
      _post('Stay hydrated out there!', author: 'Jane Doe'),
      _post('Heavy rain in the valley', author: 'Alex', address: 'Valley, CA'),
      _post('Heat wave warning', author: 'Sam', address: 'Phoenix, AZ'),
    ];

    test('returns all posts for an empty query', () {
      expect(filterPosts(posts, ''), posts);
    });

    test('returns all posts for a blank query', () {
      expect(filterPosts(posts, '   '), posts);
    });

    test('matches a single word in content', () {
      final result = filterPosts(posts, 'rain');
      expect(result.length, 1);
      expect(result.first.content, 'Heavy rain in the valley');
    });

    test('matches multiple words with AND semantics', () {
      final result = filterPosts(posts, 'heat wave');
      expect(result.length, 1);
      expect(result.first.content, 'Heat wave warning');
    });

    test('is case-insensitive', () {
      final result = filterPosts(posts, 'HEAT');
      expect(result.length, 1);
      expect(result.first.content, 'Heat wave warning');
    });

    test('matches the author name', () {
      final result = filterPosts(posts, 'alex');
      expect(result.length, 1);
      expect(result.first.content, 'Heavy rain in the valley');
    });

    test('matches the tagged address', () {
      final result = filterPosts(posts, 'phoenix');
      expect(result.length, 1);
      expect(result.first.content, 'Heat wave warning');
    });

    test('matches across content, author, and address', () {
      final result = filterPosts(posts, 'valley alex');
      expect(result.length, 1);
      expect(result.first.content, 'Heavy rain in the valley');
    });

    test('returns no posts when nothing matches', () {
      expect(filterPosts(posts, 'snowstorm'), isEmpty);
    });

    test('returns no posts when only some words match', () {
      expect(filterPosts(posts, 'rain snow'), isEmpty);
    });
  });
}
