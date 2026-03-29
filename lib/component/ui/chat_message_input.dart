import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

enum UiChatAttachmentType { photo, document, quickText }

class UiChatAttachment {
  final UiChatAttachmentType type;
  final String label;
  final Uint8List? bytes;
  final String messageText;

  const UiChatAttachment({
    required this.type,
    required this.label,
    this.bytes,
    required this.messageText,
  });
}

typedef UiChatAttachmentCallback =
    FutureOr<void> Function(UiChatAttachment attachment);
typedef UiChatSendCallback = FutureOr<void> Function(String text);

class UiChatMessageInput extends StatefulWidget {
  final TextEditingController controller;
  final UiChatSendCallback onSend;
  final UiChatAttachmentCallback onAttachmentSelected;
  final Color primary;
  final Color panelColor;
  final Color? borderColor;
  final String hintText;
  final String quickTextTemplate;
  final List<String> documentExtensions;
  final bool autoClearOnSend;
  final bool enableQuickText;

  const UiChatMessageInput({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onAttachmentSelected,
    required this.primary,
    required this.panelColor,
    this.borderColor,
    this.hintText = 'Ecrire votre message...',
    this.quickTextTemplate =
        'Bonjour, je vous contacte pour confirmer la disponibilite du produit.',
    this.documentExtensions = const ['pdf', 'doc', 'docx', 'txt'],
    this.autoClearOnSend = true,
    this.enableQuickText = true,
  });

  @override
  State<UiChatMessageInput> createState() => _UiChatMessageInputState();
}

class _UiChatMessageInputState extends State<UiChatMessageInput> {
  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _handleSend() async {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;
    await widget.onSend(text);
    if (widget.autoClearOnSend && mounted) {
      widget.controller.clear();
    }
  }

  Future<void> _openAttachmentSheet() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sheetColor = isDark ? const Color(0xFF102522) : Colors.white;
    final mutedColor = isDark ? Colors.white70 : const Color(0xFF5D6C66);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        Future<void> handleAction(Future<void> Function() action) async {
          Navigator.of(sheetContext).pop();
          await Future<void>.delayed(const Duration(milliseconds: 180));
          await action();
        }

        return Container(
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
              _UiAttachmentActionTile(
                icon: Icons.photo_library_outlined,
                title: 'Photo',
                subtitle: 'Ajouter une image dans la discussion',
                primary: widget.primary,
                isDark: isDark,
                onTap: () {
                  unawaited(handleAction(_pickPhoto));
                },
              ),
              const SizedBox(height: 10),
              _UiAttachmentActionTile(
                icon: Icons.description_outlined,
                title: 'Document',
                subtitle: 'Joindre un document ou un PDF',
                primary: widget.primary,
                isDark: isDark,
                onTap: () {
                  unawaited(handleAction(_pickDocument));
                },
              ),
              if (widget.enableQuickText) ...[
                const SizedBox(height: 10),
                _UiAttachmentActionTile(
                  icon: Icons.notes_outlined,
                  title: 'Texte rapide',
                  subtitle: 'Inserer un texte pre-rempli',
                  primary: widget.primary,
                  isDark: isDark,
                  onTap: () {
                    unawaited(handleAction(_insertQuickText));
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickPhoto() async {
    final file = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    await widget.onAttachmentSelected(
      UiChatAttachment(
        type: UiChatAttachmentType.photo,
        label: file.name,
        bytes: bytes,
        messageText: 'Photo importee depuis la galerie',
      ),
    );
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: widget.documentExtensions,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    await widget.onAttachmentSelected(
      UiChatAttachment(
        type: UiChatAttachmentType.document,
        label: file.name,
        bytes: file.bytes,
        messageText: 'Document ajoute depuis le gestionnaire de fichiers',
      ),
    );
  }

  Future<void> _insertQuickText() async {
    final template = widget.quickTextTemplate;
    widget.controller
      ..text = template
      ..selection = TextSelection.collapsed(offset: template.length);

    await widget.onAttachmentSelected(
      UiChatAttachment(
        type: UiChatAttachmentType.quickText,
        label: 'Message rapide',
        messageText: template,
      ),
    );
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
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openAttachmentSheet,
              borderRadius: BorderRadius.circular(999),
              child: Ink(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add, color: widget.primary, size: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
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

class _UiAttachmentActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color primary;
  final bool isDark;
  final VoidCallback onTap;

  const _UiAttachmentActionTile({
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
          padding: const EdgeInsets.all(7),
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
                  color: primary.withValues(alpha: 0.12),
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
