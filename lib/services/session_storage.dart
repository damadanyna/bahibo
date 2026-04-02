import 'package:shared_preferences/shared_preferences.dart';

class SessionStorage {
  static const String _accessTokenKey = 'bahibo.access_token';
  static const String _refreshTokenKey = 'bahibo.refresh_token';
  static const String _phoneKey = 'bahibo.phone';
  static const String _displayNameKey = 'bahibo.display_name';

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String phoneE164,
    required String displayName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
    await prefs.setString(_phoneKey, phoneE164);
    await prefs.setString(_displayNameKey, displayName);
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
  }
}
