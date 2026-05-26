// data/api/api_client.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'package:finance_app/core/error/app_exception.dart';

/// HTTP client for the finance API.
///
/// Responsibilities (and nothing else):
/// 1. Auth header injection — reads the stored token and attaches
///    `Authorization: Bearer <token>` to every protected request.
/// 2. Exponential backoff retry — `get/post/patch/delete` retry up to 3 times
///    on [NetworkException] or 5xx responses, with delays of 1s, 2s, 4s.
///    `getOnce` never retries.
/// 3. Exception mapping — maps HTTP status codes to typed [AppException]
///    subtypes. Throws [AuthException] on 401.
///
/// [ApiClient] does NOT own any caching or SWR logic — that belongs to
/// repositories.
class ApiClient {
  static const _baseUrl = 'https://unbrokie-backend-production.up.railway.app/api/v1';

  /// Storage key used to persist the JWT.
  static const _tokenKey = 'auth_token';

  /// Maximum number of retry attempts for foreground requests.
  static const _maxRetries = 3;

  /// Exponential backoff delays: 1s, 2s, 4s.
  static const _retryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  final http.Client _client;
  final FlutterSecureStorage _storage;

  const ApiClient({
    required http.Client client,
    required FlutterSecureStorage storage,
  })  : _client = client,
        _storage = storage;

  // ---------------------------------------------------------------------------
  // Public API — foreground calls (with retry)
  // ---------------------------------------------------------------------------

