import 'dart:async';

import 'package:bahibo/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
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

class _LivePreviewPageState extends State<LivePreviewPage> {
  final Room _room = Room(
    roomOptions: const RoomOptions(
      adaptiveStream: true,
      dynacast: true,
      defaultCameraCaptureOptions: CameraCaptureOptions(
        params: VideoParametersPresets.h360_169,
        maxFrameRate: 15,
      ),
    ),
  );

  bool _isConnecting = true;
  bool _isMicrophoneEnabled = true;
  bool _isCameraEnabled = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _room.addListener(_handleRoomChanged);
    unawaited(_connectAndPublish());
  }

  @override
  void dispose() {
    _room.removeListener(_handleRoomChanged);
    unawaited(_room.disconnect());
    _room.dispose();
    super.dispose();
  }

  Future<void> _connectAndPublish() async {
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

      await _room.connect(widget.liveUrl, widget.liveToken);

      await _room.localParticipant?.setCameraEnabled(true);
      await _room.localParticipant?.setMicrophoneEnabled(true);

      if (!mounted) {
        return;
      }

      setState(() {
        _isConnecting = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isConnecting = false;
        _errorMessage = error.toString();
      });
    }
  }

  void _handleRoomChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  VideoTrack? _localVideoTrack() {
    final participant = _room.localParticipant;
    if (participant == null) {
      return null;
    }

    for (final publication in participant.videoTrackPublications) {
      final track = publication.track;
      if (track is VideoTrack && !publication.muted) {
        return track;
      }
    }

    return null;
  }

  Future<void> _toggleMicrophone() async {
    final nextValue = !_isMicrophoneEnabled;
    await _room.localParticipant?.setMicrophoneEnabled(nextValue);
    if (mounted) {
      setState(() => _isMicrophoneEnabled = nextValue);
    }
  }

  Future<void> _toggleCamera() async {
    final nextValue = !_isCameraEnabled;
    await _room.localParticipant?.setCameraEnabled(nextValue);
    if (mounted) {
      setState(() => _isCameraEnabled = nextValue);
    }
  }

  Future<void> _leaveLive() async {
    await _room.disconnect();
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    const liveColor = Color(0xFFE53935);
    final localTrack = _localVideoTrack();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _leaveLive,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                    ),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: liveColor,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.78),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    color: const Color(0xFF090909),
                    child: _isConnecting
                        ? const Center(child: CircularProgressIndicator())
                        : _errorMessage != null
                        ? _LiveStateMessage(
                            icon: Icons.error_outline_rounded,
                            title: 'Connexion LiveKit impossible',
                            message: _errorMessage!,
                          )
                        : localTrack != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              VideoTrackRenderer(localTrack),
                              Positioned(
                                top: 16,
                                right: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.46),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'Salle ${widget.roomName}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const _LiveStateMessage(
                            icon: Icons.videocam_off_rounded,
                            title: 'Camera indisponible',
                            message: 'Aucun track video local n\'est publie.',
                          ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _toggleMicrophone,
                      style: FilledButton.styleFrom(
                        backgroundColor: _isMicrophoneEnabled
                            ? appColors.panelBackground
                            : liveColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: Icon(
                        _isMicrophoneEnabled
                            ? Icons.mic_rounded
                            : Icons.mic_off_rounded,
                      ),
                      label: Text(
                        _isMicrophoneEnabled ? 'Micro actif' : 'Micro coupe',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _toggleCamera,
                      style: FilledButton.styleFrom(
                        backgroundColor: _isCameraEnabled
                            ? appColors.panelBackground
                            : liveColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: Icon(
                        _isCameraEnabled
                            ? Icons.videocam_rounded
                            : Icons.videocam_off_rounded,
                      ),
                      label: Text(
                        _isCameraEnabled ? 'Camera active' : 'Camera coupee',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveStateMessage extends StatelessWidget {
  const _LiveStateMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 42),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.76),
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
