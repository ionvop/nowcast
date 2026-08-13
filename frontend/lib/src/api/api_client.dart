import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Thrown when the API returns a non-success HTTP status.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

/// Thrown when the request could not reach the API (network failure).
class NetworkException implements Exception {
  const NetworkException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Central HTTP client for the Laravel proxy API.
///
/// Talks to the API as a separate, independently-hosted service using the
/// base-URL adapter ([AppConfig.baseUrl]). All requests send JSON and parse
/// JSON responses, surfacing user-friendly errors on failure.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  /// POSTs [body] to `[baseUrl]/[path]` and returns the decoded JSON.
  ///
  /// Throws [NetworkException] on transport errors and [ApiException] on
  /// non-2xx responses.
  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$_baseUrl/$path');
    final http.Response response;
    try {
      response = await _client.post(
        uri,
        headers: const <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );
    } on Exception {
      throw const NetworkException(
        'Could not reach the server. Check your connection and try again.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.statusCode,
        _messageFrom(response) ?? 'Request failed (${response.statusCode}).',
      );
    }

    if (response.body.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw const ApiException(200, 'The server returned an invalid response.');
    }
  }

  String? _messageFrom(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } on FormatException {
      // Not JSON; fall through.
    }
    return null;
  }
}
