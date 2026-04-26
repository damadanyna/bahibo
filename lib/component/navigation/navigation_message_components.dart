import 'package:bahibo/component/app_network_image.dart';
import 'package:bahibo/component/ui/dinamic_icon_input.dart';
import 'package:flutter/material.dart';
import 'package:bahibo/theme/app_theme_extensions.dart';

class NavigationMessageSearchBar extends StatefulWidget {
  final Color fillColor;
  final Color iconColor;
  final Color hintColor;
  final Color borderColor;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  const NavigationMessageSearchBar({
    super.key,
    required this.fillColor,
    required this.iconColor,
    required this.hintColor,
    required this.borderColor,
    required this.onChanged,
    this.controller,
  });

  @override
  State<NavigationMessageSearchBar> createState() =>
      _NavigationMessageSearchBarState();
}

class _NavigationMessageSearchBarState
    extends State<NavigationMessageSearchBar> {
  late final TextEditingController _internalController =
      TextEditingController();

  TextEditingController get _controller =>
      widget.controller ?? _internalController;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleQueryChanged);
  }

  @override
  void didUpdateWidget(covariant NavigationMessageSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _internalController).removeListener(
        _handleQueryChanged,
      );
      _controller.addListener(_handleQueryChanged);
    }
  }

  void _handleQueryChanged() {
    widget.onChanged(_controller.text);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleQueryChanged);
    _internalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DynamicIconInput(
      controller: _controller,
      primary: widget.iconColor,
      panelColor: widget.fillColor,
      borderColor: widget.borderColor,
      hintText: 'Rechercher dans message',
      contentPadding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      leadingSize: 26,
      leadingIcon: Icon(
        Icons.search_rounded,
        color: widget.iconColor,
        size: 22,
      ),
      onLeadingTap: () {},
    );
  }
}

class NavigationMessageStoryAvatar extends StatelessWidget {
  final String name;
  final String avatarUrl;
  final String? userId;
  final bool isActive;
  final bool isOnline;
  final Color primary;
  final Color labelColor;
  final Color haloColor;
  final VoidCallback? onTap;

  const NavigationMessageStoryAvatar({
    super.key,
    required this.name,
    required this.avatarUrl,
    this.userId,
    required this.isActive,
    this.isOnline = false,
    required this.primary,
    required this.labelColor,
    required this.haloColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 72,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive
                            ? primary.withValues(alpha: 0.9)
                            : haloColor.withValues(alpha: 0.3),
                        width: isActive ? 2.2 : 1.1,
                      ),
                    ),
                    child: AppCircleNetworkAvatar(
                      radius: 28,
                      imageUrl: avatarUrl,
                      userId: userId,
                      showPresenceBadge: false,
                    ),
                  ),
                  Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        color: isOnline
                            ? Theme.of(context).appColors.onlineStatus
                            : Theme.of(
                                context,
                              ).colorScheme.outline.withValues(alpha: 0.84),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 2.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: labelColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NavigationConversationTile extends StatelessWidget {
  final String name;
  final String preview;
  final String? statusLabel;
  final String time;
  final String avatarUrl;
  final String? userId;
  final bool isTyping;
  final bool unread;
  final bool isOnline;
  final int unreadCount;
  final bool isMuted;
  final bool showReplyChip;
  final Color primary;
  final bool isDark;
  final VoidCallback onTap;

  const NavigationConversationTile({
    super.key,
    required this.name,
    required this.preview,
    this.statusLabel,
    required this.time,
    required this.avatarUrl,
    this.userId,
    this.isTyping = false,
    required this.unread,
    this.isOnline = false,
    this.unreadCount = 0,
    this.isMuted = false,
    this.showReplyChip = false,
    required this.primary,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final surfaceColor = theme.cardColor;
    final titleColor = theme.colorScheme.onSurface;
    final previewColor = unread
        ? theme.colorScheme.onSurface.withValues(alpha: 0.88)
        : appColors.mutedText;
    final statusColor = appColors.mutedText.withValues(alpha: 0.92);
    final badgeCount = unreadCount > 0 ? unreadCount : (unread ? 1 : 0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: unread
                            ? primary.withValues(alpha: 0.82)
                            : theme.colorScheme.outline.withValues(alpha: 0.22),
                        width: unread ? 1.8 : 1,
                      ),
                    ),
                    child: AppCircleNetworkAvatar(
                      radius: 26,
                      imageUrl: avatarUrl,
                      userId: userId,
                      showPresenceBadge: false,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: isOnline
                            ? appColors.onlineStatus
                            : theme.colorScheme.outline,
                        shape: BoxShape.circle,
                        border: Border.all(color: surfaceColor, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: titleColor,
                              fontWeight: unread
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        if (time.isNotEmpty)
                          Text(
                            time,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: isTyping
                              ? _NavigationTypingPreview(
                                  primary: primary,
                                  previewColor: previewColor,
                                )
                              : Text(
                                  preview,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: previewColor,
                                    fontWeight: unread
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                        if (showReplyChip) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.24),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.reply_rounded,
                                  size: 14,
                                  color: primary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Repondre',
                                  style: TextStyle(
                                    color: primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (badgeCount > 0) ...[
                          const SizedBox(width: 10),
                          Container(
                            constraints: const BoxConstraints(minWidth: 20),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badgeCount > 9 ? '9+' : '$badgeCount',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ] else if (isMuted) ...[
                          const SizedBox(width: 10),
                          Icon(
                            Icons.notifications_off_rounded,
                            size: 17,
                            color: statusColor,
                          ),
                        ],
                      ],
                    ),
                    if (statusLabel != null &&
                        statusLabel!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        statusLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationTypingPreview extends StatefulWidget {
  final Color primary;
  final Color previewColor;

  const _NavigationTypingPreview({
    required this.primary,
    required this.previewColor,
  });

  @override
  State<_NavigationTypingPreview> createState() =>
      _NavigationTypingPreviewState();
}

class _NavigationTypingPreviewState extends State<_NavigationTypingPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'En train d\'ecrire',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: widget.primary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 8),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                final phase = (_controller.value - (index * 0.18)) % 1.0;
                final opacity =
                    0.28 + ((phase < 0.5 ? phase : 1 - phase) * 1.4);
                final scale = 0.8 + ((phase < 0.5 ? phase : 1 - phase) * 0.45);

                return Padding(
                  padding: EdgeInsets.only(right: index == 2 ? 0 : 4),
                  child: Transform.scale(
                    scale: scale.clamp(0.8, 1.08),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: widget.primary.withValues(
                          alpha: opacity.clamp(0.28, 0.92),
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }
}

class NavigationIconActionButton extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback? onTap;

  const NavigationIconActionButton({
    super.key,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
      ),
    );
  }
}
