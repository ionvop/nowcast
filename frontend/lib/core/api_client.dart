// ignore_for_file: prefer_initializing_formals

import 'package:dio/dio.dart';

import 'adapters/auth_store_adapter.dart';
import 'adapters/base_url_adapter.dart';

/// Central HTTP client for the Nowcast API.
///
/// - Uses the base-URL adapter (`/api` on web, absolute URL on native).
/// - Adds `Content-Type: application/json`.
/// - Attaches `Authorization: Bearer <token>` when authenticated.
/// - Handles 401 (clear token + notify listener), 404, and network errors.
class ApiClient {
  ApiClient({
    required BaseUrlAdapter baseUrlAdapter,
    required AuthStoreAdapter authStore,
  }) : _authStore = authStore {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrlAdapter.baseUrl,
        contentType: Headers.jsonContentType,
        // Tell the server we expect JSON so unauthenticated requests return a
        // clean 401 instead of a redirect to a (nonexistent) login route.
        headers: {'Accept': 'application/json'},
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _authStore.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  late final Dio _dio;
  final AuthStoreAdapter _authStore;

  /// Called when an authenticated request returns 401 (token cleared).
  void Function()? onUnauthorized;

  /// Performs a request and returns the decoded JSON body.
  Future<dynamic> _request(
    String method,
    String path, {
    Object? data,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: data,
        options: Options(method: method),
        cancelToken: cancelToken,
      );
      return response.data;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        throw ApiCancelledException();
      }
      final status = e.response?.statusCode;
      final message = _extractMessage(e.response?.data);
      if (status == 401) {
        await _authStore.clearToken();
        onUnauthorized?.call();
        throw ApiAuthException(message ?? 'Unauthorized.');
      }
      if (status == 404) {
        throw ApiNotFoundException(message ?? 'Not found.');
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw ApiNetworkException(
          'Network error. Please check your connection and try again.',
        );
      }
      throw ApiException(message ?? 'Something went wrong. (${status ?? e.type})');
    }
  }

  String? _extractMessage(dynamic data) {
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return null;
  }

  // --- Public, typed helpers ---

  Future<dynamic> get(String path, {CancelToken? cancelToken}) =>
      _request('GET', path, cancelToken: cancelToken);

  Future<dynamic> post(
    String path, {
    Object? data,
    CancelToken? cancelToken,
  }) => _request('POST', path, data: data, cancelToken: cancelToken);

  Future<dynamic> delete(String path, {CancelToken? cancelToken}) =>
      _request('DELETE', path, cancelToken: cancelToken);

  /// Creates a fresh cancel token tied to a request group.
  CancelToken createCancelToken() => CancelToken();

  void close() => _dio.close();
}

/// Base class for user-friendly API errors.
class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ApiAuthException extends ApiException {
  const ApiAuthException(super.message);
}

class ApiNotFoundException extends ApiException {
  const ApiNotFoundException(super.message);
}

class ApiNetworkException extends ApiException {
  const ApiNetworkException(super.message);
}

class ApiCancelledException extends ApiException {
  const ApiCancelledException() : super('Request cancelled.');
}