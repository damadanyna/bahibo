import 'package:flutter/material.dart';
import 'package:bahibo/theme/app_theme_extensions.dart';

class NavigationSearchChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const NavigationSearchChip({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: appColors.inputBorder),
          ),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
