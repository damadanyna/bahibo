import 'package:banay/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';

class DynamicIconCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color primary;
  final Color panelColor;
  final Color? borderColor;
  final String label;
  final Widget? leadingIcon;
  final double leadingSize;
  final EdgeInsetsGeometry contentPadding;
  final bool showBorder;

  const DynamicIconCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.primary,
    required this.panelColor,
    required this.label,
    this.borderColor,
    this.leadingIcon,
    this.leadingSize = 42,
    this.contentPadding = const EdgeInsets.fromLTRB(7, 3, 12, 3),
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appColors = theme.appColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onChanged(!value),
        child: Container(
          padding: contentPadding,
          decoration: BoxDecoration(
            color: isDark ? appColors.inputFill : panelColor,
            borderRadius: BorderRadius.circular(999),
            border: showBorder
                ? Border.all(color: borderColor ?? appColors.inputBorder)
                : null,
          ),
          child: Row(
            children: [
              if (leadingIcon != null) ...[
                SizedBox(
                  width: leadingSize,
                  height: leadingSize,
                  child: Center(child: leadingIcon),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isDark
                        ? appColors.heroForeground
                        : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Checkbox(
                value: value,
                onChanged: (nextValue) => onChanged(nextValue ?? false),
                activeColor: primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