  /// Performs a GET request with exponential backoff retry.
  ///
  /// Unwraps `response["data"]` before returning.
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    final response = await _withRetry(
      () => _doGet(path, query: query),
    );
    return _unwrapData(response);
  }

  /// Performs a POST request with exponential backoff retry.
  ///
  /// Unwraps `response["data"]` before returning.
  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
  }) async {
    final response = await _withRetry(
      () => _doPost(path, body: body),
    );
    return _unwrapData(response);
  }

  /// Performs a POST request without an Authorization header.
  ///
  /// Use for public endpoints like `/auth/login` and `/auth/register`
  /// where no token exists yet.
  Future<Map<String, dynamic>> postPublic(
    String path, {
    Object? body,
  }) async {
    final response = await _withRetry(
      () => _doPostPublic(path, body: body),
    );
    return _unwrapData(response);
  }

  /// Performs a PATCH request with exponential backoff retry.
  ///
  /// Unwraps `response["data"]` before returning.
  Future<Map<String, dynamic>> patch(
    String path, {
    Object? body,
  }) async {
    final response = await _withRetry(
      () => _doPatch(path, body: body),
    );
    return _unwrapData(response);
  }

  /// Performs a DELETE request with exponential backoff retry.
  Future<void> delete(String path) async {
    await _withRetry(() => _doDelete(path));
  }

  // ---------------------------------------------------------------------------
  // Public API — background call (no retry)
  // ---------------------------------------------------------------------------

  /// Performs a single GET attempt with no retry.
  ///
  /// Used exclusively by [CachedFetch] background refresh.
  /// Unwraps `response["data"]` before returning.
  Future<Map<String, dynamic>> getOnce(
    String path, {
    Map<String, String>? query,
  }) async {
    final response = await _doGet(path, query: query);
    _checkStatus(response);
    return _unwrapData(response);
  }

  // ---------------------------------------------------------------------------
  // Private helpers — raw HTTP verbs
  // ---------------------------------------------------------------------------

  Future<http.Response> _doGet(
    String path, {
    Map<String, String>? query,
  }) async {
    final uri = _buildUri(path, query);
    final headers = await _authHeaders();
    try {
      return await _client.get(uri, headers: headers);
    } on SocketException catch (e) {
      throw NetworkException(e.message);
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    }
  }

  Future<http.Response> _doPost(String path, {Object? body}) async {
    final uri = _buildUri(path, null);
    final headers = await _authHeaders();
    try {
      return await _client.post(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
    } on SocketException catch (e) {
      throw NetworkException(e.message);
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    }
  }

  Future<http.Response> _doPostPublic(String path, {Object? body}) async {
    final uri = _buildUri(path, null);
    const headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    try {
      return await _client.post(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
    } on SocketException catch (e) {
      throw NetworkException(e.message);
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    }
  }

  Future<http.Response> _doPatch(String path, {Object? body}) async {
    final uri = _buildUri(path, null);
    final headers = await _authHeaders();
    try {
      return await _client.patch(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
    } on SocketException catch (e) {
      throw NetworkException(e.message);
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    }
  }

  Future<http.Response> _doDelete(String path) async {
    final uri = _buildUri(path, null);
    final headers = await _authHeaders();
    try {
      return await _client.delete(uri, headers: headers);
    } on SocketException catch (e) {
      throw NetworkException(e.message);
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    }
  }

  // ---------------------------------------------------------------------------
  // Auth header injection
  // ---------------------------------------------------------------------------

  /// Reads the stored JWT and returns headers with `Authorization: Bearer`.
  ///
  /// Throws [AuthException] if no token is stored (treated as 401).
  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null) {
      throw const AuthException('No stored token — please log in.');
    }
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ---------------------------------------------------------------------------
  // Retry with exponential backoff
  // ---------------------------------------------------------------------------

  /// Retries [request] up to [_maxRetries] times on [NetworkException] or 5xx.
  ///
  /// Delays: 1s before attempt 2, 2s before attempt 3, 4s before attempt 4.
  /// Re-throws the last exception if all attempts fail.
  Future<http.Response> _withRetry(
    Future<http.Response> Function() request,
  ) async {
    Exception? lastException;

    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(_retryDelays[attempt - 1]);
      }

      try {
        final response = await request();

        // Retry on 5xx
        if (response.statusCode >= 500) {
          lastException = ServerException.withStatus(
            response.statusCode,
            'Server error (${response.statusCode}).',
          );
          continue;
        }

        // Non-5xx: map status and return
        _checkStatus(response);
        return response;
      } on NetworkException catch (e) {
        lastException = e;
        // Retry on network failure
      }
      // AuthException, ValidationException, NotFoundException propagate immediately
    }

    throw lastException!;
  }

  // ---------------------------------------------------------------------------
  // Status code → exception mapping
  // ---------------------------------------------------------------------------

  /// Maps HTTP status codes to typed [AppException] subtypes.
  ///
  /// - 401 → [AuthException]
  /// - 404 → [NotFoundException]
  /// - 422 → [ValidationException]
  /// - 5xx → [ServerException]
  /// - 2xx → no-op (success)
  void _checkStatus(http.Response response) {
    final status = response.statusCode;

    if (status >= 200 && status < 300) return;

    final body = _tryDecodeBody(response.body);
    final message = body?['message'] as String? ?? response.reasonPhrase ?? 'Unknown error';

    switch (status) {
      case 401:
        throw AuthException(message);
      case 404:
        throw NotFoundException(message);
      case 422:
        final errors = body?['errors'];
        if (errors is Map<String, dynamic>) {
          throw ValidationException.withFields(
            errors.map((k, v) => MapEntry(k, v.toString())),
            message,
          );
        }
        throw ValidationException(message);
      default:
        if (status >= 500) {
          throw ServerException.withStatus(status, message);
        }
        // Other 4xx (400, 403, etc.) — surface as ValidationException
        throw ValidationException(message);
    }
  }

  // ---------------------------------------------------------------------------
  // Response unwrapping
  // ---------------------------------------------------------------------------

  /// Unwraps the `"data"` key from the decoded JSON response body.
  ///
  /// If the response body has a top-level `"data"` key, returns its value
  /// (cast to `Map<String, dynamic>`). Otherwise returns the full decoded body.
  /// This keeps repositories free of envelope-stripping logic.
  Map<String, dynamic> _unwrapData(http.Response response) {
    final decoded = _tryDecodeBody(response.body);
    if (decoded == null) return {};

    // Debug: log the raw response shape to help diagnose API mismatches
    debugPrint('[ApiClient] response keys: ${decoded.keys.toList()}');

    final data = decoded['data'];
    if (data is Map<String, dynamic>) {
      debugPrint('[ApiClient] data keys: ${data.keys.toList()}');
      // Log full payload for debugging category/transaction field names
      debugPrint('[ApiClient] data: $data');
      return data;
    }

    // data exists but is not a Map — log it
    if (data != null) {
      debugPrint('[ApiClient] WARNING: data field is ${data.runtimeType}: $data');
    }

    // No "data" envelope — return the full body as-is
    return decoded;
  }

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------

  Uri _buildUri(String path, Map<String, String>? query) {
    final base = Uri.parse('$_baseUrl$path');
    if (query == null || query.isEmpty) return base;
    return base.replace(
      queryParameters: {...base.queryParameters, ...query},
    );
  }

  Map<String, dynamic>? _tryDecodeBody(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }
}
