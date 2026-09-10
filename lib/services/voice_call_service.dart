import 'dart:async';

import 'package:banay/page/call/voice_call_page.dart';
import 'package:banay/services/app_api_client.dart';
import 'package:banay/services/call_tones.dart';
import 'package:banay/services/calls_api_service.dart';
import 'package:banay/services/chat_realtime_service.dart';
import 'package:banay/services/incoming_call_native_ui.dart';
import 'package:banay/services/push_notification_service.dart';
import 'package:banay/services/ringer_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

enum VoiceCallPhase { ringing, connecting, active, ended }

enum VoiceCallEndReason {
  ended,
  declined,
  missed,
  cancelled,
  busy,
  failed,
  disconnected,
  noPermission,
}

/// Link quality as reported by the SFU for the other side, shown to the
/// user so a choppy call is understood as "their network", not "the app".
enum VoiceCallQuality { unknown, excellent, good, poor, lost }

/// Snapshot of the one call the app can be in; `null` when idle.
class VoiceCallSession {
  const VoiceCallSession({
    required this.callId,
    required this.conversationId,
    required this.peerName,
    required this.peerAvatarUrl,
    required this.isOutgoing,
    required this.phase,
    this.peerUserId,
    this.connectedAt,
    this.endReason,
    this.endMessage,
    this.isMuted = false,
    this.isSpeakerOn = false,
    this.isReconnecting = false,
    this.quality = VoiceCallQuality.unknown,
    this.peerReached = false,
  });

  /// Empty while the outgoing call is being created on the server.
  final String callId;
  final String conversationId;
  final String? peerUserId;
  final String peerName;
  final String peerAvatarUrl;
  final bool isOutgoing;
  final VoiceCallPhase phase;
  final DateTime? connectedAt;
  final VoiceCallEndReason? endReason;

  /// Server-provided text for `busy` / `failed` (e.g. "X est déjà en appel").
  final String? endMessage;
  final bool isMuted;
  final bool isSpeakerOn;

  /// LiveKit is re-establishing the connection after a network cut.
  final bool isReconnecting;
  final VoiceCallQuality quality;

  /// Outgoing only: the other phone confirmed the invitation reached it
  /// and rings ("Appel…" → "Appel en cours…").
  final bool peerReached;

  bool get isEnded => phase == VoiceCallPhase.ended;

  Duration get elapsed {
    final startedAt = connectedAt;
    if (startedAt == null) {
      return Duration.zero;
    }
    return DateTime.now().difference(startedAt);
  }

  VoiceCallSession copyWith({
    String? callId,
    VoiceCallPhase? phase,
    DateTime? connectedAt,
    VoiceCallEndReason? endReason,
    String? endMessage,
    bool? isMuted,
    bool? isSpeakerOn,
    bool? isReconnecting,
    VoiceCallQuality? quality,
    bool? peerReached,
  }) {
    return VoiceCallSession(
      callId: callId ?? this.callId,
      conversationId: conversationId,
      peerUserId: peerUserId,
      peerName: peerName,
      peerAvatarUrl: peerAvatarUrl,
      isOutgoing: isOutgoing,
      phase: phase ?? this.phase,
      connectedAt: connectedAt ?? this.connectedAt,
      endReason: endReason ?? this.endReason,
      endMessage: endMessage ?? this.endMessage,
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      isReconnecting: isReconnecting ?? this.isReconnecting,
      quality: quality ?? this.quality,
      peerReached: peerReached ?? this.peerReached,
    );
  }
}

/// WhatsApp-style voice calls on top of what the app already has: the
/// backend's `calls:updated` realtime events for signalling, a push to wake
/// the callee, the phone's native call UI when the app is not on screen,
/// and a LiveKit audio-only room for the sound.
///
/// One session at a time; [session] drives `VoiceCallPage`, which is pushed
/// on the root navigator whenever a call starts or rings.
class VoiceCallService {
  VoiceCallService._();

