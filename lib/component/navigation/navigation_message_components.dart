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
      contentPadding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
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
  final bool isActive;
  final Color primary;
  final Color labelColor;
  final Color haloColor;
  final VoidCallback? onTap;

  const NavigationMessageStoryAvatar({
    super.key,
    required this.name,
    required this.avatarUrl,
    required this.isActive,
    required this.primary,
    required this.labelColor,
    required this.haloColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final successColor = Theme.of(context).appColors.success;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 68,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: primary.withValues(alpha: 0.42),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.18),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: AppCircleNetworkAvatar(
                      radius: 26,
                      imageUrl: avatarUrl,
                    ),
                  ),
                  if (isActive)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: successColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: haloColor, width: 2),
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
  final String time;
  final String avatarUrl;
  final bool isTyping;
  final bool unread;
  final Color primary;
  final bool isDark;
  final VoidCallback onTap;

  const NavigationConversationTile({
    super.key,
    required this.name,
    required this.preview,
    required this.time,
    required this.avatarUrl,
    this.isTyping = false,
    required this.unread,
    required this.primary,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final surfaceColor = unread
        ? (isDark ? theme.cardColor : theme.cardColor)
        : appColors.inputFill;
    final titleColor = isDark
        ? appColors.heroForeground
        : theme.colorScheme.onSurface;
    final previewColor = isDark
        ? appColors.heroForeground.withValues(alpha: unread ? 0.86 : 0.68)
        : appColors.mutedText;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: unread
                  ? primary.withValues(alpha: isDark ? 0.22 : 0.16)
                  : (isDark ? appColors.heroSurface : appColors.inputBorder),
            ),
            boxShadow: unread
                ? [
                    BoxShadow(
                      color: appColors.scrimSoft.withValues(
                        alpha: isDark ? 0.18 : 0.05,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
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
                        color: primary.withValues(alpha: unread ? 0.42 : 0.18),
                      ),
                    ),
                    child: AppCircleNetworkAvatar(
                      radius: 28,
                      imageUrl: avatarUrl,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 1,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: appColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: surfaceColor, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
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
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Text(
                          time,
                          style: TextStyle(
                            color: unread ? primary : previewColor,
                            fontWeight: unread
                                ? FontWeight.w800
                                : FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
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
                        if (unread) ...[
                          const SizedBox(width: 10),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: appColors.success,
                              shape: BoxShape.circle,
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

  const NavigationIconActionButton({
    super.key,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: Icon(icon, color: iconColor, size: 20),
    );
  }
}
