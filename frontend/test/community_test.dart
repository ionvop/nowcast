import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:nowcast/src/api/api_client.dart';
import 'package:nowcast/src/models/post.dart';
import 'package:nowcast/src/utils/time_ago.dart';

void main() {
  group('Post.fromJson', () {
    test('parses a full post with embedded user', () {
      final post = Post.fromJson(<String, dynamic>{
        'id': 10,
        'user_id': 3,
        'content': 'Stay hydrated out there!',
        'address': 'New York, NY, USA',
        'latitude': 40.7128,
        'longitude': -74.006,
        'created_at': '2026-08-12T11:30:00.000000Z',
        'updated_at': '2026-08-12T11:30:00.000000Z',
        'user': <String, dynamic>{
          'id': 3,
          'name': 'Jane Doe',
          'avatar': 'data:image/jpeg;base64,abc',
        },
      });

      expect(post.id, 10);
      expect(post.userId, 3);
      expect(post.content, 'Stay hydrated out there!');
      expect(post.address, 'New York, NY, USA');
      expect(post.latitude, 40.7128);
      expect(post.longitude, -74.006);
      expect(post.createdAt, isNotNull);
      expect(post.user.id, 3);
      expect(post.user.name, 'Jane Doe');
      expect(post.user.avatar, 'data:image/jpeg;base64,abc');
    });

    test('tolerates missing and null fields', () {
      final post = Post.fromJson(<String, dynamic>{
        'content': 'Hello',
        'user': <String, dynamic>{'name': 'Jane'},
      });

      expect(post.id, isNull);
      expect(post.userId, isNull);
      expect(post.content, 'Hello');
      expect(post.address, isNull);
      expect(post.latitude, isNull);
      expect(post.longitude, isNull);
      expect(post.createdAt, isNull);
      expect(post.user.name, 'Jane');
    });

    test('tolerates a missing user object', () {
      final post = Post.fromJson(<String, dynamic>{'content': 'Hello'});
      expect(post.user.name, '');
      expect(post.user.email, '');
    });
  });

  group('timeAgo', () {
    test('returns "just now" for recent times', () {
      expect(timeAgo(DateTime.now().subtract(const Duration(seconds: 5))),
          'just now');
    });

    test('returns minutes ago', () {
      expect(timeAgo(DateTime.now().subtract(const Duration(minutes: 5))),
          '5 minutes ago');
    });

    test('returns singular unit', () {
      expect(timeAgo(DateTime.now().subtract(const Duration(minutes: 1))),
          '1 minute ago');
    });

    test('returns hours ago', () {
      expect(timeAgo(DateTime.now().subtract(const Duration(hours: 2))),
          '2 hours ago');
    });

    test('returns days ago', () {
      expect(timeAgo(DateTime.now().subtract(const Duration(days: 3))),
          '3 days ago');
    });

    test('returns "in the future" for future times', () {
      expect(timeAgo(DateTime.now().add(const Duration(minutes: 1))),
          'in the future');
    });
  });

  group('ApiClient.delete', () {
    test('sends DELETE with Bearer token and returns decoded JSON', () async {
      final mock = MockClient((http.Request request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/posts/10');
        expect(request.headers['Authorization'], 'Bearer secret-token');
        return http.Response(
          jsonEncode(<String, dynamic>{'message': 'Post deleted.'}),
          200,
          headers: const <String, String>{'Content-Type': 'application/json'},
        );
      });

      final api = ApiClient(client: mock, baseUrl: 'http://example.com/api');
      final data = await api.delete('posts/10', token: 'secret-token');
      expect(data, <String, dynamic>{'message': 'Post deleted.'});
    });

    test('throws ApiException on non-2xx', () async {
      final mock = MockClient((http.Request request) async {
        return http.Response(
          jsonEncode(<String, dynamic>{'message': 'Unauthorized.'}),
          401,
        );
      });

      final api = ApiClient(client: mock, baseUrl: 'http://example.com/api');
      await expectLater(
        api.delete('posts/10', token: 'bad'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', 'Unauthorized.'),
        ),
      );
    });
  });
}
