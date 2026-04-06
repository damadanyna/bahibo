import 'dart:async';

import 'package:bahibo/services/catalog_api_service.dart';
import 'package:bahibo/services/chat_realtime_service.dart';
import 'package:flutter/foundation.dart';

class PresenceService {
  PresenceService._();

  static final PresenceService instance = PresenceService._();

  final CatalogApiService _catalogApiService = CatalogApiService();
  final ValueNotifier<int> _version = ValueNotifier<int>(0);
  final Map<String, bool> _presenceByUserId = <String, bool>{};
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

    if (_presenceByUserId.containsKey(normalizedUserId) ||
        _pendingUserIds.contains(normalizedUserId)) {
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
      for (final userId in userIds) {
        _presenceByUserId.putIfAbsent(userId, () => false);
      }
      _version.value += 1;
    }
  }
}