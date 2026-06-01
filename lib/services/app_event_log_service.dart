import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_logger.dart';

class AppEventLogService {
  AppEventLogService._();

  static final AppEventLogService instance = AppEventLogService._();

  static const String _prefKey = 'banay_user_event_log';
  static const int _maxEntries = 300;

  Future<void> record({
    required String name,
    String source = 'ui',
    String status = 'success',
    Map<String, Object?> parameters = const <String, Object?>{},
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entries = prefs.getStringList(_prefKey)?.toList() ?? <String>[];
      final payload = <String, dynamic>{
        'name': name,
        'source': source,
        'status': status,
        'timestamp': DateTime.now().toIso8601String(),
        'parameters': _normalizeMap(parameters),
      };

      entries.insert(0, jsonEncode(payload));
      if (entries.length > _maxEntries) {
        entries.removeRange(_maxEntries, entries.length);
      }

      await prefs.setStringList(_prefKey, entries);
      AppLogger.info('AppEventLog', '$name [$status/$source]');
    } catch (error) {
      AppLogger.warning('AppEventLog', 'Failed to persist event $name', error);
    }
  }

  Future<List<Map<String, dynamic>>> readRecentEvents({int limit = 100}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entries = prefs.getStringList(_prefKey) ?? const <String>[];
      return entries
          .take(limit)
          .map((entry) {
            final decoded = jsonDecode(entry);
            if (decoded is Map<String, dynamic>) {
              return decoded;
            }
            if (decoded is Map) {
              return Map<String, dynamic>.from(decoded);
            }
            return <String, dynamic>{'raw': entry};
          })
          .toList(growable: false);
    } catch (error) {
      AppLogger.warning('AppEventLog', 'Failed to read recent events', error);
      return const <Map<String, dynamic>>[];
    }
  }

  Future<void> clearEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
      AppLogger.info('AppEventLog', 'All persisted events cleared');
    } catch (error) {
      AppLogger.warning(
        'AppEventLog',
        'Failed to clear persisted events',
        error,
      );
    }
  }

  Map<String, dynamic> _normalizeMap(Map<String, Object?> input) {
    final normalized = <String, dynamic>{};
    input.forEach((key, value) {
      if (value == null) {
        return;
      }
      normalized[key] = _normalizeValue(value);
    });
    return normalized;
  }

  dynamic _normalizeValue(Object value) {
    if (value is String || value is num || value is bool) {
      return value;
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is Enum) {
      return value.name;
    }
    if (value is List) {
      return value
          .map((entry) => entry == null ? null : _normalizeValue(entry))
          .toList(growable: false);
    }
    if (value is Map) {
      return value.map(
        (key, entry) => MapEntry(
          key.toString(),
          entry == null ? null : _normalizeValue(entry),
        ),
      );
    }
    return value.toString();
  }
}
