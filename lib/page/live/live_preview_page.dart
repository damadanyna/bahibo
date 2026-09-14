import 'dart:async';

import 'package:banay/component/live/live_overlay_widgets.dart';
import 'package:banay/component/live/live_tap_hearts.dart';
import 'package:banay/component/live/live_viewers_sheet.dart';
import 'package:banay/component/ui/dinamic_icon_input.dart';
import 'package:banay/services/app_api_client.dart';
import 'package:banay/services/catalog_api_service.dart';
import 'package:banay/services/live/live_connect_options.dart';
import 'package:banay/services/live/live_room_channel.dart';
import 'package:banay/services/live/live_viewers.dart';
import 'package:banay/theme/app_theme_extensions.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class LivePreviewPage extends StatefulWidget {
  const LivePreviewPage({
    super.key,
    required this.title,
    required this.category,
    required this.liveUrl,
    required this.liveToken,
    required this.roomName,
    this.sellerName,
    this.sellerAvatarUrl,
  });

  final String title;
  final String category;
  final String liveUrl;
  final String liveToken;
  final String roomName;

  /// Host identity shown in the top-left card; falls back to [title] / a
  /// storefront icon when the caller has no profile at hand.
  final String? sellerName;
  final String? sellerAvatarUrl;

  @override
  State<LivePreviewPage> createState() => _LivePreviewPageState();
}

