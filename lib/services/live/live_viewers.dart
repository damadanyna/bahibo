import 'dart:convert';

import 'package:banay/component/live/live_overlay_widgets.dart';
import 'package:livekit_client/livekit_client.dart';

/// Someone watching a live, as read from the LiveKit room. The backend puts
/// the display name in the viewer token's `name` and `{userId, avatarUrl}`
/// in its metadata (see `getSellerLiveJoinInfo`), so listing who is watching
/// costs no request and follows joins and leaves through the room's own
/// events.
class LiveViewer {
  const LiveViewer({
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.isMe,
  });

  final String userId;
  final String name;
  final String avatarUrl;

  /// The local user, when they are a viewer (never on the host screen).
  final bool isMe;
}

const String _viewerIdentityPrefix = 'viewer-';

/// Viewers currently in [room]: the local user first when they are one,
/// then by name. One entry per user even when they watch from two phones
/// (the identity is unique per join, the user id is not). The host
/// (`seller-<id>`) is never listed.
List<LiveViewer> liveViewersOf(Room room) {
  final byUser = <String, LiveViewer>{};

  void add(Participant participant, {required bool isMe}) {
    final viewer = _viewerFrom(participant, isMe: isMe);
    if (viewer == null) {
      return;
    }
    final existing = byUser[viewer.userId];
    if (existing == null || (isMe && !existing.isMe)) {
      byUser[viewer.userId] = viewer;
    }
  }

  final local = room.localParticipant;
  if (local != null) {
    add(local, isMe: true);
  }
  for (final participant in room.remoteParticipants.values) {
    add(participant, isMe: false);
  }

  return byUser.values.toList()..sort((a, b) {
    if (a.isMe != b.isMe) {
      return a.isMe ? -1 : 1;
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
}

/// The feed line for [participant] entering the room ("X a rejoint le
/// live"), or null when it is not a viewer (the host, or an unreadable
/// identity). Built on every phone from the room's own participant events:
/// nothing travels over the data channel for it.
LiveCommentEntry? liveJoinCommentFor(Participant participant) =>
    _systemCommentFor(participant, kind: 'join', message: 'a rejoint le live');

/// Same line for a viewer leaving ("X a quitté le live"). A phone whose
/// link dropped for good shows it too, then "a rejoint" if it comes back.
LiveCommentEntry? liveLeaveCommentFor(Participant participant) =>
    _systemCommentFor(participant, kind: 'leave', message: 'a quitté le live');

LiveCommentEntry? _systemCommentFor(
  Participant participant, {
  required String kind,
  required String message,
}) {
  final viewer = _viewerFrom(participant, isMe: false);
  if (viewer == null) {
    return null;
  }
  return LiveCommentEntry(
    id: '$kind-${participant.identity}-${DateTime.now().microsecondsSinceEpoch}',
    author: viewer.name,
    message: message,
    avatarUrl: viewer.avatarUrl,
    userId: viewer.userId,
    isSystem: true,
  );
}

LiveViewer? _viewerFrom(Participant participant, {required bool isMe}) {
  final identity = participant.identity;
  if (!identity.startsWith(_viewerIdentityPrefix)) {
    return null;
  }

  var userId = '';
  var avatarUrl = '';
  final metadata = participant.metadata?.trim() ?? '';
  if (metadata.isNotEmpty) {
    try {
      final decoded = jsonDecode(metadata);
      if (decoded is Map) {
        userId = decoded['userId']?.toString().trim() ?? '';
        avatarUrl = decoded['avatarUrl']?.toString().trim() ?? '';
      }
    } catch (_) {
      // Not our JSON: fall back to the identity below.
    }
  }
  if (userId.isEmpty) {
    // `viewer-<userId>-<joinedAtMs>`: the id (a UUID, dashes included) is
    // everything before the last dash.
    final rest = identity.substring(_viewerIdentityPrefix.length);
    final cut = rest.lastIndexOf('-');
    userId = cut > 0 ? rest.substring(0, cut) : rest;
  }
  if (userId.isEmpty) {
    return null;
  }

  var name = participant.name.trim();
  // Tokens issued before 2026-09-13 carried `viewer-<userId>` as the name.
  if (name.isEmpty || name.startsWith(_viewerIdentityPrefix)) {
    name = 'Spectateur';
  }

  return LiveViewer(
    userId: userId,
    name: name,
    avatarUrl: avatarUrl,
    isMe: isMe,
  );
}
