import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:nowcast/src/api/api_client.dart';
import 'package:nowcast/src/models/user.dart';

void main() {
  group('ApiClient.get', () {
    test('sends GET with Accept/Content-Type and returns decoded JSON', () async {
      final mock = MockClient((http.Request request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/profile');
        expect(request.headers['Accept'], 'application/json');
        expect(request.headers.containsKey('Authorization'), isFalse);
        return http.Response(
          jsonEncode(<String, dynamic>{'name': 'Jane'}),
          200,
          headers: const <String, String>{'Content-Type': 'application/json'},
        );
      });

      final api = ApiClient(client: mock, baseUrl: 'http://example.com/api');
      final data = await api.get('profile');
      expect(data, <String, dynamic>{'name': 'Jane'});
    });

    test('attaches Authorization Bearer header when token given', () async {
      final mock = MockClient((http.Request request) async {
        expect(request.headers['Authorization'], 'Bearer secret-token');
        return http.Response('{}', 200);
      });

      final api = ApiClient(client: mock, baseUrl: 'http://example.com/api');
      await api.get('profile', token: 'secret-token');
    });
  });

  group('ApiClient 401 handling', () {
    test('throws ApiException with statusCode 401', () async {
      final mock = MockClient((http.Request request) async {
        return http.Response(
          jsonEncode(<String, dynamic>{'message': 'Unauthorized.'}),
          401,
        );
      });

      final api = ApiClient(client: mock, baseUrl: 'http://example.com/api');
      await expectLater(
        api.get('profile', token: 'bad'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', 'Unauthorized.'),
        ),
      );
    });
  });

  group('User.fromJson', () {
    test('parses snake_case fields', () {
      final user = User.fromJson(<String, dynamic>{
        'id': 3,
        'name': 'Jane Doe',
        'email': 'jane@example.com',
        'avatar': 'data:image/jpeg;base64,AAAA',
        'created_at': '2026-08-12T10:00:00.000000Z',
        'updated_at': '2026-08-12T11:30:00.000000Z',
      });
      expect(user.id, 3);
      expect(user.name, 'Jane Doe');
      expect(user.email, 'jane@example.com');
      expect(user.avatar, 'data:image/jpeg;base64,AAAA');
      expect(user.createdAt, isNotNull);
      expect(user.updatedAt, isNotNull);
    });

    test('tolerates missing/extra fields', () {
      final user = User.fromJson(<String, dynamic>{});
      expect(user.id, isNull);
      expect(user.name, '');
      expect(user.email, '');
      expect(user.avatar, isNull);
      expect(user.createdAt, isNull);
    });
  });
}