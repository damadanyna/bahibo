import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'app_logger.dart';
import 'chat_realtime_service.dart';
import 'presence_service.dart';
import 'session_storage.dart';

class AppApiException implements Exception {
  AppApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AppApiClient {
  AppApiClient({SessionStorage? sessionStorage})
    : _sessionStorage = sessionStorage ?? SessionStorage();

  static const Duration _requestTimeout = Duration(seconds: 20);
  static const int _maxRetries = 2;
  static const String _tag = 'AppApiClient';

  final SessionStorage _sessionStorage;
  Future<bool>? _refreshSessionFuture;

  Future<dynamic> get(
    String path, {
    Map<String, String>? queryParameters,
    bool authenticated = false,
  }) {
    return _requestWithRetry(
      'GET',
      path,
      queryParameters: queryParameters,
      authenticated: authenticated,
    );
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = false,
  }) {
    return _requestWithRetry(
      'POST',
      path,
      body: body,
      authenticated: authenticated,
    );
  }

  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = false,
  }) {
    return _requestWithRetry(
      'PATCH',
      path,
      body: body,
      authenticated: authenticated,
    );
  }

  Future<dynamic> delete(String path, {bool authenticated = false}) {
    return _requestWithRetry('DELETE', path, authenticated: authenticated);
  }

  Future<dynamic> _requestWithRetry(
    String method,
    String path, {
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
    bool authenticated = false,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        return await _request(
          method,
          path,
          queryParameters: queryParameters,
          body: body,
          authenticated: authenticated,
        );
      } on AppApiException catch (e) {
        // Retry only on network-level errors (no statusCode) and only on
        // idempotent methods to avoid duplicate mutations.
        final isNetworkError = e.statusCode == null;
        final isIdempotent = method == 'GET' || method == 'DELETE';
        if (isNetworkError && isIdempotent && attempt < _maxRetries) {
          attempt++;
          final backoff = Duration(milliseconds: 400 * attempt);
          AppLogger.warning(
            _tag,
            'Retry $attempt/$_maxRetries for $method $path after ${backoff.inMilliseconds}ms',
          );
          await Future<void>.delayed(backoff);
          continue;
        }
        rethrow;
      }
    }
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
    bool authenticated = false,
    bool retryOnUnauthorized = true,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path').replace(
      queryParameters: queryParameters?.isEmpty ?? true
          ? null
          : queryParameters,
    );

    final headers = <String, String>{'Content-Type': 'application/json'};

    if (authenticated) {
      final token = await _sessionStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        throw AppApiException('Session utilisateur introuvable');
      }
      headers['Authorization'] = 'Bearer $token';
    }

    AppLogger.debug(_tag, '$method $uri');

    late final http.Response response;

    try {
      final Future<http.Response> call = switch (method) {
        'GET' => http.get(uri, headers: headers),
        'POST' => http.post(
          uri,
          headers: headers,
          body: jsonEncode(body ?? <String, dynamic>{}),
        ),
        'PATCH' => http.patch(
          uri,
          headers: headers,
          body: jsonEncode(body ?? <String, dynamic>{}),
        ),
        'DELETE' => http.delete(uri, headers: headers),
        _ => throw AppApiException('Methode HTTP non supportee'),
      };
      response = await call.timeout(_requestTimeout);
    } on SocketException catch (e) {
      AppLogger.warning(_tag, 'Network unreachable for $method $path', e);
      throw AppApiException('Impossible de joindre le serveur BANAY');
    } on HttpException catch (e) {
      AppLogger.warning(_tag, 'HTTP error for $method $path', e);
      throw AppApiException('Impossible de joindre le serveur BANAY');
    } catch (e) {
      // Covers timeout (TimeoutException) and any other transport error.
      AppLogger.warning(_tag, 'Request failed for $method $path', e);
      throw AppApiException('Impossible de joindre le serveur BANAY');
    }

    AppLogger.debug(_tag, '${response.statusCode} $method $uri');

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 401 &&
        authenticated &&
        retryOnUnauthorized &&
        path != '/auth/refresh') {
      final refreshed = await _refreshSession();
      if (refreshed) {
        return _request(
          method,
          path,
          queryParameters: queryParameters,
          body: body,
          authenticated: authenticated,
          retryOnUnauthorized: false,
        );
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = (decoded['message'] as String?) ?? 'Erreur serveur';
      AppLogger.warning(
        _tag,
        'Server error ${response.statusCode} for $method $path: $message',
      );
      throw AppApiException(message, statusCode: response.statusCode);
    }

    return decoded['data'];
  }

  Future<bool> _refreshSession() async {
    final existingRefresh = _refreshSessionFuture;
    if (existingRefresh != null) return existingRefresh;

    final refreshFuture = _performRefreshSession();
    _refreshSessionFuture = refreshFuture;

    try {
      return await refreshFuture;
    } finally {
      if (identical(_refreshSessionFuture, refreshFuture)) {
        _refreshSessionFuture = null;
      }
    }
  }

  Future<bool> _performRefreshSession() async {
    final refreshToken = await _sessionStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _invalidateSession();
      return false;
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/auth/refresh');
    http.Response response;

    try {
      response = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(_requestTimeout);
    } catch (e) {
      AppLogger.warning(_tag, 'Token refresh failed', e);
      return false;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      await _invalidateSession();
      return false;
    }

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    final data = Map<String, dynamic>.from(
      (decoded['data'] as Map?) ?? const <String, dynamic>{},
    );
    final user = Map<String, dynamic>.from(
      (data['user'] as Map?) ?? const <String, dynamic>{},
    );
    final accessToken = data['accessToken'] as String?;
    final nextRefreshToken = data['refreshToken'] as String?;

    if (accessToken == null ||
        accessToken.isEmpty ||
        nextRefreshToken == null ||
        nextRefreshToken.isEmpty) {
      await _invalidateSession();
      return false;
    }

    await _sessionStorage.saveSession(
      accessToken: accessToken,
      refreshToken: nextRefreshToken,
      phoneE164: (user['phoneE164'] as String?) ?? '',
      displayName: (user['displayName'] as String?) ?? '',
      countryName: user['countryName'] as String?,
      countryDialCode: user['countryDialCode'] as String?,
    );
    return true;
  }

  Future<void> _invalidateSession() async {
    ChatRealtimeService.instance.disconnect();
    PresenceService.instance.reset();
    await _sessionStorage.clear();
  }
}
