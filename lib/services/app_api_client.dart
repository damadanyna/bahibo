import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'app_event_log_service.dart';
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

  /// Refresh ahead of time when the access token expires within this.
  static const Duration _accessTokenExpiryMargin = Duration(seconds: 60);

  /// Fires when the backend definitively rejected the refresh token
  /// (logged out elsewhere, account removed, 30 days unused) and the local
  /// session was cleared: the UI must send the user back to login. Never
  /// fires for network trouble or server errors.
  static final ValueNotifier<int> sessionInvalidated = ValueNotifier<int>(0);

  /// One refresh at a time for the whole isolate. Every service owns its
  /// own client, so a burst of 401s (access token expired, several screens
  /// loading at once) used to start parallel refreshes with the same
  /// rotating token: the first won, the others were told "invalid token"
  /// and wiped the session, new tokens included.
  static Future<bool>? _refreshSessionFuture;

  final SessionStorage _sessionStorage;

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

  Future<http.Response> getRawUri(Uri uri, {bool authenticated = false}) {
    return _requestRawWithRetry(uri, authenticated: authenticated);
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

  Future<http.Response> _requestRawWithRetry(
    Uri uri, {
    bool authenticated = false,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        return await _requestRaw(uri, authenticated: authenticated);
      } on AppApiException catch (e) {
        final isNetworkError = e.statusCode == null;
        if (isNetworkError && attempt < _maxRetries) {
          attempt++;
          final backoff = Duration(milliseconds: 400 * attempt);
          AppLogger.warning(
            _tag,
            'Retry $attempt/$_maxRetries for raw GET $uri after ${backoff.inMilliseconds}ms',
          );
          await Future<void>.delayed(backoff);
          continue;
        }
        rethrow;
      }
    }
  }

  /// Persists network/API failures to AppEventLogService so they survive in
  /// release builds (unlike AppLogger, which is a no-op outside kDebugMode)
  /// and show up in the QA log export.
  void _logNetworkFailure(
    String eventName, {
    required String method,
    required String path,
    required String reason,
    int? statusCode,
  }) {
    unawaited(
      AppEventLogService.instance.record(
        name: eventName,
        source: 'network',
        status: 'failure',
        parameters: {
          'method': method,
          'path': path,
          'reason': reason,
          if (statusCode != null) 'status_code': statusCode,
        },
      ),
    );
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

    String? usedAccessToken;
    if (authenticated) {
      final token = await _sessionStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        throw AppApiException('Session utilisateur introuvable');
      }
      headers['Authorization'] = 'Bearer $token';
      usedAccessToken = token;
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
      _logNetworkFailure(
        'api_request_failed',
        method: method,
        path: path,
        reason: 'socket_unreachable: $e',
      );
      throw AppApiException('Impossible de joindre le serveur BANAY');
    } on HttpException catch (e) {
      AppLogger.warning(_tag, 'HTTP error for $method $path', e);
      _logNetworkFailure(
        'api_request_failed',
        method: method,
        path: path,
        reason: 'http_exception: $e',
      );
      throw AppApiException('Impossible de joindre le serveur BANAY');
    } catch (e) {
      // Covers timeout (TimeoutException) and any other transport error.
      AppLogger.warning(_tag, 'Request failed for $method $path', e);
      _logNetworkFailure(
        'api_request_failed',
        method: method,
        path: path,
        reason: 'transport_error: $e',
      );
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
      final refreshed = await _recoverFromUnauthorized(usedAccessToken ?? '');
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
      _logNetworkFailure(
        'api_response_error',
        method: method,
        path: path,
        reason: message,
        statusCode: response.statusCode,
      );
      throw AppApiException(message, statusCode: response.statusCode);
    }

    return decoded['data'];
  }

  Future<http.Response> _requestRaw(
    Uri uri, {
    bool authenticated = false,
    bool retryOnUnauthorized = true,
  }) async {
    final headers = <String, String>{'Accept': '*/*'};

    String? usedAccessToken;
    if (authenticated) {
      final token = await _sessionStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        throw AppApiException('Session utilisateur introuvable');
      }
      headers['Authorization'] = 'Bearer $token';
      usedAccessToken = token;
    }

    AppLogger.debug(_tag, 'RAW GET $uri');

    late final http.Response response;
    try {
      response = await http.get(uri, headers: headers).timeout(_requestTimeout);
    } on SocketException catch (e) {
      AppLogger.warning(_tag, 'Network unreachable for raw GET $uri', e);
      _logNetworkFailure(
        'api_request_failed',
        method: 'GET',
        path: uri.toString(),
        reason: 'socket_unreachable: $e',
      );
      throw AppApiException('Impossible de joindre le serveur BANAY');
    } on HttpException catch (e) {
      AppLogger.warning(_tag, 'HTTP error for raw GET $uri', e);
      _logNetworkFailure(
        'api_request_failed',
        method: 'GET',
        path: uri.toString(),
        reason: 'http_exception: $e',
      );
      throw AppApiException('Impossible de joindre le serveur BANAY');
    } catch (e) {
      AppLogger.warning(_tag, 'Request failed for raw GET $uri', e);
      _logNetworkFailure(
        'api_request_failed',
        method: 'GET',
        path: uri.toString(),
        reason: 'transport_error: $e',
      );
      throw AppApiException('Impossible de joindre le serveur BANAY');
    }

    AppLogger.debug(_tag, '${response.statusCode} RAW GET $uri');

    if (response.statusCode == 401 && authenticated && retryOnUnauthorized) {
      final refreshed = await _recoverFromUnauthorized(usedAccessToken ?? '');
      if (refreshed) {
        return _requestRaw(
          uri,
          authenticated: authenticated,
          retryOnUnauthorized: false,
        );
      }
    }

    return response;
  }

  /// Renews the access token ahead of time when it has expired or is about
  /// to, so a cold start (or a socket reconnect) does not begin with a
  /// burst of 401s. Best effort: silent on network trouble, and the session
  /// is only cleared when the backend definitively rejects the refresh
  /// token (see [_performRefreshSession]).
  Future<void> refreshAccessTokenIfExpired() async {
    final accessToken = await _sessionStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      return;
    }
    final expiresAt = _jwtExpiry(accessToken);
    if (expiresAt == null ||
        expiresAt.isAfter(DateTime.now().add(_accessTokenExpiryMargin))) {
      return;
    }
    await _refreshSession();
  }

  /// `exp` claim of a JWT, decoded locally (no signature check needed: it
  /// only decides whether a refresh is worth trying).
  static DateTime? _jwtExpiry(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      return null;
    }
    try {
      final payload =
          jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
              )
              as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is! num) {
        return null;
      }
      return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
    } catch (_) {
      return null;
    }
  }

  /// After a 401 on [usedAccessToken]: true when a retry is worth it, i.e.
  /// the tokens were already rotated by another client or isolate (the
  /// push background handler shares the same storage), or this one just
  /// refreshed them.
  Future<bool> _recoverFromUnauthorized(String usedAccessToken) async {
    final current = await _sessionStorage.getAccessToken();
    if (current != null && current.isNotEmpty && current != usedAccessToken) {
      return true;
    }
    return _refreshSession();
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

  /// Only a 401/403 from `/auth/refresh` on a token nobody rotated
  /// meanwhile ends the session. Everything else (offline, timeout, 5xx,
  /// proxy error, malformed reply) is transient: the request fails, the
  /// user stays logged in, like a messaging app.
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
      _logNetworkFailure(
        'api_request_failed',
        method: 'POST',
        path: '/auth/refresh',
        reason: 'transport_error: $e',
      );
      return false;
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      if (await _refreshTokenRotatedSince(refreshToken)) {
        // Someone else (another isolate) refreshed first: their tokens are
        // in storage, the caller just has to retry with them.
        return true;
      }
      AppLogger.warning(
        _tag,
        'Refresh token rejected (${response.statusCode}): session ended',
      );
      _logNetworkFailure(
        'api_response_error',
        method: 'POST',
        path: '/auth/refresh',
        reason: 'refresh_token_rejected',
        statusCode: response.statusCode,
      );
      await _invalidateSession();
      return false;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      AppLogger.warning(
        _tag,
        'Token refresh failed with HTTP ${response.statusCode}, keeping session',
      );
      _logNetworkFailure(
        'api_response_error',
        method: 'POST',
        path: '/auth/refresh',
        reason: 'server_error',
        statusCode: response.statusCode,
      );
      return false;
    }

    Map<String, dynamic> decoded;
    try {
      decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      AppLogger.warning(
        _tag,
        'Token refresh reply unreadable, keeping session',
        e,
      );
      return false;
    }
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
      AppLogger.warning(
        _tag,
        'Token refresh reply incomplete, keeping session',
      );
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

  /// Whether storage holds a different refresh token than [refreshTokenUsed].
  /// Looks twice with a short pause: a concurrent refresh from another
  /// isolate may have won the rotation and still be writing its result.
  Future<bool> _refreshTokenRotatedSince(String refreshTokenUsed) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 1500));
      }
      final stored = await _sessionStorage.getRefreshToken();
      if (stored != null && stored.isNotEmpty && stored != refreshTokenUsed) {
        return true;
      }
    }
    return false;
  }

  /// Idempotent: a second call on an already cleared session (another
  /// request that got its 401 before the wipe) notifies nobody.
  Future<void> _invalidateSession() async {
    ChatRealtimeService.instance.disconnect();
    PresenceService.instance.reset();
    final refreshToken = await _sessionStorage.getRefreshToken();
    final accessToken = await _sessionStorage.getAccessToken();
    final hadSession =
        (refreshToken?.isNotEmpty ?? false) ||
        (accessToken?.isNotEmpty ?? false);
    await _sessionStorage.clear();
    if (hadSession) {
      sessionInvalidated.value++;
    }
  }
}
