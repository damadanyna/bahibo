import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguageProvider extends ChangeNotifier {
  AppLanguageProvider._(this._locale);

  static const String _storageKey = 'banay_language_code';

  static const Map<String, String> _languageNameByCode = {
    'mg': 'Malagasy',
    'en': 'English',
    'fr': 'French',
    'zh': 'Mandarin Chinese',
    'hi': 'Hindi',
    'es': 'Spanish',
    'ar': 'Arabic',
  };

  static const Map<String, String> _languageCodeByName = {
    'Malagasy': 'mg',
    'English': 'en',
    'French': 'fr',
    'Mandarin Chinese': 'zh',
    'Hindi': 'hi',
    'Spanish': 'es',
    'Arabic': 'ar',
  };

  Locale _locale;

  Locale get locale => _locale;

  String get selectedLanguageName =>
      _languageNameByCode[_locale.languageCode] ?? 'English';

  static Future<AppLanguageProvider> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_storageKey);
    final normalizedCode = _normalizeLanguageCode(savedCode);
    return AppLanguageProvider._(Locale(normalizedCode));
  }

  static String _normalizeLanguageCode(String? code) {
    if (code != null && _languageNameByCode.containsKey(code)) {
      return code;
    }
    return 'mg';
  }

  Future<void> selectLanguageByName(String languageName) async {
    final nextCode = _languageCodeByName[languageName] ?? 'mg';
    await selectLanguageCode(nextCode);
  }

  Future<void> selectLanguageCode(String languageCode) async {
    final nextCode = _normalizeLanguageCode(languageCode);
    if (_locale.languageCode == nextCode) {
      return;
    }

    _locale = Locale(nextCode);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, nextCode);
  }
}