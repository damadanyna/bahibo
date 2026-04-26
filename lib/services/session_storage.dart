import 'package:shared_preferences/shared_preferences.dart';

class SessionStorage {
  static const int _sessionDurationInDays = 30;
  static const String _accessTokenKey = 'BANAY.access_token';
  static const String _refreshTokenKey = 'BANAY.refresh_token';
  static const String _phoneKey = 'BANAY.phone';
  static const String _displayNameKey = 'BANAY.display_name';
  static const String _countryNameKey = 'BANAY.country_name';
  static const String _countryDialCodeKey = 'BANAY.country_dial_code';
  static const String _sessionExpiryKey = 'BANAY.session_expiry';
  static const String _pendingPhoneKey = 'BANAY.pending_phone';
  static const String _pendingCountryNameKey = 'BANAY.pending_country_name';
  static const String _pendingCountryDialCodeKey =
      'BANAY.pending_country_dial_code';

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
    await prefs.setInt(
      _sessionExpiryKey,
      _nextSessionExpiry().millisecondsSinceEpoch,
    );
    await clearPhoneDraft();
  }

  Future<bool> hasValidSession() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString(_accessTokenKey);
    final refreshToken = prefs.getString(_refreshTokenKey);
    final expiryMillis = prefs.getInt(_sessionExpiryKey);

    if (accessToken == null || refreshToken == null || expiryMillis == null) {
      return false;
    }

    final now = DateTime.now();
    final expiry = DateTime.fromMillisecondsSinceEpoch(expiryMillis);

    if (expiry.isBefore(now)) {
      await clear();
      return false;
    }

    await touchSession();
    return true;
  }

  Future<void> touchSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _sessionExpiryKey,
      _nextSessionExpiry().millisecondsSinceEpoch,
    );
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

  Future<String?> getDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_displayNameKey);
  }

  Future<String?> getPhoneE164() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_phoneKey);
  }

  Future<String?> getCountryName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_countryNameKey);
  }

  Future<String?> getCountryDialCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_countryDialCodeKey);
  }

  DateTime _nextSessionExpiry() {
    return DateTime.now().add(const Duration(days: _sessionDurationInDays));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_phoneKey);
    await prefs.remove(_displayNameKey);
    await prefs.remove(_countryNameKey);
    await prefs.remove(_countryDialCodeKey);
    await prefs.remove(_sessionExpiryKey);
    await clearPhoneDraft();
  }
}


