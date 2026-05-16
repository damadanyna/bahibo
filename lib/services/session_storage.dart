import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Sensitive fields (tokens, phone) are stored with AES encryption via
// flutter_secure_storage.  Non-sensitive fields (display name, country,
// expiry) remain in SharedPreferences for read performance.
class SessionStorage {
  static const int _sessionDurationInDays = 30;

  // Keys for secure storage (sensitive)
  static const String _accessTokenKey = 'BANAY.access_token';
  static const String _refreshTokenKey = 'BANAY.refresh_token';
  static const String _phoneKey = 'BANAY.phone';
  static const String _pendingPhoneKey = 'BANAY.pending_phone';

  // Keys for SharedPreferences (non-sensitive)
  static const String _displayNameKey = 'BANAY.display_name';
  static const String _countryNameKey = 'BANAY.country_name';
  static const String _countryDialCodeKey = 'BANAY.country_dial_code';
  static const String _sessionExpiryKey = 'BANAY.session_expiry';
  static const String _pendingCountryNameKey = 'BANAY.pending_country_name';
  static const String _pendingCountryDialCodeKey =
      'BANAY.pending_country_dial_code';

  static const AndroidOptions _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  final FlutterSecureStorage _secure = const FlutterSecureStorage(
    aOptions: _androidOptions,
  );

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String phoneE164,
    required String displayName,
    String? countryName,
    String? countryDialCode,
  }) async {
    await Future.wait([
      _secure.write(key: _accessTokenKey, value: accessToken),
      _secure.write(key: _refreshTokenKey, value: refreshToken),
      _secure.write(key: _phoneKey, value: phoneE164),
    ]);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_displayNameKey, displayName);
    if (countryName != null) await prefs.setString(_countryNameKey, countryName);
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
    final expiryMillis = prefs.getInt(_sessionExpiryKey);

    if (expiryMillis == null) return false;

    final expiry = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
    if (expiry.isBefore(DateTime.now())) {
      await clear();
      return false;
    }

    final accessToken = await _secure.read(key: _accessTokenKey);
    final refreshToken = await _secure.read(key: _refreshTokenKey);
    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
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
    await _secure.write(key: _pendingPhoneKey, value: phoneE164);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingCountryNameKey, countryName);
    await prefs.setString(_pendingCountryDialCodeKey, countryDialCode);
  }

  Future<void> clearPhoneDraft() async {
    await _secure.delete(key: _pendingPhoneKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingCountryNameKey);
    await prefs.remove(_pendingCountryDialCodeKey);
  }

  Future<String?> getAccessToken() => _secure.read(key: _accessTokenKey);

  Future<String?> getRefreshToken() => _secure.read(key: _refreshTokenKey);

  Future<String?> getPhoneE164() => _secure.read(key: _phoneKey);

  Future<String?> getDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_displayNameKey);
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
    await Future.wait([
      _secure.delete(key: _accessTokenKey),
      _secure.delete(key: _refreshTokenKey),
      _secure.delete(key: _phoneKey),
    ]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_displayNameKey);
    await prefs.remove(_countryNameKey);
    await prefs.remove(_countryDialCodeKey);
    await prefs.remove(_sessionExpiryKey);
    await clearPhoneDraft();
  }
}
