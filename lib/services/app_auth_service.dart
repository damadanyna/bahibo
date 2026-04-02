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
    required String countryName,
    required String countryDialCode,
    required String displayName,
    required String password,
  }) async {
    try {
      final data = await _client.post(
        '/auth/register',
        body: {
          'phoneE164': phoneE164,
          'countryName': countryName,
          'countryDialCode': countryDialCode,
          'displayName': displayName,
          'password': password,
          'role': 'CUSTOMER',
        },
      );
      await _persistSession(data as Map<String, dynamic>);
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

    await _persistSession(loginData as Map<String, dynamic>);
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

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> fetchCurrentUser() async {
    final data = await _client.get('/auth/me', authenticated: true);
    return Map<String, dynamic>.from(data as Map);
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
