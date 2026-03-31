import 'package:flutter/material.dart';

class DynamicIconButton extends StatelessWidget {
  final String text;
  final Widget icon;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double spacing;
  final bool expanded;

  const DynamicIconButton({
    super.key,
    required this.text,
    required this.icon,
    this.onPressed,
    this.backgroundColor = const Color(0xFF16A34A),
    this.foregroundColor = Colors.white,
    this.borderRadius = 999,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    this.spacing = 10,
    this.expanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final buttonChild = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconTheme(
          data: IconThemeData(color: foregroundColor),
          child: icon,
        ),
        SizedBox(width: spacing),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foregroundColor,
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
            color: backgroundColor,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: buttonChild,
        ),
      ),
    );
  }
}
