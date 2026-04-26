import 'dart:async';

import 'package:bahibo/services/catalog_api_service.dart';
import 'package:bahibo/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

class LiveWatchPage extends StatefulWidget {
  const LiveWatchPage({
    super.key,
    required this.sellerProfileId,
    required this.sellerName,
    required this.sellerAvatarUrl,
  });

  final String sellerProfileId;
  final String sellerName;
  final String sellerAvatarUrl;

  @override
  State<LiveWatchPage> createState() => _LiveWatchPageState();
}

class _LiveWatchPageState extends State<LiveWatchPage> {
  final CatalogApiService _catalogApiService = CatalogApiService();
  final Room _room = Room(
    roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
  );

  bool _isConnecting = true;
  String? _errorMessage;
  String _title = 'En direct maintenant';
  String _category = 'Live boutique';

  @override
  void initState() {
    super.initState();
    _room.addListener(_handleRoomChanged);
    unawaited(_connectToLive());
  }

  @override
  void dispose() {
    _room.removeListener(_handleRoomChanged);
    unawaited(_room.disconnect());
    _room.dispose();
    super.dispose();
  }

  Future<void> _connectToLive() async {
    try {
      final joinInfo = await _catalogApiService.fetchSellerLiveJoinInfo(
        widget.sellerProfileId,
      );

      _title = joinInfo['title']?.toString() ?? _title;
      _category = joinInfo['category']?.toString() ?? _category;

      await _room.connect(
        joinInfo['url']?.toString() ?? '',
        joinInfo['token']?.toString() ?? '',
      );

      if (mounted) {
        setState(() {
          _isConnecting = false;
          _errorMessage = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _errorMessage = error.toString();
        });
      }
    }
  }

  void _handleRoomChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  VideoTrack? _remoteVideoTrack() {
    for (final participant in _room.remoteParticipants.values) {
      for (final publication in participant.videoTrackPublications) {
        final track = publication.track;
        if (track is VideoTrack && !publication.muted) {
          return track;
        }
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final liveColor = theme.colorScheme.secondary;
    final headingColor = appColors.heroForeground;
    final mutedColor = appColors.heroForegroundMuted.withValues(alpha: 0.86);
    final remoteTrack = _remoteVideoTrack();

    return Scaffold(
      backgroundColor: appColors.viewerBackground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: appColors.overlaySurface,
                      side: BorderSide(color: appColors.overlayBorder),
                    ),
                    icon: Icon(Icons.arrow_back_rounded, color: headingColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.sellerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: headingColor,
                            fontSize: 16,
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
                                _category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: mutedColor,
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    color: Color.lerp(
                      appColors.viewerBackground,
                      theme.colorScheme.surface,
                      0.08,
                    ),
                    child: _isConnecting
                        ? const Center(child: CircularProgressIndicator())
                        : _errorMessage != null
                        ? _LiveWatchMessage(
                            icon: Icons.error_outline_rounded,
                            title: 'Impossible de rejoindre le live',
                            message: _errorMessage!,
                          )
                        : remoteTrack != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              VideoTrackRenderer(remoteTrack),
                              Positioned(
                                left: 18,
                                right: 18,
                                bottom: 18,
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: appColors.overlaySurface,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: appColors.overlayBorder,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _title,
                                        style: TextStyle(
                                          color: headingColor,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Live de ${widget.sellerName}',
                                        style: TextStyle(
                                          color: mutedColor,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : _LiveWatchMessage(
                            icon: Icons.wifi_tethering_off_rounded,
                            title: 'En attente du flux video',
                            message:
                                'Le salon LiveKit est rejoint, mais aucun flux video n\'est encore publie par ${widget.sellerName}.',
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveWatchMessage extends StatelessWidget {
  const _LiveWatchMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: appColors.heroForeground, size: 42),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: appColors.heroForeground,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: appColors.heroForegroundMuted.withValues(alpha: 0.86),
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
