import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
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

  final SessionStorage _sessionStorage;

  Future<dynamic> get(
    String path, {
    Map<String, String>? queryParameters,
    bool authenticated = false,
  }) {
    return _request(
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
    return _request('POST', path, body: body, authenticated: authenticated);
  }

  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = false,
  }) {
    return _request('PATCH', path, body: body, authenticated: authenticated);
  }

  Future<dynamic> delete(String path, {bool authenticated = false}) {
    return _request('DELETE', path, authenticated: authenticated);
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
    bool authenticated = false,
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

    late final http.Response response;

    try {
      response = switch (method) {
        'GET' => await http.get(uri, headers: headers),
        'POST' => await http.post(
          uri,
          headers: headers,
          body: jsonEncode(body ?? <String, dynamic>{}),
        ),
        'PATCH' => await http.patch(
          uri,
          headers: headers,
          body: jsonEncode(body ?? <String, dynamic>{}),
        ),
        'DELETE' => await http.delete(uri, headers: headers),
        _ => throw AppApiException('Methode HTTP non supportee'),
      };
    } catch (_) {
      throw AppApiException('Impossible de joindre le serveur Bahibo');
    }

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = (decoded['message'] as String?) ?? 'Erreur serveur';
      throw AppApiException(message, statusCode: response.statusCode);
    }

    return decoded['data'];
  }
}
