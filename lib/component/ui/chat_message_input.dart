import 'dart:async';
import 'dart:typed_data';

import 'package:banay/component/ui/location_picker_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:banay/theme/app_theme_extensions.dart';

enum UiChatAttachmentType { photo, document, location }

const Set<String> _allowedPhotoExtensions = <String>{
  'jpg',
  'jpeg',
  'png',
  'webp',
  'heic',
  'heif',
};
const int _maxPhotoSelectionPerBatch = 15;
const int _maxPhotoAttachmentBytes = 10 * 1024 * 1024;
const int _maxDocumentAttachmentBytes = 12 * 1024 * 1024;

class UiChatAttachment {
  final UiChatAttachmentType type;
  final String label;
  final Uint8List? bytes;
  final int? sizeBytes;
  final int? width;
  final int? height;
  final String? mediaGroupId;
  final String messageText;

  const UiChatAttachment({
    required this.type,
    required this.label,
    this.bytes,
    this.sizeBytes,
    this.width,
    this.height,
    this.mediaGroupId,
    required this.messageText,
  });
}

typedef UiChatAttachmentCallback =
    FutureOr<void> Function(UiChatAttachment attachment);
typedef UiChatSendCallback = FutureOr<void> Function(String text);
typedef UiChatTextChangedCallback = FutureOr<void> Function(String text);

class UiChatMessageInput extends StatefulWidget {
  final TextEditingController controller;
  final UiChatSendCallback onSend;
  final UiChatAttachmentCallback onAttachmentSelected;
  final Color primary;
  final Color panelColor;
  final Color? borderColor;
  final String hintText;
  final List<String> documentExtensions;
  final bool autoClearOnSend;
  final bool enableDocument;
  final bool enableLocation;
  final bool canSendWithoutText;
  final bool allowMultipleDocumentSelection;
  final UiChatTextChangedCallback? onTextChanged;

  // Backward-compatible aliases so hot reload can survive the renamed option.
  bool get enableQuickText => enableLocation;
  String get quickTextTemplate => '';

  const UiChatMessageInput({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onAttachmentSelected,
    required this.primary,
    required this.panelColor,
    this.borderColor,
    this.hintText = 'Ecrire votre message...',
    this.documentExtensions = const ['pdf', 'doc', 'docx', 'txt'],
    this.autoClearOnSend = true,
    this.enableDocument = true,
    this.enableLocation = true,
    this.canSendWithoutText = false,
    this.allowMultipleDocumentSelection = true,
    this.onTextChanged,
  });

  @override
  State<UiChatMessageInput> createState() => _UiChatMessageInputState();
}

class _UiChatMessageInputState extends State<UiChatMessageInput> {
  static const int _maxComposerLines = 6;

  final ImagePicker _imagePicker = ImagePicker();

  void _showAttachmentError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _fileExtension(String fileName) {
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot < 0 || lastDot == fileName.length - 1) {
      return '';
    }

