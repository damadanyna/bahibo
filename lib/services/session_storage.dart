import 'package:shared_preferences/shared_preferences.dart';

class SessionStorage {
  static const String _accessTokenKey = 'bahibo.access_token';
  static const String _refreshTokenKey = 'bahibo.refresh_token';
  static const String _phoneKey = 'bahibo.phone';
  static const String _displayNameKey = 'bahibo.display_name';
  static const String _countryNameKey = 'bahibo.country_name';
  static const String _countryDialCodeKey = 'bahibo.country_dial_code';
  static const String _pendingPhoneKey = 'bahibo.pending_phone';
  static const String _pendingCountryNameKey = 'bahibo.pending_country_name';
  static const String _pendingCountryDialCodeKey =
      'bahibo.pending_country_dial_code';

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String phoneE164,
    required String displayName,
    String? countryName,
    String? countryDialCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
    await prefs.setString(_phoneKey, phoneE164);
    await prefs.setString(_displayNameKey, displayName);
    if (countryName != null) {
      await prefs.setString(_countryNameKey, countryName);
    }
    if (countryDialCode != null) {
      await prefs.setString(_countryDialCodeKey, countryDialCode);
    }
    await clearPhoneDraft();
  }

  Future<void> savePhoneDraft({
    required String phoneE164,
    required String countryName,
    required String countryDialCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingPhoneKey, phoneE164);
    await prefs.setString(_pendingCountryNameKey, countryName);
    await prefs.setString(_pendingCountryDialCodeKey, countryDialCode);
  }

  Future<void> clearPhoneDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingPhoneKey);
    await prefs.remove(_pendingCountryNameKey);
    await prefs.remove(_pendingCountryDialCodeKey);
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_phoneKey);
    await prefs.remove(_displayNameKey);
    await prefs.remove(_countryNameKey);
    await prefs.remove(_countryDialCodeKey);
    await clearPhoneDraft();
  }
}