  static final VoiceCallService instance = VoiceCallService._();

  static const Duration _ringTimeout = IncomingCallNativeUi.ringWindow;
  static const Duration _endedScreenDelay = Duration(milliseconds: 1600);
  static const Duration _vibrationInterval = Duration(milliseconds: 1500);

  final ValueNotifier<VoiceCallSession?> session =
      ValueNotifier<VoiceCallSession?>(null);
  final CallsApiService _api = CallsApiService();

  StreamSubscription<Map<String, dynamic>>? _eventsSubscription;
  StreamSubscription<CallEvent?>? _nativeEventsSubscription;
  Room? _room;
  EventsListener<RoomEvent>? _roomEvents;
  Timer? _ringTimer;
  Timer? _vibrationTimer;
  Timer? _closeTimer;
  bool _pageOpen = false;
  bool _abortPendingStart = false;
  String? _lastIncomingCallId;

  /// A `call:ringing` that arrived before the start request returned the
  /// call id (the callee can be faster than our own HTTP round-trip).
  String? _earlyRingingAckCallId;

  bool _bound = false;

  /// Idempotent; called once the user is signed in and the socket is up,
  /// and again by every entry point so a session that started before this
  /// code existed (hot reload) still gets its event subscriptions. Also
  /// picks up a call the user accepted on the native UI while the app was
  /// killed (the OS launched us for it).
  void bind() {
    _eventsSubscription ??= ChatRealtimeService.instance.events.listen(
      _handleRealtimeEvent,
    );
    _nativeEventsSubscription ??= FlutterCallkitIncoming.onEvent.listen(
      _handleNativeEvent,
      onError: (Object error) => debugPrint('Native call events: $error'),
    );
    if (!_bound) {
      _bound = true;
      unawaited(_reconcileNativeCalls());
    }
  }

  bool get isInCall {
    final current = session.value;
    return current != null && !current.isEnded;
  }

  // ---------------------------------------------------------------------
  // Outgoing
  // ---------------------------------------------------------------------

  /// Opens the call screen at once and rings the other side of
  /// [conversationId]. Throws [AppApiException] when the microphone is
  /// refused; every other failure is shown on the call screen itself.
  Future<void> startCall({
    required String conversationId,
    required String peerName,
    required String peerAvatarUrl,
    String? peerUserId,
  }) async {
    bind();
    if (isInCall) {
      _openPage();
      return;
    }
    if (!await _ensureMicrophonePermission()) {
      throw AppApiException(
        'Autorisez le microphone pour passer un appel vocal.',
      );
    }

    _cancelCloseTimer();
    _abortPendingStart = false;
    _earlyRingingAckCallId = null;
    session.value = VoiceCallSession(
      callId: '',
      conversationId: conversationId,
      peerUserId: peerUserId,
      peerName: peerName,
      peerAvatarUrl: peerAvatarUrl,
      isOutgoing: true,
      phase: VoiceCallPhase.connecting,
    );
    _openPage();

    Map<String, dynamic> data;
    try {
      data = await _api.startCall(conversationId: conversationId);
    } on AppApiException catch (error) {
      _finish(
        error.statusCode == 409
            ? VoiceCallEndReason.busy
            : VoiceCallEndReason.failed,
        message: error.message,
      );
      return;
    } catch (_) {
      _finish(VoiceCallEndReason.failed);
      return;
    }

    final callId = data['callId']?.toString() ?? '';
    if (_abortPendingStart || !isInCall) {
      // Hung up while the server was still creating the call.
      if (callId.isNotEmpty) {
        unawaited(_quietly(_api.endCall(callId)));
      }
      return;
    }

    final reachedAlready = _earlyRingingAckCallId == callId;
    _earlyRingingAckCallId = null;
    _update(
      (s) => s.copyWith(
        callId: callId,
        phase: VoiceCallPhase.ringing,
        peerReached: reachedAlready,
      ),
    );
    _startRingTimer();
    // Ringback in the caller's ear until the other side answers (stopped
    // by _markActive) or the call ends (_finish).
    unawaited(
      CallTones.instance.startRingback(
        speakerOn: session.value?.isSpeakerOn ?? false,
      ),
    );
    try {
      await _connectRoom(
        data['url']?.toString() ?? '',
        data['token']?.toString() ?? '',
      );
    } catch (error) {
      debugPrint('Voice call room connect failed: $error');
      _finish(VoiceCallEndReason.failed);
      unawaited(_quietly(_api.endCall(callId)));
    }
  }

