import 'dart:async';

import 'package:banay/component/live/live_overlay_widgets.dart';
import 'package:banay/component/ui/dinamic_icon_input.dart';
import 'package:banay/services/live/live_room_channel.dart';
import 'package:banay/theme/app_theme_extensions.dart';
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
  StreamSubscription<int>? _likesSubscription;
  int _likeCount = 0;

  bool _isConnecting = true;
  bool _isLive = false;
  bool _isPaused = false;
  bool _isMuted = false;
  bool _isCameraEnabled = true;
  CameraPosition _cameraPosition = CameraPosition.front;
  String? _errorMessage;

  // TikTok-style mobile profile: 720p capture (1280x720, portrait 720x1280
  // on a phone). Above that, the host's phone and uplink pay more than the
  // viewer's screen can show, and every viewer's data bill doubles.
  CameraCaptureOptions get _cameraCaptureOptions => CameraCaptureOptions(
    cameraPosition: _cameraPosition,
    params: VideoParametersPresets.h720_169,
    maxFrameRate: 30,
  );

  static const VideoPublishOptions _videoPublishOptions = VideoPublishOptions(
    // H.264 instead of the SDK's VP8 default: hardware-encoded on every
    // phone with a camera, so three simulcast layers no longer cook a
    // mid-range device, and the picture is sharper at the same bitrate. The
    // SDK falls back to a codec the server enables if H.264 is unavailable.
    videoCodec: 'h264',
    // 1.5 Mb/s at 720p / 30 fps: middle of the range TikTok Live uses for
    // 720p; ~0.7 GB per hour for an HD viewer, ~2 Mb/s uplink with the
    // ladder below.
    videoEncoding: VideoEncoding(maxBitrate: 1500 * 1000, maxFramerate: 30),
    // 360p is what the viewer page picks on mobile data: kept at 30 fps
    // (the SDK preset stops at 20) so a 4G viewer gets the same motion as a
    // Wi-Fi one, for ~10% more data (500 kb/s vs 450). 180p (160 kb/s,
    // 15 fps) is the data-saver mode. Both are also what the SFU serves on
    // its own when a viewer's link cannot keep up.
    simulcast: true,
    videoSimulcastLayers: [
      VideoParameters(
        dimensions: VideoDimensionsPresets.h360_169,
        encoding: VideoEncoding(maxBitrate: 500 * 1000, maxFramerate: 30),
      ),
      VideoParametersPresets.h180_169,
    ],
    // Under congestion, give up a little sharpness and a little frame rate
    // rather than letting the picture stutter: a live that freezes loses
    // viewers faster than one that softens for a few seconds.
    degradationPreference: DegradationPreference.balanced,
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
      ),
    );
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
    _commentController.dispose();
    _livePulseController.dispose();
    unawaited(_commentsSubscription?.cancel());
    unawaited(_likesSubscription?.cancel());
    unawaited(_channel?.dispose());
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
        await _room.connect(widget.liveUrl, widget.liveToken);
      }

      await _room.localParticipant?.setCameraEnabled(
        true,
        cameraCaptureOptions: _cameraCaptureOptions,
      );
      await _room.localParticipant?.setMicrophoneEnabled(true);

      if (!mounted) {
        return;
      }

      unawaited(_startChannel());
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
                        child: _buildCompactActionButton(
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
