import 'dart:async';

import 'package:flutter/material.dart';

typedef UiChatSendCallback = FutureOr<void> Function(String text);

class UiChatMessageInput extends StatefulWidget {
  final TextEditingController controller;
  final UiChatSendCallback onSend;
  final Color primary;
  final Color panelColor;
  final Color? borderColor;
  final String hintText;
  final bool autoClearOnSend;

  const UiChatMessageInput({
    super.key,
    required this.controller,
    required this.onSend,
    required this.primary,
    required this.panelColor,
    this.borderColor,
    this.hintText = 'Ecrire votre message...',
    this.autoClearOnSend = true,
  });

  @override
  State<UiChatMessageInput> createState() => _UiChatMessageInputState();
}

class _UiChatMessageInputState extends State<UiChatMessageInput> {
  Future<void> _handleSend() async {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;
    await widget.onSend(text);
    if (widget.autoClearOnSend && mounted) {
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
      padding: const EdgeInsets.fromLTRB(7, 3, 5, 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF163228) : widget.panelColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color:
              widget.borderColor ??
              (isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : const Color(0xFFE1EBE4)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              maxLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _handleSend(),
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
          const SizedBox(width: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _handleSend,
              borderRadius: BorderRadius.circular(999),
              child: Ink(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF56C04E),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.primary.withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.north_east_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
