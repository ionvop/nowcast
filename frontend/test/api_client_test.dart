import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:nowcast/src/api/api_client.dart';

ApiClient _api(http.Client client, {Duration? timeout}) => ApiClient(
      client: client,
      baseUrl: 'http://example.com/api',
      timeout: timeout ?? ApiClient.defaultTimeout,
    );

void main() {
  group('ApiClient timeout', () {
    test('post throws NetworkException when the request exceeds the timeout',
        () async {
      final hanging = MockClient(
        (http.Request request) => Completer<http.Response>().future,
      );

      await expectLater(
        _api(hanging, timeout: const Duration(milliseconds: 20))
            .post('ai/activities', <String, dynamic>{}),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.message,
            'message',
            ApiClient.timeoutMessage,
          ),
        ),
      );
    });

    test('get throws NetworkException when the request exceeds the timeout',
        () async {
      final hanging = MockClient(
        (http.Request request) => Completer<http.Response>().future,
      );

      await expectLater(
        _api(hanging, timeout: const Duration(milliseconds: 20)).get('posts'),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.message,
            'message',
            ApiClient.timeoutMessage,
          ),
        ),
      );
    });

    test('delete throws NetworkException when the request exceeds the timeout',
        () async {
      final hanging = MockClient(
        (http.Request request) => Completer<http.Response>().future,
      );

      await expectLater(
        _api(hanging, timeout: const Duration(milliseconds: 20))
            .delete('posts/1'),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.message,
            'message',
            ApiClient.timeoutMessage,
          ),
        ),
      );
    });

    test('a fast response still decodes normally', () async {
      final client = MockClient((http.Request request) async {
        return http.Response(
          jsonEncode(<String, dynamic>{'ok': true}),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      final json = await _api(client).post('weather', <String, dynamic>{});
      expect(json, <String, dynamic>{'ok': true});
    });

    test('defaults to a 30 second timeout', () {
      expect(ApiClient.defaultTimeout, const Duration(seconds: 30));
    });
  });

  group('ApiClient errors', () {
    test('surfaces the server message on a non-2xx response', () async {
      final client = MockClient((http.Request request) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'message': 'The current conditions field is required.',
          }),
          400,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      await expectLater(
        _api(client).post('ai/activities', <String, dynamic>{}),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having(
                (e) => e.message,
                'message',
                'The current conditions field is required.',
              ),
        ),
      );
    });

    test('throws NetworkException on a transport failure', () async {
      final client = MockClient((http.Request request) async {
        throw const SocketExceptionStub();
      });

      await expectLater(
        _api(client).post('weather', <String, dynamic>{}),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.message,
            'message',
            'Could not reach the server. Check your connection and try again.',
          ),
        ),
      );
    });
  });
}

/// A stand-in transport failure (avoids importing `dart:io` so the test also
/// runs on the web test runner).
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