  // ---------------------------------------------------------------------
  // Incoming
  // ---------------------------------------------------------------------

  /// Data-only FCM message received while the app is in the foreground.
  void handleIncomingPush(Map<String, dynamic> data) {
    bind();
    _handleIncoming(
      callId: data['callId']?.toString() ?? '',
      conversationId: data['conversationId']?.toString() ?? '',
      callerName: data['callerName']?.toString() ?? '',
      callerAvatarUrl: data['callerAvatarUrl']?.toString() ?? '',
    );
  }

  void handleCallCancelledPush(String callId) {
    final current = session.value;
    if (current != null &&
        current.callId == callId &&
        !current.isOutgoing &&
        current.phase == VoiceCallPhase.ringing) {
      _finish(VoiceCallEndReason.cancelled);
    }
    unawaited(IncomingCallNativeUi.dismiss(callId));
  }

  /// Tap on an iOS alert, or a native call to pick up after a cold start:
  /// shows the call if it still rings, otherwise takes the tile down.
  Future<void> openIncomingCall(String callId) async {
    bind();
    final current = session.value;
    if (current != null && current.callId == callId && !current.isEnded) {
      _openPage();
      return;
    }

    try {
      final data = await _api.fetchCall(callId);
      if (data['status']?.toString() != 'RINGING') {
        await IncomingCallNativeUi.dismiss(callId);
        return;
      }
      final caller = data['caller'];
      final callerMap = caller is Map
          ? Map<String, dynamic>.from(caller)
          : const <String, dynamic>{};
      _handleIncoming(
        callId: callId,
        conversationId: data['conversationId']?.toString() ?? '',
        callerUserId: callerMap['id']?.toString(),
        callerName: callerMap['displayName']?.toString() ?? '',
        callerAvatarUrl: callerMap['avatarUrl']?.toString() ?? '',
        // The native UI is already up (that is how we got here).
        showNativeUi: false,
      );
    } catch (error) {
      debugPrint('Unable to open incoming call $callId: $error');
    }
  }

  void _handleRealtimeEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString() ?? '';
    if (!type.startsWith('call:')) {
      return;
    }
    final callId = event['callId']?.toString() ?? '';
    final current = session.value;

