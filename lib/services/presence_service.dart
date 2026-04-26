import 'dart:async';

import 'package:banay/services/catalog_api_service.dart';
import 'package:banay/services/chat_realtime_service.dart';
import 'package:flutter/foundation.dart';

class PresenceService {
  PresenceService._();

  static const Duration _presenceRefreshInterval = Duration(seconds: 30);

  static final PresenceService instance = PresenceService._();

  final CatalogApiService _catalogApiService = CatalogApiService();
  final ValueNotifier<int> _version = ValueNotifier<int>(0);
  final Map<String, bool> _presenceByUserId = <String, bool>{};
  final Map<String, DateTime> _lastPresenceFetchByUserId = <String, DateTime>{};
  final Set<String> _pendingUserIds = <String>{};

  Timer? _batchTimer;
  bool _isInitialized = false;

  ValueListenable<int> get changes => _version;

  bool? presenceOf(String userId) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return null;
    }
    return _presenceByUserId[normalizedUserId];
  }

  void watchUser(String? userId) {
    final normalizedUserId = userId?.trim() ?? '';
    if (normalizedUserId.isEmpty) {
      return;
    }

    _ensureInitialized();

    if (_pendingUserIds.contains(normalizedUserId)) {
      return;
    }

    final lastFetchedAt = _lastPresenceFetchByUserId[normalizedUserId];
    final shouldRefresh =
        lastFetchedAt == null ||
        DateTime.now().difference(lastFetchedAt) >= _presenceRefreshInterval;

    if (!shouldRefresh && _presenceByUserId.containsKey(normalizedUserId)) {
      return;
    }

    _pendingUserIds.add(normalizedUserId);
    _batchTimer?.cancel();
    _batchTimer = Timer(const Duration(milliseconds: 60), _flushPendingUsers);
  }

  void _ensureInitialized() {
    if (_isInitialized) {
      return;
    }

    _isInitialized = true;
    ChatRealtimeService.instance.ensureConnected();
    ChatRealtimeService.instance.events.listen((event) {
      final eventType = event['type']?.toString();
      if (eventType != 'presence:updated') {
        return;
      }

      final userId = event['userId']?.toString().trim() ?? '';
      if (userId.isEmpty) {
        return;
      }

      final isOnline = event['isOnline'] == true;
      final currentValue = _presenceByUserId[userId];
      _lastPresenceFetchByUserId[userId] = DateTime.now();
      if (currentValue == isOnline) {
        return;
      }

      _presenceByUserId[userId] = isOnline;
      _version.value += 1;
    });
  }

  Future<void> _flushPendingUsers() async {
    final userIds = _pendingUserIds.toList(growable: false);
    _pendingUserIds.clear();
    if (userIds.isEmpty) {
      return;
    }

    try {
      final statuses = await _catalogApiService.fetchUsersPresence(userIds);
      var hasChanges = false;
      for (final status in statuses) {
        final userId = status['userId']?.toString().trim() ?? '';
        if (userId.isEmpty) {
          continue;
        }
        _lastPresenceFetchByUserId[userId] = DateTime.now();
        final isOnline = status['isOnline'] == true;
        if (_presenceByUserId[userId] == isOnline) {
          continue;
        }
        _presenceByUserId[userId] = isOnline;
        hasChanges = true;
      }

      if (hasChanges) {
        _version.value += 1;
      }
    } catch (_) {
      // Keep previous values on transient errors so a failed fetch does not
      // permanently force users to appear offline.
    }
  }
}

