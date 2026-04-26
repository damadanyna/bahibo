import 'dart:async';

import 'package:bahibo/component/ui/dinamic_icon_input.dart';
import 'package:bahibo/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

class LivePreviewPage extends StatefulWidget {
  const LivePreviewPage({
    super.key,
    required this.title,
    required this.category,
    required this.liveUrl,
    required this.liveToken,
    required this.roomName,
  });

  final String title;
  final String category;
  final String liveUrl;
  final String liveToken;
  final String roomName;

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

  static const List<({String author, String initials, String message})>
  _sampleComments = [
    (
      author: 'Miora',
      initials: 'MI',
      message: 'Montre le produit de plus pres stp',
    ),
    (
      author: 'Tahina',
      initials: 'TA',
      message: 'Le son est propre, on te voit bien',
    ),
    (
      author: 'Aina',
      initials: 'AI',
      message: 'C\'est disponible a Tana aujourd\'hui ?',
    ),
    (
      author: 'Kanto',
      initials: 'KA',
      message: 'Le prix final avec livraison ?',
    ),
  ];

  late final Room _room;
  late final TextEditingController _commentController;
  late List<({String author, String initials, String message})> _liveComments;
  late final AnimationController _livePulseController;

  bool _isConnecting = true;
  bool _isLive = false;
  bool _isPaused = false;
  bool _isMuted = false;
  bool _isCameraEnabled = true;
  bool _showControlMenu = false;
  CameraPosition _cameraPosition = CameraPosition.front;
  String? _errorMessage;

  CameraCaptureOptions get _cameraCaptureOptions => CameraCaptureOptions(
    cameraPosition: _cameraPosition,
    params: VideoParametersPresets.h720_169,
    maxFrameRate: 24,
  );

  @override
  void initState() {
    super.initState();
    _room = Room(
      roomOptions: RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultCameraCaptureOptions: _cameraCaptureOptions,
      ),
    );
    _commentController = TextEditingController();
    _liveComments = List.of(_sampleComments);
    _livePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _room.addListener(_handleRoomChanged);
    unawaited(_connectAndPublish(initialLaunch: true));
  }

  @override
  void dispose() {
    _commentController.dispose();
    _livePulseController.dispose();
    _room.removeListener(_handleRoomChanged);
    unawaited(_room.disconnect());
    _room.dispose();
    super.dispose();
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

  void _toggleControlMenu() {
    setState(() {
      _showControlMenu = !_showControlMenu;
    });
  }

  Future<void> _submitComment(String text) async {
    if (text.trim().isEmpty) {
      return;
    }

    setState(() {
      _liveComments = [
        (author: 'Vous', initials: 'VO', message: text.trim()),
        ..._liveComments,
      ];
    });
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
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.appColors.scrimStrong.withValues(alpha: 0.76),
                      Colors.transparent,
                      theme.appColors.scrimStrong.withValues(alpha: 0.88),
                    ],
                    stops: const [0, 0.34, 1],
                  ),
                ),
              ),
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
            Positioned(
              top: 6,
              left: 16,
              child: SafeArea(child: _buildCloseButton(theme)),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [const Spacer(), _buildTopRightControls()]),
                    const Spacer(),
                    _buildCommentsSpace(),
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

    return ClipRect(
      child: SizedBox.expand(child: VideoTrackRenderer(localTrack)),
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

  Widget _buildFloatingControlIcon({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            color: Theme.of(context).appColors.heroForeground,
            size: 28,
          ),
        ),
      ),
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

  Widget _buildTopRightControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLive) ...[_buildBlinkingLiveDot(), const SizedBox(width: 8)],
            _buildTopLiveStats(),
          ],
        ),
        const SizedBox(height: 10),
        _buildFloatingControlIcon(
          icon: _showControlMenu
              ? Icons.settings_applications_rounded
              : Icons.settings_outlined,
          onTap: _toggleControlMenu,
        ),
        if (_showControlMenu) ...[
          const SizedBox(height: 10),
          _buildFloatingControlIcon(
            icon: Icons.flip_camera_ios_outlined,
            onTap: _switchCamera,
          ),
        ],
        if (_showControlMenu && _isLive) ...[
          const SizedBox(height: 10),
          _buildFloatingControlIcon(
            icon: _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            onTap: _togglePauseLive,
          ),
          const SizedBox(height: 10),
          _buildFloatingControlIcon(
            icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            onTap: _toggleMuteLive,
          ),
          const SizedBox(height: 10),
          _buildFloatingControlIcon(
            icon: _isCameraEnabled
                ? Icons.videocam_rounded
                : Icons.videocam_off_rounded,
            onTap: _toggleCamera,
          ),
        ],
      ],
    );
  }

  Widget _buildCommentsSpace() {
    final comments = _isLive
        ? _liveComments
        : const <({String author, String initials, String message})>[];

    return SizedBox(
      height: 192,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: comments.isEmpty
                        ? Align(
                            alignment: Alignment.topLeft,
                            child: Text(
                              'Les commentaires apparaitront ici des que le live commence. L\'espace est reserve pour garder la lecture claire.',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .appColors
                                    .heroForegroundMuted
                                    .withValues(alpha: 0.86),
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            physics: const BouncingScrollPhysics(),
                            itemCount: comments.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final comment = comments[index];
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 17,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).appColors.heroSurface,
                                    child: Text(
                                      comment.initials,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).appColors.heroForeground,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          comment.author,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          comment.message,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .appColors
                                                .heroForeground
                                                .withValues(alpha: 0.92),
                                            fontWeight: FontWeight.w500,
                                            height: 1.25,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopLiveStats() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTopStatChip(
          icon: Icons.remove_red_eye_rounded,
          value: _isLive ? '2.4k' : '--',
        ),
        const SizedBox(width: 8),
        _buildTopStatChip(
          icon: Icons.favorite_rounded,
          value: _isLive ? '2.4k' : '--',
        ),
        const SizedBox(width: 8),
        _buildTopStatChip(
          icon: Icons.chat_bubble_rounded,
          value: _isLive ? '128' : '--',
        ),
      ],
    );
  }

  Widget _buildTopStatChip({required IconData icon, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).appColors.overlaySurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).appColors.overlayBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Theme.of(context).appColors.heroForeground,
            size: 15,
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: Theme.of(context).appColors.heroForeground,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlinkingLiveDot() {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(
        CurvedAnimation(parent: _livePulseController, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Theme.of(
                context,
              ).colorScheme.secondary.withValues(alpha: 0.56),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
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
