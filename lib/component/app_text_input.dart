import 'package:flutter/material.dart';

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
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: height,
      alignment: Alignment.center,
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF142B27) : const Color(0xFFF6FBF7),
        borderRadius: borderRadius,
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFDFEAE2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.14 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
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
  final isDark = theme.brightness == Brightness.dark;
  final subtleText = isDark ? Colors.white70 : const Color(0xFF5D6C66);

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
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return TextStyle(
    color: isDark ? Colors.white : const Color(0xFF12201B),
    fontWeight: FontWeight.w600,
    fontSize: 14,
  );
}
