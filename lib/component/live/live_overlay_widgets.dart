import 'package:banay/component/app_network_image.dart';
import 'package:banay/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';

/// Overlay building blocks shared by the host (`live_preview_page.dart`) and
/// viewer (`live_watch_page.dart`) live screens, so both read the same way:
/// host card top-left, round glass buttons, comments feed above the input.

/// One line of the live chat overlay. Serialised as-is over the room's data
/// channel (see `LiveRoomChannel`).
class LiveCommentEntry {
  const LiveCommentEntry({
    required this.id,
    required this.author,
    required this.message,
    this.avatarUrl = '',
    this.isHost = false,
    this.userId = '',
  });

  final String id;
  final String author;
  final String message;
  final String avatarUrl;
  final bool isHost;
  final String userId;

  String get initials {
    final parts = author
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      final word = parts.first;
      return (word.length >= 2 ? word.substring(0, 2) : word).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'author': author,
    'message': message,
    'avatarUrl': avatarUrl,
    'isHost': isHost,
    'userId': userId,
  };

  /// Null when the payload carries no usable message.
  static LiveCommentEntry? fromJson(Map<String, dynamic> json) {
    final message = json['message']?.toString().trim() ?? '';
    if (message.isEmpty) {
      return null;
    }
    final author = json['author']?.toString().trim() ?? '';

    return LiveCommentEntry(
      id: json['id']?.toString() ?? '',
      author: author.isNotEmpty ? author : 'Spectateur',
      message: message,
      avatarUrl: json['avatarUrl']?.toString() ?? '',
      isHost: json['isHost'] == true,
      userId: json['userId']?.toString() ?? '',
    );
  }
}

String formatLiveCount(int value) {
  if (value >= 1000000) {
    final compact = (value / 1000000).toStringAsFixed(
      value % 1000000 == 0 ? 0 : 1,
    );
    return '${compact}M';
  }
  if (value >= 1000) {
    final compact = (value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1);
    return '${compact}k';
  }
  return '$value';
}

/// Pulsing dot driven by the page's live animation controller.
class LiveBlinkingDot extends StatelessWidget {
  const LiveBlinkingDot({
    super.key,
    required this.pulse,
    this.size = 14,
    this.color,
  });

  final Animation<double> pulse;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final dotColor = color ?? Theme.of(context).colorScheme.secondary;

    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.35,
        end: 1,
      ).animate(CurvedAnimation(parent: pulse, curve: Curves.easeInOut)),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: dotColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: dotColor.withValues(alpha: 0.56),
              blurRadius: size * 0.85,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

/// Red "LIVE" pill with a pulsing dot.
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key, required this.pulse});

  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).appColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: appColors.liveIndicator,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: appColors.overlaySurface, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LiveBlinkingDot(pulse: pulse, size: 6, color: Colors.white),
          const SizedBox(width: 4),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Top-left identity card: avatar with the LIVE tag overlapping its bottom
/// edge, the host's name, the viewer count and the live title.
class LiveHostCard extends StatelessWidget {
  const LiveHostCard({
    super.key,
    required this.name,
    required this.isLive,
    required this.pulse,
    this.title,
    this.avatarUrl,
    this.viewerCount,
    this.likeCount,
  });

  final String name;
  final String? title;
  final String? avatarUrl;
  final bool isLive;

  /// Null renders "--" (not connected yet).
  final int? viewerCount;

