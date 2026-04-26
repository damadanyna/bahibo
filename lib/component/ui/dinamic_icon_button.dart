import 'package:flutter/material.dart';

import 'package:bahibo/theme/app_theme_extensions.dart';

class DynamicIconButton extends StatelessWidget {
  final String text;
  final Widget icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double spacing;
  final bool expanded;

  const DynamicIconButton({
    super.key,
    required this.text,
    required this.icon,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.borderRadius = 999,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    this.spacing = 10,
    this.expanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final resolvedBackgroundColor =
        backgroundColor ?? theme.colorScheme.primary;
    final resolvedForegroundColor =
        foregroundColor ?? theme.colorScheme.onPrimary;
    final disabledBackgroundColor = appColors.panelMuted;
    final disabledForegroundColor = appColors.mutedText;
    final currentBackgroundColor = onPressed == null
        ? disabledBackgroundColor
        : resolvedBackgroundColor;
    final currentForegroundColor = onPressed == null
        ? disabledForegroundColor
        : resolvedForegroundColor;

    final buttonChild = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconTheme(
          data: IconThemeData(color: currentForegroundColor),
          child: icon,
        ),
        SizedBox(width: spacing),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: currentForegroundColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Ink(
          padding: padding,
          decoration: BoxDecoration(
            color: currentBackgroundColor,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: buttonChild,
        ),
      ),
    );
  }
}
