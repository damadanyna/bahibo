import 'package:banay/component/ui/app_debounce.dart';
import 'package:flutter/material.dart';

import 'package:banay/theme/app_theme_extensions.dart';

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

  /// When true the button shows a spinner, disables tap, and visually dims.
  /// Pass `isLoading: _isSubmitting` instead of `onPressed: _isSubmitting ? null : _doX`
  /// to get both the disabled state AND the loading indicator automatically.
  final bool isLoading;

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
    this.isLoading = false,
  });

  VoidCallback? _guardedOnPressed() {
    if (onPressed == null || isLoading) return null;
    return () {
      if (!AppDebounce.tryAcquire()) return;
      onPressed!();
    };
  }

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

    final effectiveOnPressed = _guardedOnPressed();
    final isDisabled = effectiveOnPressed == null;

    final currentBackgroundColor =
        isDisabled ? disabledBackgroundColor : resolvedBackgroundColor;
    final currentForegroundColor =
        isDisabled ? disabledForegroundColor : resolvedForegroundColor;

    final leadingWidget = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: currentForegroundColor,
            ),
          )
        : IconTheme(
            data: IconThemeData(color: currentForegroundColor),
            child: icon,
          );

    final buttonChild = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        leadingWidget,
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
        onTap: effectiveOnPressed,
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