    switch (type) {
      case 'call:incoming':
        final caller = event['caller'];
        final callerMap = caller is Map
            ? Map<String, dynamic>.from(caller)
            : const <String, dynamic>{};
        _handleIncoming(
          callId: callId,
          conversationId: event['conversationId']?.toString() ?? '',
          callerUserId: callerMap['id']?.toString(),
          callerName: callerMap['displayName']?.toString() ?? '',
          callerAvatarUrl: callerMap['avatarUrl']?.toString() ?? '',
        );
      case 'call:ringing':
        if (current != null && current.isOutgoing && !current.isEnded) {
          if (current.callId == callId) {
            _update((s) => s.copyWith(peerReached: true));
          } else if (current.callId.isEmpty) {
            _earlyRingingAckCallId = callId;
          }
        }
      case 'call:accepted':
        if (current != null && current.callId == callId && current.isOutgoing) {
          _markActive();
        }
      case 'call:ended':
        if (current != null && current.callId == callId) {
          _finish(_reasonFromServer(event['reason']?.toString()));
        } else {
          unawaited(IncomingCallNativeUi.dismiss(callId));
        }
    }
  }

  void _handleIncoming({
    required String callId,
    required String conversationId,
    required String callerName,
    required String callerAvatarUrl,
    String? callerUserId,
    bool showNativeUi = true,
  }) {
    // The socket, the push and the native UI all announce the same call.
    if (callId.isEmpty || _lastIncomingCallId == callId) {
      return;
    }
    // Already on a call: the server rings the caller out on its own.
    if (isInCall) {
      return;
    }

    _lastIncomingCallId = callId;
    _cancelCloseTimer();
    session.value = VoiceCallSession(
      callId: callId,
      conversationId: conversationId,
      peerUserId: callerUserId,
      peerName: callerName.trim().isNotEmpty ? callerName.trim() : 'Appel',
      peerAvatarUrl: callerAvatarUrl,
      isOutgoing: false,
      phase: VoiceCallPhase.ringing,
    );
    _startRingTimer();
    // Tell the caller the invitation reached this phone; the background
    // isolate does the same when it puts the native screen up first.
    unawaited(_quietly(_api.markRinging(callId)));

    _openPage();
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      // On screen: our own page rings and vibrates, as the phone allows.
      unawaited(_startIncomingAlert(callId));
    } else if (showNativeUi) {
      // Backgrounded: the OS call UI rings (full screen, lock screen,
      // ringtone) unless the background isolate already put it up.
      unawaited(
        _showNativeIncomingIfAbsent(
          callId: callId,
          conversationId: conversationId,
          callerName: callerName,
          callerAvatarUrl: callerAvatarUrl,
          callerUserId: callerUserId ?? '',
        ),
      );
    }
  }

  Future<void> _showNativeIncomingIfAbsent({
    required String callId,
    required String conversationId,
    required String callerName,
    required String callerAvatarUrl,
    required String callerUserId,
  }) async {
    final active = await IncomingCallNativeUi.activeCalls();
    final alreadyShown = active.any(
      (call) => IncomingCallNativeUi.callIdOf(call) == callId,
    );
    if (alreadyShown || session.value?.callId != callId) {
      return;
    }
    await IncomingCallNativeUi.show(
      callId: callId,
      conversationId: conversationId,
      callerName: callerName,
      callerAvatarUrl: callerAvatarUrl,
      callerUserId: callerUserId,
    );
  }

  /// Native UI events (Android call screen, iOS CallKit).
  void _handleNativeEvent(CallEvent? event) {
    switch (event) {
      case CallEventActionCallAccept(:final callKitParams):
        unawaited(_acceptFromNative(IncomingCallNativeUi.callIdOf(callKitParams)));
      case CallEventActionCallDecline(:final callKitParams):
        final callId = IncomingCallNativeUi.callIdOf(callKitParams);
        if (session.value?.callId == callId) {
          unawaited(decline());
        } else {
          unawaited(_quietly(_api.declineCall(callId)));
        }
      case CallEventActionCallEnded(:final callKitParams):
        final callId = IncomingCallNativeUi.callIdOf(callKitParams);
        if (session.value?.callId == callId && isInCall) {
          unawaited(hangUp());
        }
      case CallEventActionCallTimeout(:final id):
        final current = session.value;
        if (current != null &&
            current.callId == id &&
            current.phase == VoiceCallPhase.ringing) {
          _finish(VoiceCallEndReason.missed);
        }
      case CallEventActionCallToggleMute(:final id, :final isMuted):
        // iOS CallKit mute button.
        final current = session.value;
        if (current != null && current.callId == id && current.isMuted != isMuted) {
          unawaited(toggleMute());
        }
      default:
        break;
    }
  }

  /// Accept pressed on the OS UI: the app may have been killed, in which
  /// case the session has to be rebuilt from the server first.
  Future<void> _acceptFromNative(String callId) async {
    if (callId.isEmpty) {
      return;
    }
    final current = session.value;
    if (current == null || current.callId != callId || current.isEnded) {
      await openIncomingCall(callId);
    }
    final rebuilt = session.value;
    if (rebuilt != null &&
        rebuilt.callId == callId &&
        !rebuilt.isOutgoing &&
        rebuilt.phase == VoiceCallPhase.ringing) {
      await accept();
    }
  }

  /// Cold start after "Accepter" on the native UI: the OS remembers the
  /// accepted call, the server still holds it as ringing.
  Future<void> _reconcileNativeCalls() async {
    final calls = await IncomingCallNativeUi.activeCalls();
    for (final call in calls) {
      final callId = IncomingCallNativeUi.callIdOf(call);
      if (callId.isEmpty) {
        continue;
      }
      if (call.isAccepted) {
        await _acceptFromNative(callId);
      } else {
        await openIncomingCall(callId);
      }
    }
  }

  Future<void> accept() async {
    final current = session.value;
    if (current == null ||
        current.isOutgoing ||
        current.phase != VoiceCallPhase.ringing) {
      return;
    }

    _stopVibration();
    unawaited(CallTones.instance.stop());
    _cancelRingTimer();
    _openPage();

    if (!await _ensureMicrophonePermission()) {
      _finish(VoiceCallEndReason.noPermission);
      unawaited(_quietly(_api.declineCall(current.callId)));
      return;
    }

    _update((s) => s.copyWith(phase: VoiceCallPhase.connecting));
    try {
      final data = await _api.acceptCall(current.callId);
      await _connectRoom(
        data['url']?.toString() ?? '',
        data['token']?.toString() ?? '',
      );
      _markActive();
    } on AppApiException catch (error) {
      _finish(VoiceCallEndReason.failed, message: error.message);
    } catch (error) {
      debugPrint('Voice call accept failed: $error');
      _finish(VoiceCallEndReason.failed);
    }
  }

  Future<void> decline() async {
    final current = session.value;
    if (current == null || current.isOutgoing || current.isEnded) {
      return;
    }
    _finish(VoiceCallEndReason.declined);
    unawaited(_quietly(_api.declineCall(current.callId)));
  }

  /// Cancels a ringing call, ends an active one.
  Future<void> hangUp() async {
    final current = session.value;
    if (current == null || current.isEnded) {
      return;
    }
    if (current.callId.isEmpty) {
      _abortPendingStart = true;
      _finish(VoiceCallEndReason.cancelled);
      return;
    }

    final reason = switch (current.phase) {
      VoiceCallPhase.active => VoiceCallEndReason.ended,
      _ =>
        current.isOutgoing
            ? VoiceCallEndReason.cancelled
            : VoiceCallEndReason.declined,
    };
    _finish(reason);
    unawaited(_quietly(_api.endCall(current.callId)));
  }

  Future<void> toggleMute() async {
    final current = session.value;
    if (current == null || current.isEnded) {
      return;
    }
    final next = !current.isMuted;
    _update((s) => s.copyWith(isMuted: next));
    await _room?.localParticipant?.setMicrophoneEnabled(!next);
  }

  Future<void> toggleSpeaker() async {
    final current = session.value;
    if (current == null || current.isEnded) {
      return;
    }
    final next = !current.isSpeakerOn;
    _update((s) => s.copyWith(isSpeakerOn: next));
    try {
      await Hardware.instance.setSpeakerphoneOn(next);
    } catch (error) {
      debugPrint('Speakerphone toggle failed: $error');
    }
  }

  // ---------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------

  void _markActive() {
    _cancelRingTimer();
    _stopVibration();
    unawaited(CallTones.instance.stop());
    final current = session.value;
    _update(
      (s) => s.copyWith(
        phase: VoiceCallPhase.active,
        connectedAt: DateTime.now(),
      ),
    );
    unawaited(WakelockPlus.enable());
    if (current != null && !current.isOutgoing) {
      unawaited(IncomingCallNativeUi.markConnected(current.callId));
    }
  }

  /// Single exit path: freezes the screen on the outcome for a moment, then
  /// clears the session (which closes the page).
  void _finish(VoiceCallEndReason reason, {String? message}) {
    final current = session.value;
    if (current == null || current.isEnded) {
      return;
    }

    _cancelRingTimer();
    _stopVibration();
    unawaited(CallTones.instance.stop());
    unawaited(CallTones.instance.playEndCall(speakerOn: current.isSpeakerOn));
    unawaited(_disconnectRoom());
    unawaited(WakelockPlus.disable());
    if (current.callId.isNotEmpty) {
      unawaited(IncomingCallNativeUi.dismiss(current.callId));
    }

    session.value = current.copyWith(
      phase: VoiceCallPhase.ended,
      endReason: reason,
      endMessage: message,
      isReconnecting: false,
    );
    _closeTimer = Timer(_endedScreenDelay, () {
      _closeTimer = null;
      if (session.value?.isEnded ?? false) {
        session.value = null;
      }
    });
  }

  VoiceCallEndReason _reasonFromServer(String? reason) => switch (reason) {
    'declined' => VoiceCallEndReason.declined,
    'missed' => VoiceCallEndReason.missed,
    'cancelled' => VoiceCallEndReason.cancelled,
    _ => VoiceCallEndReason.ended,
  };

  Future<void> _connectRoom(String url, String token) async {
    if (url.isEmpty || token.isEmpty) {
      throw StateError('Missing LiveKit credentials for the call');
    }
    await _disconnectRoom();

    // Audio only, tuned for Malagasy mobile links: Opus at 24 kb/s with DTX
    // (nothing sent during silence), echo cancellation and noise
    // suppression on. About 10 MB per hour of talk.
    final room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultAudioCaptureOptions: AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        ),
        defaultAudioPublishOptions: AudioPublishOptions(
          dtx: true,
          audioBitrate: AudioPreset.speech,
        ),
      ),
    );
    _room = room;
    _roomEvents = room.createListener()
      ..on<ParticipantConnectedEvent>((_) {
        // The other side is in the room: the call is live even if the
        // socket's `call:accepted` never arrived (socket down or late).
        // Without this, the ring timer would cut a perfectly good call.
        final current = session.value;
        if (identical(_room, room) &&
            current != null &&
            current.isOutgoing &&
            current.phase == VoiceCallPhase.ringing) {
          _markActive();
        }
      })
      ..on<ParticipantDisconnectedEvent>((_) {
        // The other side vanished without hanging up (app killed, network
        // gone for good): end on our side so the call line gets written.
        if (identical(_room, room) &&
            session.value?.phase == VoiceCallPhase.active) {
          unawaited(hangUp());
        }
      })
      ..on<RoomReconnectingEvent>((_) {
        if (identical(_room, room)) {
          _update((s) => s.copyWith(isReconnecting: true));
        }
      })
      ..on<RoomReconnectedEvent>((_) {
        if (identical(_room, room)) {
          _update((s) => s.copyWith(isReconnecting: false));
        }
      })
      ..on<ParticipantConnectionQualityUpdatedEvent>((event) {
        if (identical(_room, room) && event.participant is RemoteParticipant) {
          _update(
            (s) => s.copyWith(quality: _mapQuality(event.connectionQuality)),
          );
        }
      })
      ..on<RoomDisconnectedEvent>((_) {
        if (identical(_room, room) && isInCall) {
          _finish(VoiceCallEndReason.disconnected);
        }
      });

    await room.connect(url, token);
    await room.localParticipant?.setMicrophoneEnabled(
      !(session.value?.isMuted ?? false),
    );
    try {
      await Hardware.instance.setSpeakerphoneOn(
        session.value?.isSpeakerOn ?? false,
      );
    } catch (_) {
      // Desktop / unsupported: the default output is fine.
    }
  }

  VoiceCallQuality _mapQuality(ConnectionQuality quality) => switch (quality) {
    ConnectionQuality.excellent => VoiceCallQuality.excellent,
    ConnectionQuality.good => VoiceCallQuality.good,
    ConnectionQuality.poor => VoiceCallQuality.poor,
    ConnectionQuality.lost => VoiceCallQuality.lost,
    ConnectionQuality.unknown => VoiceCallQuality.unknown,
  };

  Future<void> _disconnectRoom() async {
    final room = _room;
    final events = _roomEvents;
    _room = null;
    _roomEvents = null;
    if (events != null) {
      await events.dispose();
    }
    if (room != null) {
      try {
        await room.disconnect();
      } catch (_) {
        // Already gone.
      }
      await room.dispose();
    }
  }

  Future<bool> _ensureMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  void _openPage() {
    if (_pageOpen) {
      return;
    }
    final navigator = PushNotificationService.navigatorKey.currentState;
    if (navigator == null) {
      return;
    }
    _pageOpen = true;
    unawaited(
      navigator
          .push(
            MaterialPageRoute<void>(
              fullscreenDialog: true,
              builder: (_) => const VoiceCallPage(),
            ),
          )
          .whenComplete(() => _pageOpen = false),
    );
  }

  void _startRingTimer() {
    _cancelRingTimer();
    _ringTimer = Timer(_ringTimeout, () {
      _ringTimer = null;
      final current = session.value;
      if (current != null && current.phase == VoiceCallPhase.ringing) {
        _finish(VoiceCallEndReason.missed);
        if (current.callId.isNotEmpty) {
          unawaited(_quietly(_api.endCall(current.callId)));
        }
      }
    });
  }

  void _cancelRingTimer() {
    _ringTimer?.cancel();
    _ringTimer = null;
  }

  /// Ringtone and vibration for an incoming call shown in the app, exactly
  /// as the phone is set: normal → both, vibrate → vibration only, silent →
  /// nothing but the screen. Real ring-style vibration (long buzz, pause)
  /// when the device has a vibrator, a haptic tick otherwise.
  Future<void> _startIncomingAlert(String callId) async {
    final mode = await currentRingerMode();
    final current = session.value;
    if (current == null ||
        current.callId != callId ||
        current.phase != VoiceCallPhase.ringing) {
      return;
    }
    if (mode == RingerMode.silent) {
      return;
    }
    if (mode != RingerMode.vibrate) {
      unawaited(CallTones.instance.startRingtone());
    }
    await _startVibration();
  }

  Future<void> _startVibration() async {
    _stopVibration();
    bool hasVibrator = false;
    try {
      hasVibrator = await Vibration.hasVibrator();
    } catch (_) {
      hasVibrator = false;
    }
    if (session.value?.phase != VoiceCallPhase.ringing) {
      return;
    }
    if (hasVibrator) {
      try {
        // 0 ms wait, 900 ms buzz, 1100 ms pause, repeated from the start.
        // Explicit intensities: the default "-1" amplitude is rejected by
        // some vibrator HALs (seen on the Android emulator).
        await Vibration.vibrate(
          pattern: const [0, 900, 1100],
          intensities: const [0, 255, 0],
          repeat: 0,
        );
        return;
      } catch (error) {
        debugPrint('Ring vibration failed: $error');
      }
    }
    unawaited(HapticFeedback.vibrate());
    _vibrationTimer = Timer.periodic(_vibrationInterval, (_) {
      unawaited(HapticFeedback.vibrate());
    });
  }

  void _stopVibration() {
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    unawaited(_quietly(Vibration.cancel()));
  }

  void _cancelCloseTimer() {
    _closeTimer?.cancel();
    _closeTimer = null;
  }

  void _update(VoiceCallSession Function(VoiceCallSession) change) {
    final current = session.value;
    if (current != null) {
      session.value = change(current);
    }
  }

  Future<void> _quietly(Future<Object?> future) async {
    try {
      await future;
    } catch (error) {
      debugPrint('Voice call request failed: $error');
    }
  }
}
