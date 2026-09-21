import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:nowcast/src/api/api_client.dart';
import 'package:nowcast/src/models/comment.dart';

void main() {
  group('Comment.fromJson', () {
    test('parses a full comment with embedded user', () {
      final comment = Comment.fromJson(<String, dynamic>{
        'id': 21,
        'post_id': 10,
        'user_id': 5,
        'content': 'Stay hydrated out there!',
        'created_at': '2026-08-12T11:30:00.000000Z',
        'updated_at': '2026-08-12T11:30:00.000000Z',
        'user': <String, dynamic>{
          'id': 5,
          'name': 'Jane Doe',
          'avatar': 'data:image/jpeg;base64,abc',
        },
      });

      expect(comment.id, 21);
      expect(comment.postId, 10);
      expect(comment.userId, 5);
      expect(comment.content, 'Stay hydrated out there!');
      expect(comment.createdAt, isNotNull);
      expect(comment.user.id, 5);
      expect(comment.user.name, 'Jane Doe');
      expect(comment.user.avatar, 'data:image/jpeg;base64,abc');
    });

    test('tolerates missing and null fields', () {
      final comment = Comment.fromJson(<String, dynamic>{
        'content': 'Hello',
        'user': <String, dynamic>{'name': 'Jane'},
      });

      expect(comment.id, isNull);
      expect(comment.postId, isNull);
      expect(comment.userId, isNull);
      expect(comment.content, 'Hello');
      expect(comment.createdAt, isNull);
      expect(comment.user.name, 'Jane');
    });

    test('tolerates a missing user object', () {
      final comment = Comment.fromJson(<String, dynamic>{'content': 'Hello'});
      expect(comment.user.name, '');
      expect(comment.user.email, '');
    });
  });

  group('ApiClient comments', () {
    test(
      'POSTs a comment with Bearer token and returns decoded JSON',
      () async {
        final mock = MockClient((http.Request request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/posts/10/comments');
          expect(request.headers['Authorization'], 'Bearer secret-token');
          expect(jsonDecode(request.body), <String, dynamic>{'content': 'Hi!'});
          return http.Response(
            jsonEncode(<String, dynamic>{
              'id': 21,
              'post_id': 10,
              'user_id': 5,
              'content': 'Hi!',
              'user': <String, dynamic>{'id': 5, 'name': 'Jane'},
            }),
            201,
            headers: const <String, String>{'Content-Type': 'application/json'},
          );
        });

        final api = ApiClient(client: mock, baseUrl: 'http://example.com/api');
        final data = await api.post('posts/10/comments', <String, dynamic>{
          'content': 'Hi!',
        }, token: 'secret-token');
        expect(data, isA<Map<String, dynamic>>());
        expect((data as Map<String, dynamic>)['id'], 21);
      },
    );

    test('DELETEs a comment with Bearer token', () async {
      final mock = MockClient((http.Request request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/comments/21');
        expect(request.headers['Authorization'], 'Bearer secret-token');
        return http.Response(
          jsonEncode(<String, dynamic>{'message': 'Comment deleted.'}),
          200,
          headers: const <String, String>{'Content-Type': 'application/json'},
        );
      });

      final api = ApiClient(client: mock, baseUrl: 'http://example.com/api');
      final data = await api.delete('comments/21', token: 'secret-token');
      expect(data, <String, dynamic>{'message': 'Comment deleted.'});
    });

    test('GETs comments for a post without auth', () async {
      final mock = MockClient((http.Request request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/posts/10/comments');
        expect(request.headers.containsKey('Authorization'), isFalse);
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{
              'id': 21,
              'post_id': 10,
              'user_id': 5,
              'content': 'Hi!',
              'user': <String, dynamic>{'id': 5, 'name': 'Jane'},
            },
          ]),
          200,
          headers: const <String, String>{'Content-Type': 'application/json'},
        );
      });

      final api = ApiClient(client: mock, baseUrl: 'http://example.com/api');
      final data = await api.get('posts/10/comments');
      expect(data, isA<List<dynamic>>());
      expect((data as List<dynamic>).length, 1);
    });
  });
}
