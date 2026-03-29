import 'dart:async';

import 'package:flutter/material.dart';

typedef DynamicInputSubmitCallback = FutureOr<void> Function(String text);

class DynamicIconInput extends StatefulWidget {
  final TextEditingController controller;
  final DynamicInputSubmitCallback? onSubmitted;
  final Color primary;
  final Color panelColor;
  final Color? borderColor;
  final String hintText;
  final bool autoClearOnSubmit;
  final Widget? leadingIcon;
  final VoidCallback? onLeadingTap;
  final double leadingSize;
  final Widget? trailingIcon;
  final VoidCallback? onTrailingTap;
  final double trailingSize;
  final EdgeInsetsGeometry contentPadding;
  final bool showBorder;

  const DynamicIconInput({
    super.key,
    required this.controller,
    this.onSubmitted,
    required this.primary,
    required this.panelColor,
    this.borderColor,
    this.hintText = 'Ecrire votre message...',
    this.autoClearOnSubmit = false,
    this.leadingIcon,
    this.onLeadingTap,
    this.leadingSize = 42,
    this.trailingIcon,
    this.onTrailingTap,
    this.trailingSize = 42,
    this.contentPadding = const EdgeInsets.fromLTRB(7, 3, 5, 3),
    this.showBorder = true,
  });

  @override
  State<DynamicIconInput> createState() => _DynamicIconInputState();
}

class _DynamicIconInputState extends State<DynamicIconInput> {
  Future<void> _handleSubmit() async {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;
    if (widget.onSubmitted != null) {
      await widget.onSubmitted!(text);
    }
    if (widget.autoClearOnSubmit && mounted) {
      widget.controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hintColor = isDark
        ? Colors.white.withValues(alpha: 0.58)
        : const Color(0xFF697B71);

    return Container(
      padding: widget.contentPadding,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF163228) : widget.panelColor,
        borderRadius: BorderRadius.circular(999),
        border: widget.showBorder
            ? Border.all(
                color:
                    widget.borderColor ??
                    (isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : const Color(0xFFE1EBE4)),
              )
            : null,
      ),
      child: Row(
        children: [
          if (widget.leadingIcon != null) ...[
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onLeadingTap,
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  width: widget.leadingSize,
                  height: widget.leadingSize,
                  child: Center(child: widget.leadingIcon),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: TextField(
              controller: widget.controller,
              maxLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _handleSubmit(),
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF14201A),
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  color: hintColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (widget.trailingIcon != null) ...[
            const SizedBox(width: 10),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTrailingTap,
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  width: widget.trailingSize,
                  height: widget.trailingSize,
                  child: Center(child: widget.trailingIcon),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
