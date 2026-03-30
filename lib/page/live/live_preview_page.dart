import 'dart:async';

import 'package:bahibo/component/ui/dinamic_icon_input.dart';
import 'package:bahibo/theme/app_theme_extensions.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LivePreviewPage extends StatefulWidget {
  final String title;
  final String category;

  const LivePreviewPage({
    super.key,
    required this.title,
    required this.category,
  });

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

  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  late final TextEditingController _commentController;
  late List<({String author, String initials, String message})> _liveComments;
  bool _isLoading = true;
  bool _isStartingLive = false;
  bool _isLive = false;
  bool _isPaused = false;
  bool _isMuted = false;
  bool _showControlMenu = false;
  String? _cameraError;
  late final AnimationController _livePulseController;

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;

    if (controller == null) {
      return;
    }

    try {
      await controller.dispose();
    } on CameraException {
      // Ignore camera plugin teardown failures during page disposal.
    } on PlatformException {
      // Ignore transient channel teardown errors from Android camera plugins.
    } catch (_) {
      // Keep teardown failures from crashing the app.
    }
  }

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
    _liveComments = List.of(_sampleComments);
    _livePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _initializeCamera();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _livePulseController.dispose();
    unawaited(_disposeController());
    super.dispose();
  }

  Future<void> _initializeCamera([CameraDescription? preferredCamera]) async {
    setState(() {
      _isLoading = true;
      _cameraError = null;
    });

    try {
      final cameras = _cameras.isNotEmpty ? _cameras : await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _cameras = const [];
          _cameraError = 'Aucune camera disponible sur cet appareil.';
          _isLoading = false;
        });
        return;
      }

      _cameras = cameras;
      final nextCamera = preferredCamera ?? cameras.first;

      await _disposeController();
      final controller = CameraController(
        nextCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _isLoading = false;
      });
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _cameraError = error.description ?? error.code;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cameraError = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _controller == null) {
      return;
    }

    final currentCamera = _controller!.description;
    final currentIndex = _cameras.indexOf(currentCamera);
    final nextIndex = currentIndex == -1
        ? 0
        : (currentIndex + 1) % _cameras.length;
    await _initializeCamera(_cameras[nextIndex]);
  }

  Future<void> _goLive() async {
    if (_isLive || _controller == null || !_controller!.value.isInitialized) {
      return;
    }

    setState(() => _isStartingLive = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _isStartingLive = false;
      _isLive = true;
      _isPaused = false;
      _isMuted = false;
      _showControlMenu = false;
    });
    _livePulseController.repeat(reverse: true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Le live "${widget.title}" est demarre.')),
    );
  }

  Future<void> _togglePauseLive() async {
    if (!_isLive) {
      return;
    }

    setState(() {
      _isPaused = !_isPaused;
    });

    if (_isPaused) {
      _livePulseController.stop();
    } else {
      _livePulseController.repeat(reverse: true);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isPaused ? 'Le live est en pause.' : 'Le live a repris.',
        ),
      ),
    );
  }

  Future<void> _toggleMuteLive() async {
    if (!_isLive) {
      return;
    }

    setState(() {
      _isMuted = !_isMuted;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isMuted ? 'Le micro est en muet.' : 'Le micro est reactif.',
        ),
      ),
    );
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

    final wasLive = _isLive;
    _livePulseController.stop();
    setState(() {
      _isStartingLive = false;
      _isLive = false;
      _isPaused = false;
      _isMuted = false;
      _showControlMenu = false;
    });

    await _disposeController();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(wasLive);
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
    final appColors = theme.appColors;
    final previewReady =
        _controller != null && _controller!.value.isInitialized;

    return WillPopScope(
      onWillPop: () async {
        await _handleExitRequested();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: previewReady
                  ? _buildCameraSurface()
                  : Container(
                      color: Colors.black,
                      alignment: Alignment.center,
                      child: _buildFallback(theme),
                    ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.58),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.72),
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
                        color: Colors.black.withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.pause_circle_filled_rounded,
                            color: Colors.white,
                            size: 74,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Live en pause',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.94),
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
                    Row(
                      children: [const Spacer(), _buildTopRightControls(theme)],
                    ),
                    const Spacer(),
                    _buildCommentsSpace(theme),
                    const SizedBox(height: 12),
                    DynamicIconInput(
                      controller: _commentController,
                      onSubmitted: _submitComment,
                      autoClearOnSubmit: true,
                      primary: const Color(0xFFE53935),
                      panelColor: Colors.black.withValues(alpha: 0.22),
                      borderColor: Colors.white.withValues(alpha: 0.12),
                      hintText: 'Ecrire un commentaire...',
                      textInputAction: TextInputAction.send,
                      leadingIcon: Icon(
                        Icons.emoji_emotions_outlined,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                      onLeadingTap: () {
                        _showEmojiPicker();
                      },
                      trailingIcon: const Icon(
                        Icons.send_rounded,
                        color: Color(0xFFE53935),
                      ),
                      onTrailingTap: () =>
                          _submitComment(_commentController.text.trim()),
                    ),
                    if (!_isLive) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: _buildCompactActionButton(
                          label: 'Passer en direct',
                          icon: Icons.wifi_tethering_rounded,
                          onTap: previewReady && !_isStartingLive
                              ? _goLive
                              : null,
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

  Widget _buildCameraSurface() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return CameraPreview(controller);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: previewSize.height,
              height: previewSize.width,
              child: CameraPreview(controller),
            ),
          ),
        );
      },
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
          child: Icon(icon, color: Colors.white, size: 28),
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
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF7A2525),
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
                backgroundColor: Colors.black.withValues(alpha: 0.22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
    );
  }

  Widget _buildTopRightControls(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLive) ...[_buildBlinkingLiveDot(), const SizedBox(width: 8)],
            _buildTopLiveStats(theme),
          ],
        ),
        const SizedBox(height: 10),
        _buildFloatingControlIcon(
          icon: _showControlMenu
              ? Icons.settings_applications_rounded
              : Icons.settings_outlined,
          onTap: _toggleControlMenu,
        ),
        if (_showControlMenu && _cameras.length > 1) ...[
          const SizedBox(height: 10),
          _buildFloatingControlIcon(
            icon: Icons.flip_camera_ios_outlined,
            onTap: () {
              _switchCamera();
            },
          ),
        ],
        if (_showControlMenu && _isLive) ...[
          const SizedBox(height: 10),
          _buildFloatingControlIcon(
            icon: _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            onTap: () {
              _togglePauseLive();
            },
          ),
          const SizedBox(height: 10),
          _buildFloatingControlIcon(
            icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            onTap: () {
              _toggleMuteLive();
            },
          ),
        ],
      ],
    );
  }

  Widget _buildCommentsSpace(ThemeData theme) {
    final comments = _isLive
        ? _liveComments
        : const <({String author, String initials, String message})>[];

    return SizedBox(
      height: 192,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
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
                                    color: Colors.white.withValues(alpha: 0.82),
                                    height: 1.35,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: EdgeInsets.zero,
                                physics: const BouncingScrollPhysics(),
                                itemCount: comments.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final comment = comments[index];
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 17,
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.14),
                                        child: Text(
                                          comment.initials,
                                          style: const TextStyle(
                                            color: Colors.white,
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
                                              style: const TextStyle(
                                                color: Color.fromARGB(
                                                  255,
                                                  67,
                                                  167,
                                                  1,
                                                ),
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              comment.message,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.9,
                                                ),
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
          );
        },
      ),
    );
  }

  Widget _buildTopLiveStats(ThemeData theme) {
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
        color: Colors.black.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.94),
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
        decoration: const BoxDecoration(
          color: Color(0xFFE53935),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x99E53935),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallback(ThemeData theme) {
    if (_isLoading) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
          SizedBox(height: 14),
          Text(
            'Initialisation de la camera...',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_off_rounded, color: Colors.white, size: 42),
          const SizedBox(height: 14),
          Text(
            _cameraError ?? 'Impossible d\'ouvrir la camera.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _initializeCamera,
            child: const Text('Reessayer'),
          ),
        ],
      ),
    );
  }
}