class _LivePreviewPageState extends State<LivePreviewPage>
    with SingleTickerProviderStateMixin {
  static const List<String> _quickEmojis = [
    '😀',
    '😍',
    '🔥',
    '👏',
    '❤️',
    '👍',
    '🎉',
    '😂',
    '😮',
    '🙏',
    '🥰',
    '💯',
  ];

  static const int _maxKeptComments = 200;

  late final Room _room;
  late final TextEditingController _commentController;
  final List<LiveCommentEntry> _liveComments = <LiveCommentEntry>[];
  late final AnimationController _livePulseController;
  LiveRoomChannel? _channel;
  StreamSubscription<LiveCommentEntry>? _commentsSubscription;
  EventsListener<RoomEvent>? _roomEvents;
  StreamSubscription<int>? _likesSubscription;
  int _likeCount = 0;
  final LiveTapHeartsController _heartsController = LiveTapHeartsController();

  // "Still broadcasting" pings: the server closes a live after 90 s without
  // one, so a host whose data ran out does not stay "en direct" for days.
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  final CatalogApiService _catalogApiService = CatalogApiService();
  Timer? _heartbeatTimer;
  bool _liveClosedByServer = false;

  // Debug builds only: one console line every few seconds with what the
  // uplink really carries per layer, so a "not sharp" report reads as
  // "h 1080x1920 at 1.4 Mb/s, bandwidth-limited" instead of a guess. The
  // SDK already polls sender stats every 2 s; this only listens.
  EventsListener<TrackEvent>? _senderStatsEvents;
  LocalVideoTrack? _senderStatsTrack;
  DateTime? _senderStatsLoggedAt;
  static const Duration _senderStatsLogInterval = Duration(seconds: 6);

  bool _isConnecting = true;
  bool _isLive = false;
  bool _isPaused = false;
  bool _isMuted = false;
  bool _isCameraEnabled = true;
  // Rear camera first: a live shows the shop and the goods, and the main
  // sensor is larger and less noisy than the selfie one (noise costs bits
  // that the 1080p layer does not have on 4G). The switch button remains.
  CameraPosition _cameraPosition = CameraPosition.back;
  String? _errorMessage;

  // 1080p capture (1920x1080, sent as 1080x1920 in portrait). The viewer
  // draws it full-screen with VideoViewFit.cover: a 1.25x upscale with the
  // sides cropped on a 1080x2400 panel, 1.6x on 1440x3088. More pixels than
  // this would not be visible on these screens; what decides sharpness is
  // the bitrate the uplink leaves to this layer (see _videoPublishOptions).
  // A front camera that stops at 720p falls back to its best format; the
  // layer below is derived from what the camera gives.
  CameraCaptureOptions get _cameraCaptureOptions => CameraCaptureOptions(
    cameraPosition: _cameraPosition,
    params: VideoParametersPresets.h1080_169,
    maxFrameRate: 30,
  );

  static const VideoPublishOptions _videoPublishOptions = VideoPublishOptions(
    // H.264: MediaCodec hardware encoding on any Android 10+ chip (older
    // Android: Qualcomm / Exynos only); libwebrtc ships no software H.264
    // encoder. The SDK negotiates Constrained Baseline; High profile is not
    // reachable from Dart.
    videoCodec: 'h264',
    // Ceiling of the 1080p layer, reached by a host on Wi-Fi, fibre or 5G
    // (~1.8 GB per hour for a viewer who gets it). On 4G the encoder
    // follows the uplink estimate below it. 4 Mb/s is the 1080p range of
    // TikTok LIVE Studio and of LiveKit's own egress preset; 2.5 Mb/s
    // (0.04 bit per pixel) was visibly soft even when fully fed.
    videoEncoding: VideoEncoding(maxBitrate: 4000 * 1000, maxFramerate: 30),
    // Two layers, not three. libwebrtc's simulcast allocator serves the
    // lower layers' targets first and gives the top layer only what is
    // left. With 360p 400 kb/s + 720p 1.2 Mb/s below it, the 1080p layer
    // switched on at 2.4 Mb/s of uplink but was encoded at uplink minus
    // 1.6 Mb/s: 0.8 to 1.4 Mb/s on a 2.4 to 3 Mb/s 4G link, and the SFU
    // forwarded that starved 1080p to every viewer, worse than the 720p it
    // replaced. The QP quality scaler is off in simulcast, so a starved
    // layer never downsizes itself. With a single 540p layer at 700 kb/s
    // the 1080p layer switches on at 1.5 Mb/s (1.66 when it comes back
    // after a dip) and gets uplink minus 0.7 Mb/s: 1.8 Mb/s at 2.5, 3.3 at
    // 4; the phone runs two encoders instead of three. 540p is what the
    // SFU serves when it measures that a viewer's downlink cannot carry the
    // 1080p layer (2.5x on a 1080-wide screen); 30 fps so the step down
    // keeps the same motion.
    simulcast: true,
    videoSimulcastLayers: [
      VideoParameters(
        dimensions: VideoDimensionsPresets.h540_169,
        encoding: VideoEncoding(maxBitrate: 700 * 1000, maxFramerate: 30),
      ),
    ],
    // No VP8 backup track: every phone decodes H.264, and the backup would
    // start a second 1080p simulcast encode on the host the moment one
    // subscriber declined H.264, doubling the uplink and CPU cost.
    backupVideoCodec: BackupVideoCodec(enabled: false),
    // In simulcast this only answers CPU overuse (a bandwidth shortfall is
    // handled by pausing the top layer): balanced shrinks the source, and
    // with it both layers, rather than only dropping frames.
    degradationPreference: DegradationPreference.balanced,
  );

  // Opus at 64 kb/s, sent continuously. The SDK default (48 kb/s with DTX)
  // is a call profile: DTX stops sending during pauses and the viewer's
  // decoder fills them with comfort noise, so the shop's room tone switches
  // on and off with every sentence — the "phone call" feel. 64 kb/s mono is
  // transparent for voice and leaves room for music playing in the shop.
  // ~30 MB per hour more than the default for a viewer.
  //
  // Capture stays on the SDK's call profile (echo cancellation, noise
  // suppression, gain control): flutter_webrtc opens one audio device for
  // the whole process, shared with voice calls, and only a global
  // "bypass voice processing" flag at app start changes it — which would
  // also strip echo cancellation from calls. The high-pass filter is the
  // one per-track addition: it cuts the rumble of a hand-held phone.
  static const AudioPublishOptions _audioPublishOptions = AudioPublishOptions(
    dtx: false,
    audioBitrate: 64 * 1000,
  );
  static const AudioCaptureOptions _audioCaptureOptions = AudioCaptureOptions(
    highPassFilter: true,
  );

  @override
  void initState() {
    super.initState();
    // A host does not touch the screen for minutes at a time: never let the
    // system dim or lock it mid-broadcast.
    unawaited(WakelockPlus.enable());
    _room = Room(
      roomOptions: RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultCameraCaptureOptions: _cameraCaptureOptions,
        defaultVideoPublishOptions: _videoPublishOptions,
        defaultAudioCaptureOptions: _audioCaptureOptions,
        defaultAudioPublishOptions: _audioPublishOptions,
      ),
    );
    // "X a rejoint le live" in the host's feed, from the room's own
    // participant events (viewers only: the identity filter is in
    // liveJoinCommentFor).
    _roomEvents = _room.createListener()
      ..on<ParticipantConnectedEvent>((event) {
        final entry = liveJoinCommentFor(event.participant);
        if (entry != null) {
          _appendComment(entry);
        }
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        // Only while connected: ending the live would otherwise announce
        // every viewer leaving at once.
        if (_room.connectionState != ConnectionState.connected) {
          return;
        }
        final entry = liveLeaveCommentFor(event.participant);
        if (entry != null) {
          _appendComment(entry);
        }
      });
    _commentController = TextEditingController();
    _livePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _room.addListener(_handleRoomChanged);
    unawaited(_connectAndPublish(initialLaunch: true));
  }

  @override
  void dispose() {
    unawaited(WakelockPlus.disable());
    _heartbeatTimer?.cancel();
    _commentController.dispose();
    _livePulseController.dispose();
    unawaited(_commentsSubscription?.cancel());
    unawaited(_likesSubscription?.cancel());
    unawaited(_channel?.dispose());
    unawaited(_roomEvents?.dispose());
    unawaited(_senderStatsEvents?.dispose());
    _room.removeListener(_handleRoomChanged);
    unawaited(_room.disconnect());
    _room.dispose();
    super.dispose();
  }

  /// Opens the comments / likes channel once the room is connected. Not
  /// awaited by the caller: resolving the identity must not delay going live.
  Future<void> _startChannel() async {
    if (_channel != null) {
      return;
    }

    final sellerName = widget.sellerName?.trim() ?? '';
    final channel = LiveRoomChannel(
      room: _room,
      isHost: true,
      authorName: sellerName.isNotEmpty ? sellerName : widget.title,
      authorAvatarUrl: widget.sellerAvatarUrl,
    );
    _channel = channel;
    _commentsSubscription = channel.comments.listen(_appendComment);
    _likesSubscription = channel.likes.listen((count) {
      if (mounted) {
        setState(() => _likeCount += count);
        _heartsController.celebrate(count);
      }
    });
    await channel.start();
  }

  void _appendComment(LiveCommentEntry entry) {
    if (!mounted) {
      return;
    }
    setState(() {
      _liveComments.insert(0, entry);
      if (_liveComments.length > _maxKeptComments) {
        _liveComments.removeRange(_maxKeptComments, _liveComments.length);
      }
    });
  }

  Future<void> _connectAndPublish({bool initialLaunch = false}) async {
    if (!initialLaunch && _isConnecting) {
      return;
    }

    if (mounted) {
      setState(() {
        _isConnecting = true;
        _errorMessage = null;
      });
    }

    try {
      final statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      if (statuses[Permission.camera] != PermissionStatus.granted ||
          statuses[Permission.microphone] != PermissionStatus.granted) {
        throw Exception(
          'Camera et microphone sont requis pour lancer un live.',
        );
      }

      if (_room.connectionState != ConnectionState.connected) {
        await _room.connect(
          widget.liveUrl,
          widget.liveToken,
          connectOptions: liveConnectOptions,
        );
      }

      await _room.localParticipant?.setCameraEnabled(
        true,
        cameraCaptureOptions: _cameraCaptureOptions,
      );
      await _room.localParticipant?.setMicrophoneEnabled(true);

      if (!mounted) {
        return;
      }

      _attachSenderStatsLog();
      unawaited(_startChannel());
      _startHeartbeat();
      _livePulseController.repeat(reverse: true);
      setState(() {
        _isConnecting = false;
        _isLive = true;
        _isPaused = false;
        _isMuted = false;
        _isCameraEnabled = true;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      _livePulseController.stop();
      setState(() {
        _isConnecting = false;
        _isLive = false;
        _errorMessage = error.toString();
      });
    }
  }

  void _handleRoomChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      _heartbeatInterval,
      (_) => unawaited(_sendHeartbeat()),
    );
  }

  Future<void> _sendHeartbeat() async {
    try {
      await _catalogApiService.heartbeatCurrentUserLive();
    } on AppApiException catch (error) {
      // 404: the server already closed this live (heartbeats missed while
      // offline, or a viewer found the room empty). Anything else is a
      // passing network error: the next ping will tell.
      if (error.statusCode == 404) {
        _handleLiveClosedByServer();
      }
    } catch (_) {
      // Offline right now; the server decides after three misses.
    }
  }

  /// The live no longer exists server-side: stop streaming into a room
  /// nobody can join any more and say so, with the exit as the only way out.
  void _handleLiveClosedByServer() {
    if (!mounted || _liveClosedByServer) {
      return;
    }
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _livePulseController.stop();
    unawaited(_room.disconnect());
    setState(() {
      _liveClosedByServer = true;
      _isLive = false;
      _isConnecting = false;
      _errorMessage =
          'Live interrompu : la connexion a été perdue trop longtemps. '
          'Relancez un live depuis l\'accueil.';
    });
  }

  LocalVideoTrack? _localVideoTrack() {
    final participant = _room.localParticipant;
    if (participant == null) {
      return null;
    }

    for (final publication in participant.videoTrackPublications) {
      final track = publication.track;
      if (track is LocalVideoTrack && !publication.muted) {
        return track;
      }
    }

    return null;
  }

  void _attachSenderStatsLog() {
    if (!kDebugMode) {
      return;
    }
    // Camera switch, pause and toggle restart the capture inside the same
    // track object; only a track that ended (camera taken by another app)
    // gets replaced by the SDK, and the listener then follows the new one.
    final track = _localVideoTrack();
    if (track == null || identical(track, _senderStatsTrack)) {
      return;
    }
    unawaited(_senderStatsEvents?.dispose());
    _senderStatsTrack = track;
    _senderStatsEvents = track.createListener()
      ..on<VideoSenderStatsEvent>(_logSenderStats);
  }

  void _logSenderStats(VideoSenderStatsEvent event) {
    final now = DateTime.now();
    final loggedAt = _senderStatsLoggedAt;
    if (loggedAt != null &&
        now.difference(loggedAt) < _senderStatsLogInterval) {
      return;
    }
    _senderStatsLoggedAt = now;

    String? encoder;
    num? roundTripTime;
    final layers = <String>[];
    for (final entry in event.stats.entries) {
      final stats = entry.value;
      encoder ??= stats.encoderImplementation;
      roundTripTime ??= stats.roundTripTime;
      final kbps = ((event.bitrateForLayers[entry.key] ?? 0) / 1000).round();
      layers.add(
        '${entry.key} ${stats.frameWidth?.toInt() ?? 0}x'
        '${stats.frameHeight?.toInt() ?? 0} '
        '${stats.framesPerSecond?.round() ?? 0}fps $kbps kb/s '
        '${stats.qualityLimitationReason ?? '-'}',
      );
    }
    final rttMs = roundTripTime == null ? '-' : (roundTripTime * 1000).round();
    debugPrint(
      'live uplink ${(event.currentBitrate / 1000).round()} kb/s, '
      'rtt $rttMs ms, ${encoder ?? '?'}: ${layers.join(' | ')}',
    );
  }

  Future<void> _switchCamera() async {
    final localTrack = _localVideoTrack();
    if (localTrack == null) {
      return;
    }

    final nextPosition = _cameraPosition.switched();
    await localTrack.setCameraPosition(nextPosition);

    if (mounted) {
      setState(() {
        _cameraPosition = nextPosition;
      });
    }
  }

  Future<void> _togglePauseLive() async {
    if (!_isLive) {
      return;
    }

    final nextPaused = !_isPaused;
    await _room.localParticipant?.setCameraEnabled(
      !nextPaused,
      cameraCaptureOptions: _cameraCaptureOptions,
    );

    if (!mounted) {
      return;
    }

    _attachSenderStatsLog();
    if (nextPaused) {
      _livePulseController.stop();
    } else {
      _livePulseController.repeat(reverse: true);
    }

    setState(() {
      _isPaused = nextPaused;
      _isCameraEnabled = !nextPaused;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nextPaused ? 'Le live est en pause.' : 'Le live a repris.',
        ),
      ),
    );
  }

  Future<void> _toggleMuteLive() async {
    if (!_isLive) {
      return;
    }

    final nextMuted = !_isMuted;
    await _room.localParticipant?.setMicrophoneEnabled(!nextMuted);

    if (!mounted) {
      return;
    }

    setState(() {
      _isMuted = nextMuted;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nextMuted ? 'Le micro est en muet.' : 'Le micro est reactif.',
        ),
      ),
    );
  }

  Future<void> _toggleCamera() async {
    final nextValue = !_isCameraEnabled;
    await _room.localParticipant?.setCameraEnabled(
      nextValue,
      cameraCaptureOptions: _cameraCaptureOptions,
    );

    if (!mounted) {
      return;
    }

    _attachSenderStatsLog();
    setState(() {
      _isCameraEnabled = nextValue;
      if (nextValue) {
        _isPaused = false;
        if (_isLive) {
          _livePulseController.repeat(reverse: true);
        }
      }
    });
  }

  Future<bool> _confirmExitLive() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);

        return AlertDialog(
          backgroundColor: theme.appColors.panelBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(_isLive ? 'Quitter le live ?' : 'Fermer la preview ?'),
          content: Text(
            _isLive
                ? 'Le live sera ferme pour toi. Veux-tu vraiment quitter maintenant ?'
                : 'Veux-tu fermer cette preview video ? ',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
              ),
              child: const Text('Quitter'),
            ),
          ],
        );
      },
    );

    return shouldExit ?? false;
  }

  Future<void> _handleExitRequested() async {
    final shouldExit = await _confirmExitLive();
    if (!mounted || !shouldExit) {
      return;
    }

    _livePulseController.stop();
    await _room.disconnect();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  Future<void> _submitComment(String text) async {
    final channel = _channel;
    if (text.trim().isEmpty || channel == null) {
      return;
    }

    // Clear right away, before the send round-trip, so the field is empty
    // on every send path (keyboard action and send icon alike).
    _commentController.clear();

    // Own messages are not echoed back by the room: append what was sent.
    final entry = await channel.sendComment(text);
    if (entry != null) {
      _appendComment(entry);
    }
  }

  Future<void> _showEmojiPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              decoration: BoxDecoration(
                color: theme.appColors.panelBackground,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.appColors.overlayBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Choisir un emoji',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _quickEmojis.map((emoji) {
                      return InkWell(
                        onTap: () {
                          final previousText = _commentController.text;
                          final nextText = '$previousText$emoji';
                          _commentController.value = TextEditingValue(
                            text: nextText,
                            selection: TextSelection.collapsed(
                              offset: nextText.length,
                            ),
                          );
                          Navigator.of(sheetContext).pop();
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Ink(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.appColors.overlayBorder,
                            ),
                          ),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final localTrack = _localVideoTrack();
    final previewReady =
        localTrack != null &&
        !_isConnecting &&
        _errorMessage == null &&
        !_isPaused;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        await _handleExitRequested();
      },
      child: Scaffold(
        backgroundColor: theme.appColors.viewerBackground,
        body: Stack(
          children: [
            Positioned.fill(
              child: previewReady
                  ? _buildCameraSurface(localTrack)
                  : Container(
                      color: theme.appColors.viewerBackground,
                      alignment: Alignment.center,
                      child: _buildFallback(),
                    ),
            ),
            const Positioned.fill(child: LiveOverlayScrim()),
            // The host does not tap to like: this layer only shows the
            // viewers' hearts rising from the corner.
            Positioned.fill(
              child: LiveTapHeartsLayer(controller: _heartsController),
            ),
            if (_isLive && _isPaused)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 22,
                      ),
                      decoration: BoxDecoration(
                        color: theme.appColors.overlaySurface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: theme.appColors.overlayBorder,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.pause_circle_filled_rounded,
                            color: theme.appColors.heroForeground,
                            size: 74,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Live en pause',
                            style: TextStyle(
                              color: theme.appColors.heroForeground,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LiveKit reconnects on its own after a cut; say so
                    // instead of leaving a frozen preview unexplained.
                    if (_isLive &&
                        _room.connectionState != ConnectionState.connected) ...[
                      _buildConnectionBanner(theme),
                      const SizedBox(height: 10),
                    ],
                    // Header: host identity + live state on the left, close
                    // on the right — mirrors what viewers see, from the host
                    // side.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildHostCard(theme)),
                        const SizedBox(width: 10),
                        _buildCloseButton(theme),
                      ],
                    ),
                    if (!isKeyboardOpen) ...[
                      const SizedBox(height: 14),
                      // Broadcast tools stay one tap away on a vertical rail
                      // instead of behind a settings toggle. Hidden while
                      // typing: the keyboard needs that height.
                      Align(
                        alignment: Alignment.centerRight,
                        child: _buildToolRail(theme),
                      ),
                    ],
                    // Takes whatever height is left and shrinks under the
                    // keyboard instead of overflowing the column.
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: _buildCommentsSpace(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DynamicIconInput(
                      controller: _commentController,
                      onSubmitted: _submitComment,
                      autoClearOnSubmit: true,
                      primary: theme.colorScheme.secondary,
                      panelColor: theme.appColors.overlaySurface,
                      borderColor: theme.appColors.overlayBorder,
                      hintText: 'Ecrire un commentaire...',
                      textInputAction: TextInputAction.send,
                      leadingIcon: Icon(
                        Icons.emoji_emotions_outlined,
                        color: theme.appColors.heroForegroundMuted.withValues(
                          alpha: 0.86,
                        ),
                      ),
                      onLeadingTap: _showEmojiPicker,
                      trailingIcon: Icon(
                        Icons.send_rounded,
                        color: theme.colorScheme.secondary,
                      ),
                      onTrailingTap: () =>
                          _submitComment(_commentController.text.trim()),
                    ),
                    if (!_isLive) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: _liveClosedByServer
                            // Retrying would stream into a closed session:
                            // a new live has to be started from the home.
                            ? _buildCompactActionButton(
                                label: 'Fermer',
                                icon: Icons.close_rounded,
                                onTap: () => Navigator.of(context).pop(true),
                                filled: true,
                                theme: theme,
                              )
                            : _buildCompactActionButton(
                                label: _errorMessage == null
                                    ? 'Passer en direct'
                                    : 'Reessayer la connexion',
                                icon: Icons.wifi_tethering_rounded,
                                onTap: _isConnecting
                                    ? null
                                    : () => _connectAndPublish(),
                                filled: true,
                                theme: theme,
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraSurface(LocalVideoTrack? localTrack) {
    if (localTrack == null) {
      return const SizedBox.shrink();
    }

    // Same fill as the viewer page: the default `contain` fit left black
    // bands around the camera preview, which read as a dark frame.
    return ClipRect(
      child: SizedBox.expand(
        child: VideoTrackRenderer(localTrack, fit: VideoViewFit.cover),
      ),
    );
  }

  Widget _buildCloseButton(ThemeData theme) {
    final appColors = theme.appColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleExitRequested,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: appColors.backButtonFill,
            shape: BoxShape.circle,
            border: Border.all(color: appColors.backButtonBorder),
          ),
          child: Align(
            child: Icon(Icons.close_rounded, color: appColors.heroForeground),
          ),
        ),
      ),
    );
  }

  Widget _buildHostCard(ThemeData theme) {
    final sellerName = widget.sellerName?.trim() ?? '';

    return LiveHostCard(
      name: sellerName.isNotEmpty ? sellerName : widget.title,
      title: sellerName.isNotEmpty ? widget.title : null,
      avatarUrl: widget.sellerAvatarUrl,
      isLive: _isLive,
      viewerCount: _isLive ? _room.remoteParticipants.length : null,
      likeCount: _isLive ? _likeCount : null,
      pulse: _livePulseController,
      onViewersTap: _isLive
          ? () => showLiveViewersSheet(context, room: _room)
          : null,
    );
  }

  Widget _buildToolRail(ThemeData theme) {
    const gap = SizedBox(height: 10);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LiveRoundButton(
          icon: Icons.flip_camera_ios_outlined,
          tooltip: 'Changer de caméra',
          onTap: _switchCamera,
        ),
        if (_isLive) ...[
          gap,
          LiveRoundButton(
            icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            tooltip: _isMuted ? 'Réactiver le micro' : 'Couper le micro',
            onTap: _toggleMuteLive,
            isOff: _isMuted,
          ),
          gap,
          LiveRoundButton(
            icon: _isCameraEnabled
                ? Icons.videocam_rounded
                : Icons.videocam_off_rounded,
            tooltip: _isCameraEnabled
                ? 'Couper la caméra'
                : 'Réactiver la caméra',
            onTap: _toggleCamera,
            isOff: !_isCameraEnabled,
          ),
          gap,
          LiveRoundButton(
            icon: _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            tooltip: _isPaused ? 'Reprendre le live' : 'Mettre en pause',
            onTap: _togglePauseLive,
            isOff: _isPaused,
          ),
        ],
      ],
    );
  }

  Widget _buildCompactActionButton({
    required String label,
    required IconData icon,
    required FutureOr<void> Function()? onTap,
    required bool filled,
    required ThemeData theme,
  }) {
    final appColors = theme.appColors;

    return SizedBox(
      height: 52,
      child: filled
          ? ElevatedButton.icon(
              onPressed: onTap == null ? null : () => onTap(),
              icon: Icon(icon),
              label: Text(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: theme.colorScheme.onSecondary,
                disabledBackgroundColor: theme.colorScheme.secondary.withValues(
                  alpha: 0.42,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap == null ? null : () => onTap(),
              icon: Icon(icon),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: appColors.heroForeground,
                side: BorderSide(color: appColors.overlayBorder),
                backgroundColor: appColors.overlaySurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
    );
  }

  Widget _buildCommentsSpace() {
    return LiveCommentsFeed(
      comments: _isLive ? _liveComments : const <LiveCommentEntry>[],
      emptyText: 'Les commentaires apparaîtront ici dès que le live commence.',
    );
  }

  Widget _buildConnectionBanner(ThemeData theme) {
    final appColors = theme.appColors;
    final isReconnecting =
        _room.connectionState == ConnectionState.reconnecting;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: appColors.overlaySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appColors.overlayBorder),
      ),
      child: Row(
        children: [
          if (isReconnecting)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              Icons.wifi_off_rounded,
              size: 18,
              color: appColors.liveIndicator,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isReconnecting
                  ? 'Connexion perdue, reconnexion en cours…'
                  : 'Connexion perdue. Le live sera fermé sans reprise '
                        'rapide.',
              style: TextStyle(
                color: appColors.heroForeground,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallback() {
    final theme = Theme.of(context);

    if (_isConnecting) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
          const SizedBox(height: 14),
          Text(
            'Initialisation de la camera...',
            style: TextStyle(
              color: theme.appColors.heroForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _errorMessage == null
                ? Icons.videocam_off_rounded
                : Icons.error_outline_rounded,
            color: theme.appColors.heroForeground,
            size: 42,
          ),
          const SizedBox(height: 14),
          Text(
            _isPaused
                ? 'Le live est en pause.'
                : _errorMessage ?? 'Impossible d\'ouvrir la camera.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.appColors.heroForeground,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _connectAndPublish(),
            child: const Text('Reessayer'),
          ),
        ],
      ),
    );
  }
}
