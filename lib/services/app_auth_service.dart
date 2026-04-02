import 'app_api_client.dart';
import 'session_storage.dart';

class AppAuthService {
  AppAuthService({AppApiClient? client, SessionStorage? sessionStorage})
    : _client = client ?? AppApiClient(),
      _sessionStorage = sessionStorage ?? SessionStorage();

  final AppApiClient _client;
  final SessionStorage _sessionStorage;

  Future<void> registerOrLogin({
    required String phoneE164,
    required String displayName,
    required String password,
  }) async {
    try {
      final data = await _client.post(
        '/auth/register',
        body: {
          'phoneE164': phoneE164,
          'displayName': displayName,
          'password': password,
          'role': 'CUSTOMER',
        },
      );
      await _persistSession(
        data as Map<String, dynamic>,
        phoneE164,
        displayName,
      );
      return;
    } on AppApiException catch (error) {
      if (error.statusCode != 409) {
        rethrow;
      }
    }

    final loginData = await _client.post(
      '/auth/login',
      body: {'phoneE164': phoneE164, 'password': password},
    );

    await _persistSession(
      loginData as Map<String, dynamic>,
      phoneE164,
      displayName,
    );
  }

  Future<Map<String, dynamic>> fetchCurrentUser() async {
    final data = await _client.get('/auth/me', authenticated: true);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> _persistSession(
    Map<String, dynamic> data,
    String phoneE164,
    String displayName,
  ) {
    return _sessionStorage.saveSession(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      phoneE164: phoneE164,
      displayName: displayName,
    );
  }
}
