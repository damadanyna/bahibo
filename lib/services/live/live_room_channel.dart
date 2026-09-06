import 'dart:async';
import 'dart:convert';

import 'package:banay/component/live/live_overlay_widgets.dart';
import 'package:banay/services/app_auth_service.dart';
import 'package:livekit_client/livekit_client.dart';

/// Comments and likes exchanged between the host and the viewers of a live.
///
/// Rides on the LiveKit room's data channel (no extra backend, no storage):
/// every participant in the room receives what the others publish, and the
/// server enforces who may publish through the token's `canPublishData`
/// grant. Comments go reliable, likes lossy — a dropped heart is harmless.
class LiveRoomChannel {
  LiveRoomChannel({
    required this.room,
    required this.isHost,
    this.authorName,
    this.authorAvatarUrl,
  });

  static const String topic = 'banay.live';
  static const int _maxMessageLength = 300;

  final Room room;
  final bool isHost;

  /// Known identity (the host knows its shop name); when null, resolved from
  /// the authenticated user so viewers appear under their own name.
  final String? authorName;
  final String? authorAvatarUrl;

  final AppAuthService _authService = AppAuthService();
  final StreamController<LiveCommentEntry> _comments =
      StreamController<LiveCommentEntry>.broadcast();
  final StreamController<int> _likes = StreamController<int>.broadcast();
  EventsListener<RoomEvent>? _listener;
  String _resolvedName = '';
  String _resolvedAvatarUrl = '';
  String _userId = '';
  int _sequence = 0;

  /// Comments published by the other participants (own ones are echoed by
  /// the caller from [sendComment]'s return value).
  Stream<LiveCommentEntry> get comments => _comments.stream;

  /// Like increments received from other participants.
  Stream<int> get likes => _likes.stream;

  Future<void> start() async {
    _listener ??= room.createListener()..on<DataReceivedEvent>(_handleData);
    await _resolveIdentity();
  }

  Future<void> dispose() async {
    await _listener?.dispose();
    _listener = null;
    await _comments.close();
    await _likes.close();
  }

  Future<void> _resolveIdentity() async {
    _resolvedName = authorName?.trim() ?? '';
    _resolvedAvatarUrl = authorAvatarUrl?.trim() ?? '';

    try {
      final user = await _authService.fetchCurrentUser();
      _userId = (user['id'] ?? user['userId'])?.toString().trim() ?? '';
      if (_resolvedName.isEmpty) {
        _resolvedName =
            (user['displayName'] ?? user['name'])?.toString().trim() ?? '';
      }
      if (_resolvedAvatarUrl.isEmpty) {
        _resolvedAvatarUrl = user['avatarUrl']?.toString().trim() ?? '';
      }
    } catch (_) {
      // Offline or expired session: keep the fallbacks below, the message
      // still reaches the room.
    }

    if (_resolvedName.isEmpty) {
      _resolvedName = isHost ? 'Vendeur' : 'Spectateur';
    }
  }

  /// Publishes [text] to the room and returns the entry to echo locally
  /// (LiveKit does not deliver a participant's own data back to them).
  Future<LiveCommentEntry?> sendComment(String text) async {
    final message = text.trim();
    if (message.isEmpty) {
      return null;
    }

    final entry = LiveCommentEntry(
      id: '$_userId-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}',
      author: _resolvedName,
      avatarUrl: _resolvedAvatarUrl,
      message: message.length > _maxMessageLength
          ? message.substring(0, _maxMessageLength)
          : message,
      isHost: isHost,
      userId: _userId,
    );
    await _publish({'type': 'comment', ...entry.toJson()}, reliable: true);
    return entry;
  }

  Future<void> sendLike({int count = 1}) {
    return _publish({
      'type': 'like',
      'count': count,
      'userId': _userId,
    }, reliable: false);
  }

  Future<void> _publish(
    Map<String, dynamic> payload, {
    required bool reliable,
  }) async {
    final participant = room.localParticipant;
    if (participant == null) {
      return;
    }

    try {
      await participant.publishData(
        utf8.encode(jsonEncode(payload)),
        reliable: reliable,
        topic: topic,
      );
    } catch (_) {
      // Best effort: the sender already sees their own message locally and
      // the room will reconnect on its own.
    }
  }

  void _handleData(DataReceivedEvent event) {
    if (event.topic != null && event.topic != topic) {
      return;
    }

    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(utf8.decode(event.data));
      if (decoded is! Map) {
        return;
      }
      payload = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return;
    }

    switch (payload['type']) {
      case 'comment':
        final entry = LiveCommentEntry.fromJson(payload);
        if (entry != null && !_comments.isClosed) {
          _comments.add(entry);
        }
      case 'like':
        final rawCount = payload['count'];
        final count = rawCount is num ? rawCount.toInt().clamp(1, 50) : 1;
        if (!_likes.isClosed) {
          _likes.add(count);
        }
    }
  }
}
