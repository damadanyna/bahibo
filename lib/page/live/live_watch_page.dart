import 'dart:async';

import 'package:banay/component/live/live_overlay_widgets.dart';
import 'package:banay/component/ui/dinamic_icon_input.dart';
import 'package:banay/services/catalog_api_service.dart';
import 'package:banay/services/live/live_room_channel.dart';
import 'package:banay/services/live/live_view_quality.dart';
import 'package:banay/theme/app_theme_extensions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Viewer side of a live: full-bleed video with the same overlay grammar as
/// the host screen — host card top-left, leave top-right, comments
/// bottom-left, comment input + like bottom row.
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

class _LiveWatchPageState extends State<LiveWatchPage>
    with SingleTickerProviderStateMixin {
  final CatalogApiService _catalogApiService = CatalogApiService();
  // adaptiveStream is off on purpose: it would pick the layer from the
  // renderer's logical size alone and ignore the network. The layer is
  // chosen here instead — TikTok-style — from the connection type (see
  // [resolveLiveViewQuality]); the SFU still steps down on its own under
  // congestion.
  final Room _room = Room(
    roomOptions: const RoomOptions(adaptiveStream: false, dynacast: true),
  );
  late final EventsListener<RoomEvent> _roomEvents = _room.createListener();
  final TextEditingController _commentController = TextEditingController();
  late final AnimationController _livePulseController;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnCellular = false;

  bool _isConnecting = true;
  String? _errorMessage;
  String _title = 'En direct maintenant';
  late String _sellerName = widget.sellerName;
  late String _sellerAvatarUrl = widget.sellerAvatarUrl;
  int _likeCount = 0;
  bool _likeBump = false;
  final List<LiveCommentEntry> _comments = <LiveCommentEntry>[];
  LiveRoomChannel? _channel;
  StreamSubscription<LiveCommentEntry>? _commentsSubscription;
  StreamSubscription<int>? _likesSubscription;
  static const int _maxKeptComments = 200;

  @override
  void initState() {
    super.initState();
    // Watching is hands-off: keep the screen from dimming or locking.
    unawaited(WakelockPlus.enable());
    _livePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _room.addListener(_handleRoomChanged);
    // Each subscribed video track gets the layer matching the viewer's
    // network; re-evaluated when the connection type changes.
    _roomEvents.on<TrackSubscribedEvent>((event) {
      if (event.publication.kind == TrackType.VIDEO) {
        _applyVideoQuality();
      }
    });
    _bindConnectivity();
    unawaited(_connectToLive());
  }

  @override
  void dispose() {
    unawaited(WakelockPlus.disable());
    _commentController.dispose();
    _livePulseController.dispose();
    unawaited(_connectivitySubscription?.cancel());
    unawaited(_commentsSubscription?.cancel());
    unawaited(_likesSubscription?.cancel());
    unawaited(_channel?.dispose());
    unawaited(_roomEvents.dispose());
    _room.removeListener(_handleRoomChanged);
    unawaited(_room.disconnect());
    _room.dispose();
    super.dispose();
  }

  /// Comments / likes over the room's data channel; identity resolved from
  /// the signed-in user so the host sees who is talking.
  Future<void> _startChannel() async {
    if (_channel != null) {
      return;
    }

    final channel = LiveRoomChannel(room: _room, isHost: false);
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
      _comments.insert(0, entry);
      if (_comments.length > _maxKeptComments) {
        _comments.removeRange(_maxKeptComments, _comments.length);
      }
    });
  }

  Future<void> _connectToLive() async {
    try {
      final joinInfo = await _catalogApiService.fetchSellerLiveJoinInfo(
        widget.sellerProfileId,
      );

      _title = joinInfo['title']?.toString() ?? _title;
      final joinSellerName = joinInfo['sellerName']?.toString().trim() ?? '';
      final joinAvatarUrl =
          joinInfo['sellerAvatarUrl']?.toString().trim() ?? '';
      if (joinSellerName.isNotEmpty) {
        _sellerName = joinSellerName;
      }
      if (joinAvatarUrl.isNotEmpty) {
        _sellerAvatarUrl = joinAvatarUrl;
      }

      await _room.connect(
        joinInfo['url']?.toString() ?? '',
        joinInfo['token']?.toString() ?? '',
      );
      unawaited(_startChannel());

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

  /// Tracks Wi-Fi ⇄ mobile data switches so the automatic mode follows the
  /// viewer mid-live instead of freezing on the layer chosen at join time.
  void _bindConnectivity() {
    unawaited(
      _connectivity.checkConnectivity().then(_handleConnectivityChange),
    );
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChange,
    );
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final isOnCellular = isCellularOnly(results);
    if (!mounted || isOnCellular == _isOnCellular) {
      return;
    }
    setState(() => _isOnCellular = isOnCellular);
    _applyVideoQuality();
  }

  /// Asks the SFU for the simulcast layer matching the current network
  /// on every subscribed video track. Cheap and idempotent: the SDK skips
  /// the signal when the quality is unchanged.
  void _applyVideoQuality() {
    final quality = resolveLiveViewQuality(isOnCellular: _isOnCellular);
    for (final participant in _room.remoteParticipants.values) {
      for (final publication in participant.videoTrackPublications) {
        unawaited(publication.setVideoQuality(quality));
      }
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

  /// Everyone else in the room, host included, minus nothing: the host is
  /// one remote participant, this viewer is not counted, so the two cancel.
  int? get _viewerCount => _room.connectionState == ConnectionState.connected
      ? _room.remoteParticipants.length
      : null;

  void _handleLike() {
    unawaited(HapticFeedback.lightImpact());
    unawaited(_channel?.sendLike() ?? Future<void>.value());
    setState(() {
      _likeCount += 1;
      _likeBump = true;
    });
    Future<void>.delayed(const Duration(milliseconds: 180), () {
      if (mounted) {
        setState(() => _likeBump = false);
      }
    });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final remoteTrack = _remoteVideoTrack();
    final isStreaming =
        !_isConnecting && _errorMessage == null && remoteTrack != null;

    return Scaffold(
      backgroundColor: appColors.viewerBackground,
      body: Stack(
        children: [
          Positioned.fill(
            child: remoteTrack != null
                ? VideoTrackRenderer(remoteTrack, fit: VideoViewFit.cover)
                : Container(
                    color: appColors.viewerBackground,
                    alignment: Alignment.center,
                    child: _buildStateMessage(),
                  ),
          ),
          const Positioned.fill(child: LiveOverlayScrim()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: LiveHostCard(
                          name: _sellerName,
                          title: _title,
                          avatarUrl: _sellerAvatarUrl,
                          isLive: isStreaming,
                          viewerCount: _viewerCount,
                          likeCount: isStreaming ? _likeCount : null,
                          pulse: _livePulseController,
                        ),
                      ),
                      const SizedBox(width: 10),
                      LiveRoundButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Quitter le live',
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  // Leave the right side free of text, like every live UI:
                  // the eye lands on the host, comments stay a side channel.
                  // Expanded (not Spacer + fixed box) so the feed shrinks
                  // under the keyboard instead of overflowing.
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: FractionallySizedBox(
                        widthFactor: 0.82,
                        child: LiveCommentsFeed(
                          comments: _comments,
                          emptyText: isStreaming
                              ? 'Dites bonjour à $_sellerName, vos messages '
                                    'apparaîtront ici.'
                              : '',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: DynamicIconInput(
                          controller: _commentController,
                          onSubmitted: _submitComment,
                          autoClearOnSubmit: true,
                          primary: theme.colorScheme.primary,
                          panelColor: appColors.overlaySurface,
                          borderColor: appColors.overlayBorder,
                          hintText: 'Écrire un commentaire…',
                          textInputAction: TextInputAction.send,
                          trailingIcon: Icon(
                            Icons.send_rounded,
                            color: theme.colorScheme.primary,
                          ),
                          onTrailingTap: () =>
                              _submitComment(_commentController.text),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _buildLikeButton(theme),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLikeButton(ThemeData theme) {
    final appColors = theme.appColors;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedScale(
          scale: _likeBump ? 1.15 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: LiveRoundButton(
            icon: Icons.favorite_rounded,
            tooltip: 'J\'aime',
            onTap: _handleLike,
            fillColor: appColors.liveIndicator,
          ),
        ),
        if (_likeCount > 0)
          Positioned(
            top: -6,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: appColors.overlaySurface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: appColors.overlayBorder),
              ),
              child: Text(
                formatLiveCount(_likeCount),
                style: TextStyle(
                  color: appColors.heroForeground,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStateMessage() {
    if (_isConnecting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _LiveWatchMessage(
        icon: Icons.error_outline_rounded,
        title: 'Impossible de rejoindre le live',
        message: _errorMessage!,
      );
    }

    return _LiveWatchMessage(
      icon: Icons.wifi_tethering_off_rounded,
      title: 'En attente du flux vidéo',
      message:
          'Vous êtes dans le salon, mais $_sellerName ne diffuse pas encore '
          'd\'image.',
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
