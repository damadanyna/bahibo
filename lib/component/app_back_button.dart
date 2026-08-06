import 'package:flutter/material.dart';
import 'package:banay/theme/app_theme_extensions.dart';

class AppBackButton extends StatelessWidget {
  final VoidCallback? onTap;
  final double size;
  final EdgeInsetsGeometry padding;
  // Utilisé quand le bouton repose sur le fond de page (et non sur une photo/hero) :
  // en thème clair, le disque sombre tranche mal sur un fond clair, donc on le masque.
  final bool themeAdaptive;

  const AppBackButton({
    super.key,
    this.onTap,
    this.size = 46,
    this.padding = const EdgeInsets.all(10),
    this.themeAdaptive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final isLight = themeAdaptive && theme.brightness == Brightness.light;

    final Color fillColor = isLight ? Colors.transparent : appColors.backButtonFill;
    final Color borderColor = isLight ? Colors.transparent : appColors.backButtonBorder;
    final Color iconColor = isLight ? Colors.black : appColors.heroForeground;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () => Navigator.of(context).pop(),
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: fillColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor),
          ),
          child: Padding(
            padding: padding,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Icon(Icons.arrow_back, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}

