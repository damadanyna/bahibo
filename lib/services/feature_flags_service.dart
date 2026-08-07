import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_api_client.dart';
import 'app_logger.dart';

/// Client for server-controlled feature flags (backend: FeatureFlagsModule,
/// `GET/PATCH /feature-flags`). Lets an admin flip a feature on/off live via
/// the API, without an app rebuild or store release.
///
/// Flags are cached locally so the last known state survives an offline
/// launch. Call [initialize] once at startup, then gate UI with [isEnabled].
class FeatureFlagsService {
  FeatureFlagsService._({AppApiClient? client})
    : _client = client ?? AppApiClient();

  static final FeatureFlagsService instance = FeatureFlagsService._();

  static const String _cacheKey = 'banay_feature_flags_cache';
  static const String _tag = 'FeatureFlagsService';

  final AppApiClient _client;
  Map<String, bool> _flags = const <String, bool>{};

  Future<void> initialize() async {
    await _loadFromCache();
    unawaited(refresh());
  }

  Future<void> refresh() async {
    try {
      final data = await _client.get('/feature-flags');
      final flags = <String, bool>{};
      for (final item in (data as List).whereType<Map>()) {
        final key = item['key']?.toString();
        if (key != null && key.isNotEmpty) {
          flags[key] = item['enabled'] == true;
        }
      }
      _flags = flags;
      await _saveToCache(flags);
    } catch (error) {
      AppLogger.warning(_tag, 'Failed to refresh feature flags', error);
    }
  }

  bool isEnabled(String key, {bool defaultValue = false}) {
    return _flags[key] ?? defaultValue;
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) {
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        _flags = decoded.map(
          (key, value) => MapEntry(key.toString(), value == true),
        );
      }
    } catch (error) {
      AppLogger.warning(_tag, 'Failed to load cached feature flags', error);
    }
  }

  Future<void> _saveToCache(Map<String, bool> flags) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(flags));
    } catch (error) {
      AppLogger.warning(_tag, 'Failed to cache feature flags', error);
    }
  }
}
