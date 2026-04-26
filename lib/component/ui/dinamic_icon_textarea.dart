import 'package:banay/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';

class DynamicIconTextArea extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final Color primary;
  final Color panelColor;
  final Color? borderColor;
  final String hintText;
  final String? labelText;
  final Widget? leadingIcon;
  final int minLines;
  final int maxLines;
  final EdgeInsetsGeometry contentPadding;
  final bool showBorder;

  const DynamicIconTextArea({
    super.key,
    required this.controller,
    required this.primary,
    required this.panelColor,
    this.focusNode,
    this.borderColor,
    this.hintText = 'Ecrire ici...',
    this.labelText,
    this.leadingIcon,
    this.minLines = 4,
    this.maxLines = 4,
    this.contentPadding = const EdgeInsets.fromLTRB(14, 12, 14, 12),
    this.showBorder = true,
  });

  @override
  State<DynamicIconTextArea> createState() => _DynamicIconTextAreaState();
}

class _DynamicIconTextAreaState extends State<DynamicIconTextArea> {
  late final FocusNode _focusNode;
  late final bool _ownsFocusNode;

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appColors = theme.appColors;
    final hintColor = isDark
        ? appColors.heroForegroundMuted
        : appColors.mutedText;
    final hasFocus = _focusNode.hasFocus;
    final hasText = widget.controller.text.trim().isNotEmpty;
    final effectiveHintText = hasFocus
        ? widget.hintText
        : hasText
        ? ''
        : (widget.labelText ?? widget.hintText);

    return Container(
      padding: widget.contentPadding,
      decoration: BoxDecoration(
        color: isDark ? appColors.inputFill : widget.panelColor,
        borderRadius: BorderRadius.circular(24),
        border: widget.showBorder
            ? Border.all(color: widget.borderColor ?? appColors.inputBorder)
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.leadingIcon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: SizedBox(
                width: 24,
                height: 24,
                child: Center(child: widget.leadingIcon),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              minLines: widget.minLines,
              maxLines: widget.maxLines,
              textInputAction: TextInputAction.newline,
              style: TextStyle(
                color: isDark
                    ? theme.appColors.heroForeground
                    : theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                hintText: effectiveHintText,
                hintStyle: TextStyle(
                  color: hintColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

