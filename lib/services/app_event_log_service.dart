import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_logger.dart';

class AppEventLogService {
  AppEventLogService._();

  static final AppEventLogService instance = AppEventLogService._();

  static const String _prefKey = 'banay_user_event_log';
  static const String _lastSyncKey = 'banay_user_event_log_last_sync';
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

  /// Events recorded since the last successful [markSyncedUpTo] call, newest
  /// first. Used by the background flush (see AppEventLogSyncService) so it
  /// only ever uploads events once.
  Future<List<Map<String, dynamic>>> readEventsSinceLastSync({
    int limit = 200,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncIso = prefs.getString(_lastSyncKey);
      final lastSync = lastSyncIso != null
          ? DateTime.tryParse(lastSyncIso)
          : null;
      final allEvents = await readRecentEvents(limit: _maxEntries);

      if (lastSync == null) {
        return allEvents.take(limit).toList(growable: false);
      }

      final freshEvents = <Map<String, dynamic>>[];
      for (final event in allEvents) {
        final timestamp = DateTime.tryParse(
          event['timestamp']?.toString() ?? '',
        );
        if (timestamp == null || !timestamp.isAfter(lastSync)) {
          break; // Entries are newest-first: the rest were already synced.
        }
        freshEvents.add(event);
        if (freshEvents.length >= limit) {
          break;
        }
      }
      return freshEvents;
    } catch (error) {
      AppLogger.warning(
        'AppEventLog',
        'Failed to read events since last sync',
        error,
      );
      return const <Map<String, dynamic>>[];
    }
  }

  Future<void> markSyncedUpTo(DateTime timestamp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, timestamp.toIso8601String());
    } catch (error) {
      AppLogger.warning('AppEventLog', 'Failed to persist sync marker', error);
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