  /// Hearts received during this live; hidden when null.
  final int? likeCount;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final mutedColor = appColors.heroForegroundMuted.withValues(alpha: 0.9);
    final resolvedTitle = title?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
      decoration: BoxDecoration(
        color: appColors.overlaySurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: appColors.overlayBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAvatar(theme),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: appColors.heroForeground,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.visibility_rounded, size: 14, color: mutedColor),
                    const SizedBox(width: 4),
                    Text(
                      viewerCount == null
                          ? '--'
                          : formatLiveCount(viewerCount!),
                      style: TextStyle(
                        color: mutedColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (likeCount != null) ...[
                      const SizedBox(width: 10),
                      Icon(
                        Icons.favorite_rounded,
                        size: 14,
                        color: appColors.liveIndicator,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formatLiveCount(likeCount!),
                        style: TextStyle(
                          color: mutedColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (resolvedTitle.isNotEmpty) ...[
                      Text(
                        '  ·  ',
                        style: TextStyle(color: mutedColor, fontSize: 12),
                      ),
                      Flexible(
                        child: Text(
                          resolvedTitle,
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
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme) {
    final appColors = theme.appColors;
    final url = avatarUrl?.trim() ?? '';

    return SizedBox(
      width: 48,
      height: 50,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          if (url.isNotEmpty)
            AppCircleNetworkAvatar(
              imageUrl: url,
              radius: 22,
              showPresenceBadge: false,
            )
          else
            CircleAvatar(
              radius: 22,
              backgroundColor: appColors.heroSurface,
              child: Icon(
                Icons.storefront_rounded,
                color: appColors.heroForeground,
                size: 22,
              ),
            ),
          if (isLive) Positioned(bottom: 0, child: LiveBadge(pulse: pulse)),
        ],
      ),
    );
  }
}

/// 46 px round glass button. [isOff] paints it red (muted mic, hidden
/// camera); [fillColor] forces a fill (e.g. the viewer's like button).
class LiveRoundButton extends StatelessWidget {
  const LiveRoundButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isOff = false,
    this.fillColor,
    this.size = 46,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool isOff;
  final Color? fillColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).appColors;
    final background =
        fillColor ??
        (isOff
            ? appColors.liveIndicator.withValues(alpha: 0.92)
            : appColors.overlaySurface);
    final showBorder = fillColor == null && !isOff;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              border: Border.all(
                color: showBorder
                    ? appColors.overlayBorder
                    : Colors.transparent,
              ),
            ),
            child: Icon(icon, color: appColors.heroForeground, size: 22),
          ),
        ),
      ),
    );
  }
}

/// Bottom-anchored comments feed: newest entry (index 0) sits closest to the
/// input, older ones scroll up and fade into the scrim.
class LiveCommentsFeed extends StatelessWidget {
  const LiveCommentsFeed({
    super.key,
    required this.comments,
    required this.emptyText,
    this.height = 192,
  });

  final List<LiveCommentEntry> comments;
  final String emptyText;
  final double height;

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).appColors;

    return SizedBox(
      height: height,
      child: comments.isEmpty
          ? Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                child: Text(
                  emptyText,
                  style: TextStyle(
                    color: appColors.heroForegroundMuted.withValues(
                      alpha: 0.86,
                    ),
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          : ListView.separated(
              reverse: true,
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              physics: const BouncingScrollPhysics(),
              itemCount: comments.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _LiveCommentTile(comment: comments[index]),
            ),
    );
  }
}

class _LiveCommentTile extends StatelessWidget {
  const _LiveCommentTile({required this.comment});

  final LiveCommentEntry comment;

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).appColors;

    final primary = Theme.of(context).colorScheme.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (comment.avatarUrl.trim().isNotEmpty)
          AppCircleNetworkAvatar(
            imageUrl: comment.avatarUrl,
            radius: 17,
            showPresenceBadge: false,
          )
        else
          CircleAvatar(
            radius: 17,
            backgroundColor: appColors.heroSurface,
            child: Text(
              comment.initials,
              style: TextStyle(
                color: appColors.heroForeground,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name quiet, message loud: readers scan what is said. The
              // host is the one exception — their replies must stand out.
              Row(
                children: [
                  Flexible(
                    child: Text(
                      comment.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: comment.isHost
                            ? primary
                            : appColors.heroForegroundMuted.withValues(
                                alpha: 0.9,
                              ),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (comment.isHost) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Vendeur',
                        style: TextStyle(
                          color: primary,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                comment.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: appColors.heroForeground,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
