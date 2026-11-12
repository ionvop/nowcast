import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
  ApiClient({
    http.Client? client,
    String? baseUrl,
    this.timeout = defaultTimeout,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.baseUrl;

  /// How long a single request may take before it is abandoned.
  ///
  /// Without a bound a hung socket leaves the caller waiting forever. It is
  /// deliberately tighter than [aiTimeout] so non-AI endpoints — weather,
  /// forecasts, posts, the profile — fail fast and the UI can offer a retry.
  static const Duration defaultTimeout = Duration(seconds: 30);

  /// How long an AI request may take before it is abandoned.
  ///
  /// The AI endpoints (`ai/summary`, `ai/activities`, `ai/health-risk`) are
  /// slow: the server itself allows OpenRouter up to 30 seconds, and the
  /// payloads have to travel there and back. The extra headroom leaves room
  /// for that round trip so the app receives the server's own error message
  /// instead of timing out first. Pass it per call:
  ///
  /// ```dart
  /// await api.post('ai/summary', body, timeout: ApiClient.aiTimeout);
  /// ```
  static const Duration aiTimeout = Duration(seconds: 60);

  /// The message surfaced when a request exceeds its timeout.
  static const String timeoutMessage =
      'The request timed out. Check your connection and try again.';

  /// How long a single request may take before it is abandoned.
  ///
  /// Applies to every request that does not pass its own `timeout`.
  final Duration timeout;

  final http.Client _client;
  final String _baseUrl;

  /// Resolves the deadline for one request: the per-call [timeout] when given,
  /// otherwise the client-wide default.
  Duration _deadline(Duration? timeout) => timeout ?? this.timeout;

  /// GETs `[baseUrl]/[path]` and returns the decoded JSON.
  ///
  /// When [token] is non-null it is attached as a `Bearer` authorization
  /// header. [timeout] overrides the client-wide deadline for this request
  /// only (see [aiTimeout]). Throws [NetworkException] on transport errors and
  /// [ApiException] on non-2xx responses (a 401 surfaces as [ApiException] with
  /// [ApiException.statusCode] == 401).
  Future<dynamic> get(String path, {String? token, Duration? timeout}) async {
    final uri = Uri.parse('$_baseUrl/$path');
    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: _headers(token: token))
          .timeout(_deadline(timeout));
    } on TimeoutException {
      throw const NetworkException(timeoutMessage);
    } on Exception {
      throw const NetworkException(
        'Could not reach the server. Check your connection and try again.',
      );
    }
    return _decode(response);
  }

  /// GETs `[baseUrl]/[path]` and returns the raw response body bytes.
  ///
  /// Unlike [get], this does not attempt to decode the body as JSON — it is
  /// intended for binary payloads such as weather icon SVGs. [query] is
  /// appended as query parameters. When [token] is non-null it is attached as
  /// a `Bearer` authorization header. [timeout] overrides the client-wide
  /// deadline for this request only. Throws [NetworkException] on transport
  /// errors and [ApiException] on non-2xx responses.
  Future<Uint8List> getBytes(String path,
      {Map<String, String>? query, String? token, Duration? timeout}) async {
    var uri = Uri.parse('$_baseUrl/$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }
    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: _headers(token: token))
          .timeout(_deadline(timeout));
    } on TimeoutException {
      throw const NetworkException(timeoutMessage);
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
    return response.bodyBytes;
  }

  /// POSTs [body] to `[baseUrl]/[path]` and returns the decoded JSON.
  ///
  /// When [token] is provided it is attached as a `Bearer` authorization
  /// header. [timeout] overrides the client-wide deadline for this request
  /// only — the AI endpoints should pass [aiTimeout]. Throws
  /// [NetworkException] on transport errors and [ApiException] on non-2xx
  /// responses.
  Future<dynamic> post(String path, Map<String, dynamic> body,
      {String? token, Duration? timeout}) async {
    final uri = Uri.parse('$_baseUrl/$path');
    final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: _headers(token: token),
            body: jsonEncode(body),
          )
          .timeout(_deadline(timeout));
    } on TimeoutException {
      throw const NetworkException(timeoutMessage);
    } on Exception {
      throw const NetworkException(
        'Could not reach the server. Check your connection and try again.',
      );
    }
    return _decode(response);
  }

  /// PUTs [body] to `[baseUrl]/[path]` and returns the decoded JSON.
  ///
  /// When [token] is provided it is attached as a `Bearer` authorization
  /// header. [timeout] overrides the client-wide deadline for this request
  /// only. Throws [NetworkException] on transport errors and [ApiException] on
  /// non-2xx responses.
  Future<dynamic> put(String path, Map<String, dynamic> body,
      {String? token, Duration? timeout}) async {
    final uri = Uri.parse('$_baseUrl/$path');
    final http.Response response;
    try {
      response = await _client
          .put(
            uri,
            headers: _headers(token: token),
            body: jsonEncode(body),
          )
          .timeout(_deadline(timeout));
    } on TimeoutException {
      throw const NetworkException(timeoutMessage);
    } on Exception {
      throw const NetworkException(
        'Could not reach the server. Check your connection and try again.',
      );
    }
    return _decode(response);
  }

  /// DELETEs `[baseUrl]/[path]` and returns the decoded JSON.
  ///
  /// When [token] is provided it is attached as a `Bearer` authorization
  /// header. [timeout] overrides the client-wide deadline for this request
  /// only. Throws [NetworkException] on transport errors and [ApiException] on
  /// non-2xx responses.
  Future<dynamic> delete(String path, {String? token, Duration? timeout}) async {
    final uri = Uri.parse('$_baseUrl/$path');
    final http.Response response;
    try {
      response = await _client
          .delete(uri, headers: _headers(token: token))
          .timeout(_deadline(timeout));
    } on TimeoutException {
      throw const NetworkException(timeoutMessage);
    } on Exception {
      throw const NetworkException(
        'Could not reach the server. Check your connection and try again.',
      );
    }
    return _decode(response);
  }

  /// Builds the request headers, attaching a `Bearer` token when present.
  Map<String, String> _headers({String? token}) {
    return <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Decodes a successful response, throwing [ApiException] for non-2xx.
  dynamic _decode(http.Response response) {
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
