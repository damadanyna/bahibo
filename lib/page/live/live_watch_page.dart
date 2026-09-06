import 'dart:async';

import 'package:banay/component/live/live_overlay_widgets.dart';
import 'package:banay/component/profile_models.dart';
import 'package:banay/component/ui/dinamic_icon_input.dart';
import 'package:banay/services/app_api_client.dart';
import 'package:banay/services/catalog_api_service.dart';
import 'package:banay/services/live/live_room_channel.dart';
import 'package:banay/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';

/// Viewer side of a live: full-bleed video with the same overlay grammar as
/// the host screen — host card top-left, follow + leave top-right, comments
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
  final Room _room = Room(
    roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
  );
  final TextEditingController _commentController = TextEditingController();
  late final AnimationController _livePulseController;

  bool _isConnecting = true;
  String? _errorMessage;
  String _title = 'En direct maintenant';
  late String _sellerName = widget.sellerName;
  late String _sellerAvatarUrl = widget.sellerAvatarUrl;
  bool _isFollowing = false;
  bool _isFollowSubmitting = false;
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
    _livePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _room.addListener(_handleRoomChanged);
    unawaited(_connectToLive());
  }

  @override
  void dispose() {
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
      _isFollowing = joinInfo['isFollowing'] == true;

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

  Future<void> _toggleFollow() async {
    final sellerProfileId = widget.sellerProfileId.trim();
    if (sellerProfileId.isEmpty || _isFollowSubmitting) {
      return;
    }

    setState(() => _isFollowSubmitting = true);

    try {
      final data = _isFollowing
          ? await _catalogApiService.unfollowSeller(sellerProfileId)
          : await _catalogApiService.followSeller(sellerProfileId);
      final nextProfile = buildSellerProfileFromApi(data);
      if (!mounted) {
        return;
      }
      setState(() => _isFollowing = nextProfile.isFollowing);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFollowing
                ? 'Vous suivez maintenant $_sellerName.'
                : 'Vous ne suivez plus $_sellerName.',
          ),
        ),
      );
    } on AppApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _isFollowSubmitting = false);
      }
    }
  }

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
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      appColors.scrimStrong.withValues(alpha: 0.76),
                      Colors.transparent,
                      appColors.scrimStrong.withValues(alpha: 0.88),
                    ],
                    stops: const [0, 0.34, 1],
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
                      _buildFollowButton(theme),
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

  Widget _buildFollowButton(ThemeData theme) {
    if (widget.sellerProfileId.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final appColors = theme.appColors;
    final shape = const StadiumBorder();
    const padding = EdgeInsets.symmetric(horizontal: 16);

    return SizedBox(
      height: 46,
      child: _isFollowing
          ? OutlinedButton.icon(
              onPressed: _isFollowSubmitting ? null : _toggleFollow,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Abonné'),
              style: OutlinedButton.styleFrom(
                foregroundColor: appColors.heroForeground,
                backgroundColor: appColors.overlaySurface,
                side: BorderSide(color: appColors.overlayBorder),
                shape: shape,
                padding: padding,
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            )
          : FilledButton.icon(
              onPressed: _isFollowSubmitting ? null : _toggleFollow,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Suivre'),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: shape,
                padding: padding,
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
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
