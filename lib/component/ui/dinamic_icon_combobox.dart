import 'package:bahibo/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';

class DynamicIconComboBox<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final Color primary;
  final Color panelColor;
  final Color? borderColor;
  final String hintText;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final double leadingSize;
  final double trailingSize;
  final EdgeInsetsGeometry contentPadding;
  final bool showBorder;
  final bool isExpanded;

  const DynamicIconComboBox({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.primary,
    required this.panelColor,
    this.borderColor,
    this.hintText = 'Selectionner',
    this.leadingIcon,
    this.trailingIcon,
    this.leadingSize = 42,
    this.trailingSize = 42,
    this.contentPadding = const EdgeInsets.fromLTRB(7, 3, 5, 3),
    this.showBorder = true,
    this.isExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appColors = theme.appColors;
    final hintColor = isDark
        ? appColors.heroForegroundMuted
        : appColors.mutedText;

    return Container(
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
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                items: items,
                onChanged: onChanged,
                isExpanded: isExpanded,
                borderRadius: BorderRadius.circular(20),
                dropdownColor: isDark ? appColors.inputFill : panelColor,
                icon:
                    trailingIcon ??
                    Icon(Icons.keyboard_arrow_down_rounded, color: primary),
                hint: Text(
                  hintText,
                  style: TextStyle(
                    color: hintColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextStyle(
                  color: isDark
                      ? theme.appColors.heroForeground
                      : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (trailingIcon != null)
            SizedBox(
              width: trailingSize,
              height: trailingSize,
              child: Center(child: trailingIcon),
            ),
        ],
      ),
    );
  }
}
