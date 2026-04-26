import 'package:flutter/material.dart';
import 'package:banay/theme/app_theme_extensions.dart';

class AppBackButton extends StatelessWidget {
  final VoidCallback? onTap;
  final double size;
  final EdgeInsetsGeometry padding;

  const AppBackButton({
    super.key,
    this.onTap,
    this.size = 46,
    this.padding = const EdgeInsets.all(10),
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).appColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () => Navigator.of(context).pop(),
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: appColors.backButtonFill,
            shape: BoxShape.circle,
            border: Border.all(color: appColors.backButtonBorder),
          ),
          child: Padding(
            padding: padding,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Icon(Icons.arrow_back, color: appColors.heroForeground),
            ),
          ),
        ),
      ),
    );
  }
}