    return fileName.substring(lastDot + 1).toLowerCase();
  }

  String _createMediaGroupId(UiChatAttachmentType type) {
    final typeLabel = switch (type) {
      UiChatAttachmentType.photo => 'image',
      UiChatAttachmentType.document => 'document',
      UiChatAttachmentType.location => 'location',
    };
    return '$typeLabel-${DateTime.now().microsecondsSinceEpoch}';
  }

  Future<void> _handleSend() async {
    final text = widget.controller.text.trim();
    if (text.isEmpty && !widget.canSendWithoutText) return;
    await widget.onSend(text);
    if (widget.autoClearOnSend && mounted) {
      widget.controller.clear();
    }
  }

  Future<void> _openAttachmentSheet() async {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final sheetColor = theme.cardColor;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        Future<void> handleAction(Future<void> Function() action) async {
          Navigator.of(sheetContext).pop();
          await Future<void>.delayed(const Duration(milliseconds: 180));
          await action();
        }

        final maxSheetHeight = MediaQuery.of(sheetContext).size.height * 0.82;

        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxSheetHeight),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
              decoration: BoxDecoration(
                color: sheetColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 28,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 46,
                        height: 5,
                        decoration: BoxDecoration(
                          color: appColors.inputBorder,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.02,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _UiAttachmentActionTile(
                          title: 'Photo',
                          primary: widget.primary,
                          isDark: theme.brightness == Brightness.dark,
                          illustration: _UiAttachmentIllustrationType.photo,
                          onTap: () {
                            unawaited(handleAction(_pickPhoto));
                          },
                        ),
                        _UiAttachmentActionTile(
                          title: 'Camera',
                          primary: widget.primary,
                          isDark: theme.brightness == Brightness.dark,
                          illustration: _UiAttachmentIllustrationType.camera,
                          onTap: () {
                            unawaited(handleAction(_capturePhoto));
                          },
                        ),
                        if (widget.enableDocument)
                          _UiAttachmentActionTile(
                            title: 'Document',
                            primary: widget.primary,
                            isDark: theme.brightness == Brightness.dark,
                            illustration:
                                _UiAttachmentIllustrationType.document,
                            onTap: () {
                              unawaited(handleAction(_pickDocument));
                            },
                          ),
                        if (widget.enableLocation)
                          _UiAttachmentActionTile(
                            title: 'Localisation',
                            primary: widget.primary,
                            isDark: theme.brightness == Brightness.dark,
                            illustration:
                                _UiAttachmentIllustrationType.location,
                            onTap: () {
                              unawaited(handleAction(_insertCurrentLocation));
                            },
                          ),
                      ],
                    ),
                    if (widget.enableLocation) ...[const SizedBox(height: 2)],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _capturePhoto() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
      maxWidth: 1600,
      maxHeight: 1600,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (file == null) {
      return;
    }

    await _handleSinglePhotoFile(
      file,
      messageText: 'Photo prise avec l\'appareil photo',
    );
  }

  Future<void> _pickPhoto() async {
    final pickedFiles = await _imagePicker.pickMultiImage(
      imageQuality: 82,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (pickedFiles.isEmpty) return;

    final hasSelectionOverflow =
        pickedFiles.length > _maxPhotoSelectionPerBatch;
    final files = pickedFiles
        .take(_maxPhotoSelectionPerBatch)
        .toList(growable: false);

    var hasRejectedPhoto = hasSelectionOverflow;
    final mediaGroupId = files.length > 1
        ? _createMediaGroupId(UiChatAttachmentType.photo)
        : null;

    for (final file in files) {
      final wasAccepted = await _handleSinglePhotoFile(
        file,
        mediaGroupId: mediaGroupId,
        messageText: 'Photo importee depuis la galerie',
      );
      if (!wasAccepted) {
        hasRejectedPhoto = true;
      }
    }

    if (hasRejectedPhoto) {
      _showAttachmentError(
        hasSelectionOverflow
            ? 'Maximum 15 images par chargement. Les images supplementaires ont ete ignorees.'
            : 'Certaines photos ont ete ignorees car leur format ou leur taille n\'est pas pris en charge.',
      );
    }
  }

  Future<bool> _handleSinglePhotoFile(
    XFile file, {
    String? mediaGroupId,
    required String messageText,
  }) async {
    final extension = _fileExtension(file.name);
    if (!_allowedPhotoExtensions.contains(extension)) {
      return false;
    }

    final fileLength = await file.length();
    if (fileLength > _maxPhotoAttachmentBytes) {
      return false;
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      return false;
    }

    final decodedImage = await decodeImageFromList(bytes);
    await widget.onAttachmentSelected(
      UiChatAttachment(
        type: UiChatAttachmentType.photo,
        label: file.name,
        bytes: bytes,
        sizeBytes: fileLength,
        width: decodedImage.width,
        height: decodedImage.height,
        mediaGroupId: mediaGroupId,
        messageText: messageText,
      ),
    );
    return true;
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: widget.allowMultipleDocumentSelection,
      type: FileType.custom,
      allowedExtensions: widget.documentExtensions,
    );

    if (result == null || result.files.isEmpty) return;

    var hasRejectedDocument = false;
    final mediaGroupId = result.files.length > 1
        ? _createMediaGroupId(UiChatAttachmentType.document)
        : null;

    for (final file in result.files) {
      final extension = _fileExtension(file.name);
      if (!widget.documentExtensions.contains(extension)) {
        hasRejectedDocument = true;
        continue;
      }

      if (file.size > _maxDocumentAttachmentBytes) {
        hasRejectedDocument = true;
        continue;
      }

      if (file.bytes == null || file.bytes!.isEmpty) {
        hasRejectedDocument = true;
        continue;
      }

      await widget.onAttachmentSelected(
        UiChatAttachment(
          type: UiChatAttachmentType.document,
          label: file.name,
          bytes: file.bytes,
          sizeBytes: file.size,
          mediaGroupId: mediaGroupId,
          messageText: 'Document ajoute depuis le gestionnaire de fichiers',
        ),
      );
    }

    if (hasRejectedDocument) {
      _showAttachmentError(
        'Certains documents ont ete ignores car leur format, leur taille ou leur contenu n\'est pas valide.',
      );
    }
  }

  Future<void> _insertCurrentLocation() async {
    final selection = await Navigator.of(context).push<UiLocationSelection>(
      MaterialPageRoute(
        builder: (_) => UiLocationPickerPage(primary: widget.primary),
      ),
    );
    if (!mounted || selection == null) {
      return;
    }

    final mapsUrl =
        'https://maps.google.com/?q=${selection.latitude},${selection.longitude}';
    final message = 'Ma localisation: ${selection.title}\n$mapsUrl';

    widget.controller
      ..text = message
      ..selection = TextSelection.collapsed(offset: message.length);

    await widget.onAttachmentSelected(
      UiChatAttachment(
        type: UiChatAttachmentType.location,
        label: selection.title,
        messageText: message,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final hintColor = appColors.mutedText;

    return Container(
      padding: const EdgeInsets.fromLTRB(7, 3, 5, 3),
      decoration: BoxDecoration(
        color: widget.panelColor,
        // Half of the single-line height (3 + 50 + 3): a pill on one line,
        // a rounded rectangle once the field grows, so text never runs into
        // the curved corners.
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: widget.borderColor ?? appColors.inputBorder),
      ),
      child: Row(
        // Buttons stay anchored to the bottom while the field grows upward,
        // like WhatsApp / Messenger / Teams composers.
        crossAxisAlignment: CrossAxisAlignment.end,
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
            // A single line is centered against the 50px send button; extra
            // lines expand above it (up to _maxComposerLines).
            child: Container(
              constraints: const BoxConstraints(minHeight: 50),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: TextField(
                controller: widget.controller,
                minLines: 1,
                maxLines: _maxComposerLines,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.newline,
                onChanged: widget.onTextChanged,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  filled: false,
                  fillColor: Colors.transparent,
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
                  color: widget.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.primary.withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.north_east_rounded,
                  color: theme.colorScheme.onPrimary,
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

enum _UiAttachmentIllustrationType { photo, camera, document, location }

class _UiAttachmentActionTile extends StatelessWidget {
  final String title;
  final Color primary;
  final bool isDark;
  final _UiAttachmentIllustrationType illustration;
  final VoidCallback onTap;

  const _UiAttachmentActionTile({
    required this.title,
    required this.primary,
    required this.isDark,
    required this.illustration,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: _UiAttachmentIllustration(
                    type: illustration,
                    primary: primary,
                    isDark: isDark,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UiAttachmentIllustration extends StatelessWidget {
  final _UiAttachmentIllustrationType type;
  final Color primary;
  final bool isDark;

  const _UiAttachmentIllustration({
    required this.type,
    required this.primary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white;

    return Container(
      width: 98,
      height: 86,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primary.withValues(alpha: 0.12)),
      ),
      child: switch (type) {
        _UiAttachmentIllustrationType.photo => _UiPhotoAttachmentPreview(
          cardColor: cardColor,
        ),
        _UiAttachmentIllustrationType.camera => _UiCameraAttachmentPreview(
          cardColor: cardColor,
          primary: primary,
        ),
        _UiAttachmentIllustrationType.document => _UiDocumentAttachmentPreview(
          cardColor: cardColor,
        ),
        _UiAttachmentIllustrationType.location => _UiLocationAttachmentPreview(
          cardColor: cardColor,
          primary: primary,
        ),
      },
    );
  }
}

class _UiPhotoAttachmentPreview extends StatelessWidget {
  final Color cardColor;

  const _UiPhotoAttachmentPreview({required this.cardColor});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 12,
          top: 6,
          child: Transform.rotate(
            angle: 0.1,
            child: _UiPreviewFrame(cardColor: cardColor),
          ),
        ),
        Positioned(
          left: 0,
          top: 16,
          child: _UiPreviewFrame(cardColor: cardColor),
        ),
      ],
    );
  }
}

class _UiPreviewFrame extends StatelessWidget {
  final Color cardColor;

  const _UiPreviewFrame({required this.cardColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFA8E0FF), Color(0xFF58C27D)],
          ),
        ),
        child: const Stack(
          children: [
            Positioned(
              left: 5,
              top: 5,
              child: Icon(
                Icons.wb_sunny_rounded,
                color: Colors.white,
                size: 10,
              ),
            ),
            Positioned(
              left: 6,
              right: 6,
              bottom: 6,
              child: Icon(
                Icons.landscape_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UiDocumentAttachmentPreview extends StatelessWidget {
  final Color cardColor;

  const _UiDocumentAttachmentPreview({required this.cardColor});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 64,
        height: 74,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFF5F7FB)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: 0,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EEF8),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              top: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFD32F2F)],
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'PDF',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              top: 40,
              child: Column(
                children: List.generate(
                  4,
                  (index) => Container(
                    margin: EdgeInsets.only(bottom: index == 3 ? 0 : 6),
                    height: index == 0 ? 5 : 4,
                    width: index == 3 ? 26 : double.infinity,
                    decoration: BoxDecoration(
                      color: index == 0
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFFD5DDEA),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UiCameraAttachmentPreview extends StatelessWidget {
  final Color cardColor;
  final Color primary;

  const _UiCameraAttachmentPreview({
    required this.cardColor,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 68,
        height: 54,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(Icons.photo_camera_rounded, color: primary, size: 32),
      ),
    );
  }
}

class _UiLocationAttachmentPreview extends StatelessWidget {
  final Color cardColor;
  final Color primary;

  const _UiLocationAttachmentPreview({
    required this.cardColor,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: cardColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          Icon(Icons.location_on_rounded, color: primary, size: 34),
          Positioned(
            bottom: 10,
            child: Container(
              width: 28,
              height: 6,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
