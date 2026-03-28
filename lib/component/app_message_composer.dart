import 'package:flutter/material.dart';

import 'package:bahibo/component/app_text_input.dart';

class AppMessageComposer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onAttachmentTap;
  final VoidCallback onSend;
  final Color primary;
  final Color panelColor;
  final Color? borderColor;
  final String hintText;
  final int minLines;
  final int maxLines;

  const AppMessageComposer({
    super.key,
    required this.controller,
    required this.onAttachmentTap,
    required this.onSend,
    required this.primary,
    required this.panelColor,
    this.borderColor,
    this.hintText = 'Ecrire votre message...',
    this.minLines = 1,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color:
              borderColor ??
              (isDark ? Colors.white10 : const Color(0xFFDFEAE2)),
        ),
      ),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onAttachmentTap,
              borderRadius: BorderRadius.circular(999),
              child: Ink(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add, color: primary, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: minLines,
              maxLines: maxLines,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: appInputDecoration(
                context,
                hintText: hintText,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              style: appInputTextStyle(context),
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onSend,
              borderRadius: BorderRadius.circular(999),
              child: Ink(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primary, primary.withOpacity(0.78)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.30),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.north_east_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
