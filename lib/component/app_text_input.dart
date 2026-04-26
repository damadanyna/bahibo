import 'package:flutter/material.dart';
import 'package:banay/theme/app_theme_extensions.dart';

class AppInputContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;
  final double height;

  const AppInputContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;

    return Container(
      height: height,
      alignment: Alignment.center,
      padding: padding,
      decoration: BoxDecoration(
        color: appColors.inputFill,
        borderRadius: borderRadius,
        border: Border.all(color: appColors.inputBorder),
      ),
      child: child,
    );
  }
}

InputDecoration appInputDecoration(
  BuildContext context, {
  String? hintText,
  String? labelText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(vertical: 8),
  bool isDense = true,
}) {
  final theme = Theme.of(context);
  final subtleText = theme.appColors.mutedText;

  return InputDecoration(
    hintText: hintText,
    labelText: labelText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    hintStyle: TextStyle(color: subtleText, fontWeight: FontWeight.w600),
    labelStyle: TextStyle(color: subtleText, fontWeight: FontWeight.w600),
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    isDense: isDense,
    contentPadding: contentPadding,
  );
}

TextStyle appInputTextStyle(BuildContext context) {
  final theme = Theme.of(context);
  return TextStyle(
    color: theme.colorScheme.onSurface,
    fontWeight: FontWeight.w600,
    fontSize: 14,
  );
}

