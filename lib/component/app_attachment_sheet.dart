import 'dart:async';

import 'package:flutter/material.dart';

typedef AppAttachmentAction = FutureOr<void> Function();

Future<void> showAppAttachmentSheet(
  BuildContext context, {
  required AppAttachmentAction onPhotoTap,
  required AppAttachmentAction onDocumentTap,
  required AppAttachmentAction onQuickTextTap,
}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final primary = theme.colorScheme.primary;
  final sheetColor = isDark ? const Color(0xFF102522) : Colors.white;
  final mutedColor = isDark ? Colors.white70 : const Color(0xFF5D6C66);

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      Future<void> handleTap(AppAttachmentAction action) async {
        Navigator.of(sheetContext).pop();
        await Future<void>.delayed(const Duration(milliseconds: 180));
        await action();
      }

      return SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
          decoration: BoxDecoration(
            color: sheetColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Ajouter un contenu',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF12201B),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Photo, document ou texte rapide.',
                style: TextStyle(
                  color: mutedColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              _AttachmentActionTile(
                icon: Icons.photo_library_outlined,
                title: 'Photo',
                subtitle: 'Ajouter une image dans la discussion',
                primary: primary,
                isDark: isDark,
                onTap: () {
                  unawaited(handleTap(onPhotoTap));
                },
              ),
              const SizedBox(height: 10),
              _AttachmentActionTile(
                icon: Icons.description_outlined,
                title: 'Document',
                subtitle: 'Joindre un document ou un PDF',
                primary: primary,
                isDark: isDark,
                onTap: () {
                  unawaited(handleTap(onDocumentTap));
                },
              ),
              const SizedBox(height: 10),
              _AttachmentActionTile(
                icon: Icons.notes_outlined,
                title: 'Texte rapide',
                subtitle: 'Inserer un texte pre-rempli',
                primary: primary,
                isDark: isDark,
                onTap: () {
                  unawaited(handleTap(onQuickTextTap));
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _AttachmentActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color primary;
  final bool isDark;
  final VoidCallback onTap;

  const _AttachmentActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF152D29) : const Color(0xFFF4FBF6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white10 : const Color(0xFFE1EBE4),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF12201B),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF5D6C66),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
