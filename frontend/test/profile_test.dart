import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:nowcast/src/api/api_client.dart';
import 'package:nowcast/src/models/post.dart';

void main() {
  group('ApiClient.get users/{id}/posts', () {
    test('fetches a user\'s posts without an auth header', () async {
      final mock = MockClient((http.Request request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/users/3/posts');
        expect(request.headers.containsKey('Authorization'), isFalse);
        return http.Response(
          jsonEncode(<dynamic>[
            <String, dynamic>{
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
            },
          ]),
          200,
          headers: const <String, String>{'Content-Type': 'application/json'},
        );
      });

      final api = ApiClient(client: mock, baseUrl: 'http://example.com/api');
      final json = await api.get('users/3/posts');

      final posts = json
          .whereType<Map<String, dynamic>>()
          .map(Post.fromJson)
          .toList();
      expect(posts.length, 1);
      expect(posts[0].id, 10);
      expect(posts[0].userId, 3);
      expect(posts[0].content, 'Stay hydrated out there!');
      expect(posts[0].user.id, 3);
      expect(posts[0].user.name, 'Jane Doe');
    });

    test('returns an empty list when the user has no posts', () async {
      final mock = MockClient((http.Request request) async {
        return http.Response(
          jsonEncode(<dynamic>[]),
          200,
          headers: const <String, String>{'Content-Type': 'application/json'},
        );
      });

      final api = ApiClient(client: mock, baseUrl: 'http://example.com/api');
      final json = await api.get('users/3/posts');

      expect(json is List, isTrue);
      expect(json.length, 0);
    });

    test('throws ApiException on 404 (user not found)', () async {
      final mock = MockClient((http.Request request) async {
        return http.Response(
          jsonEncode(<String, dynamic>{'message': 'User not found.'}),
          404,
        );
      });

      final api = ApiClient(client: mock, baseUrl: 'http://example.com/api');
      await expectLater(
        api.get('users/999/posts'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.message, 'message', 'User not found.'),
        ),
      );
    });
  });
}