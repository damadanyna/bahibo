import 'dart:io';
import 'dart:convert';

import 'app_api_client.dart';
import 'api_config.dart';
import 'session_storage.dart';
import 'package:http/http.dart' as http;

class AppAuthService {
  AppAuthService({AppApiClient? client, SessionStorage? sessionStorage})
    : _client = client ?? AppApiClient(),
      _sessionStorage = sessionStorage ?? SessionStorage();

  final AppApiClient _client;
  final SessionStorage _sessionStorage;

  Future<void> registerOrLogin({
    required String phoneE164,
    required String countryName,
    required String countryDialCode,
    required String displayName,
    String? avatarUrl,
  }) async {
    final data = await _client.post(
      '/auth/register',
      body: {
        'phoneE164': phoneE164,
        'countryName': countryName,
        'countryDialCode': countryDialCode,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'role': 'CUSTOMER',
      },
    );

    await _persistSession(data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> requestOtp({
    required String phoneE164,
    required String countryName,
    required String countryDialCode,
    String? appSignature,
  }) async {
    await _sessionStorage.savePhoneDraft(
      phoneE164: phoneE164,
      countryName: countryName,
      countryDialCode: countryDialCode,
    );

    final data = await _client.post(
      '/auth/otp/request',
      body: {
        'phoneE164': phoneE164,
        'countryName': countryName,
        'countryDialCode': countryDialCode,
        'appSignature': appSignature,
      },
    );

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String phoneE164,
    required String otpCode,
  }) async {
    final data = await _client.post(
      '/auth/otp/verify',
      body: {'phoneE164': phoneE164, 'otpCode': otpCode},
    );

    final response = Map<String, dynamic>.from(data as Map);

    if (response['authenticated'] == true &&
        response['accessToken'] is String &&
        response['refreshToken'] is String) {
      await _persistSession(response);
    }

    return response;
  }

  Future<String> uploadProfileImage({
    required String phoneE164,
    required File imageFile,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/auth/profile-image');
    final request = http.MultipartRequest('POST', uri)
      ..fields['phoneE164'] = phoneE164
      ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    http.StreamedResponse streamedResponse;

    try {
      streamedResponse = await request.send();
    } catch (_) {
      throw AppApiException('Impossible de joindre le serveur Bahibo');
    }

    final response = await http.Response.fromStream(streamedResponse);
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = (decoded['message'] as String?) ?? 'Erreur serveur';
      throw AppApiException(message, statusCode: response.statusCode);
    }

    final data = Map<String, dynamic>.from(
      (decoded['data'] as Map?) ?? const <String, dynamic>{},
    );
    final avatarUrl = data['avatarUrl'] as String?;

    if (avatarUrl == null || avatarUrl.isEmpty) {
      throw AppApiException('URL Cloudinary invalide');
    }

    return avatarUrl;
  }

  Future<Map<String, dynamic>> fetchCurrentUser() async {
    final data = await _client.get('/auth/me', authenticated: true);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<bool> restoreSession() async {
    final hasValidSession = await _sessionStorage.hasValidSession();

    if (!hasValidSession) {
      return false;
    }

    final refreshToken = await _sessionStorage.getRefreshToken();

    if (refreshToken == null || refreshToken.isEmpty) {
      await _sessionStorage.clear();
      return false;
    }

    try {
      final data = await _client.post(
        '/auth/refresh',
        body: {'refreshToken': refreshToken},
      );

      await _persistSession(Map<String, dynamic>.from(data as Map));
      return true;
    } on AppApiException {
      await _sessionStorage.clear();
      return false;
    }
  }

  Future<void> _persistSession(Map<String, dynamic> data) {
    final user = Map<String, dynamic>.from(
      (data['user'] as Map?) ?? const <String, dynamic>{},
    );

    return _sessionStorage.saveSession(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      phoneE164: (user['phoneE164'] as String?) ?? '',
      displayName: (user['displayName'] as String?) ?? '',
      countryName: user['countryName'] as String?,
      countryDialCode: user['countryDialCode'] as String?,
    );
  }
}
