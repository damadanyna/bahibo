import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:bahibo/component/app_attachment_sheet.dart';
import 'package:bahibo/component/app_back_button.dart';
import 'package:bahibo/component/app_message_composer.dart';
import 'package:flutter/material.dart';
import 'package:bahibo/component/app_network_image.dart';
import 'package:bahibo/component/app_page_skeletons.dart';
import 'package:bahibo/component/app_page_refresh.dart';
import 'package:image_picker/image_picker.dart';

class SellerChatPage extends StatefulWidget {
  const SellerChatPage({super.key});

  @override
  State<SellerChatPage> createState() => _SellerChatPageState();
}

class _SellerChatPageState extends State<SellerChatPage>
    with AppPageRefreshMixin<SellerChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _showEntrySkeleton = true;
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      message: 'Bonjour, le Samsung S20 est-il toujours disponible ?',
      time: '13:00',
      isMine: false,
    ),
    const _ChatMessage(
      message: 'Oui, il est toujours disponible. Interesse ?',
      time: '13:02',
      isMine: true,
    ),
    const _ChatMessage(
      message: 'Oui, je souhaite l\'acheter. Je peux passer aujourd\'hui ?',
      time: '13:04',
      isMine: false,
    ),
    const _ChatMessage(
      message: 'Pas de souci. Je suis disponible a partir de 16h.',
      time: '13:06',
      isMine: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    initializePageRefresh();
    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      setState(() => _showEntrySkeleton = false);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToBottom();
    });
  }

  @override
  void dispose() {
    disposePageRefresh();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Future<void> onPageReload() async {
    if (mounted) {
      setState(() => _showEntrySkeleton = true);
    }
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _showEntrySkeleton = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToBottom();
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final now = TimeOfDay.now();
    final formattedTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    setState(() {
      _messages.add(
        _ChatMessage(message: text, time: formattedTime, isMine: true),
      );
    });

    _messageController.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animateToBottom();
    });
  }

  void _openAttachmentSheet() {
    showAppAttachmentSheet(
      context,
      onPhotoTap: _pickImageFromGallery,
      onDocumentTap: _pickDocumentFromFiles,
      onQuickTextTap: _insertQuickText,
    );
  }

  void _insertQuickText() {
    const template =
        'Bonjour, je vous contacte pour confirmer la disponibilite du produit.';
    _messageController
      ..text = template
      ..selection = TextSelection.collapsed(offset: template.length);
    setState(() {});
  }

  Future<void> _pickImageFromGallery() async {
    final file = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    _addAttachmentMessage(
      _AttachmentType.photo,
      label: file.name,
      bytes: bytes,
      messageText: 'Photo importee depuis la galerie',
    );
  }

  Future<void> _pickDocumentFromFiles() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    _addAttachmentMessage(
      _AttachmentType.document,
      label: file.name,
      bytes: file.bytes,
      messageText: 'Document ajoute depuis le gestionnaire de fichiers',
    );
  }

  void _addAttachmentMessage(
    _AttachmentType type, {
    String? label,
    Uint8List? bytes,
    String? messageText,
  }) {
    final now = TimeOfDay.now();
    final formattedTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    late final _ChatMessage message;
    switch (type) {
      case _AttachmentType.photo:
        message = _ChatMessage(
          message: messageText ?? 'Photo importee',
          time: formattedTime,
          isMine: true,
          attachmentType: _AttachmentType.photo,
          attachmentLabel: label ?? 'Image_produit.jpg',
          attachmentBytes: bytes,
        );
        break;
      case _AttachmentType.document:
        message = _ChatMessage(
          message: messageText ?? 'Document ajoute',
          time: formattedTime,
          isMine: true,
          attachmentType: _AttachmentType.document,
          attachmentLabel: label ?? 'Facture_bahibo.pdf',
          attachmentBytes: bytes,
        );
        break;
      case _AttachmentType.text:
        message = _ChatMessage(
          message: messageText ?? 'Texte ajoute',
          time: formattedTime,
          isMine: true,
          attachmentType: _AttachmentType.text,
          attachmentLabel: label ?? 'Message rapide',
          attachmentBytes: bytes,
        );
        break;
    }

    setState(() {
      _messages.add(message);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animateToBottom();
    });
  }

  void _jumpToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  void _animateToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 120,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final background = isDark
        ? const Color(0xFF031C19)
        : const Color(0xFFEAF5EE);
    final cardColor = isDark ? const Color(0xFF0F2320) : Colors.white;
    final panelColor = isDark
        ? const Color(0xFF142B27)
        : const Color(0xFFF6FBF7);
    final subtleText = isDark ? Colors.white70 : const Color(0xFF5D6C66);
    const sellerName = 'John Rakoto';
    const sellerRole = 'Vendeur certifie';
    const avatarUrl =
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200';

    return Scaffold(
      backgroundColor: background,
      body: _showEntrySkeleton
          ? const SafeArea(child: SellerChatSkeleton())
          : SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            primary.withOpacity(isDark ? 0.12 : 0.08),
                            background,
                            background,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: refreshPageWithDialog,
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                            child: Column(
                              children: [
                                _ChatHeader(
                                  primary: primary,
                                  cardColor: cardColor,
                                  subtleText: subtleText,
                                  sellerName: sellerName,
                                  sellerRole: sellerRole,
                                  avatarUrl: avatarUrl,
                                ),
                                const SizedBox(height: 10),
                                _ProductContextCard(
                                  primary: primary,
                                  cardColor: cardColor,
                                  subtleText: subtleText,
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 18),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: panelColor,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white10
                                          : const Color(0xFFE0EAE4),
                                    ),
                                  ),
                                  child: Text(
                                    'Aujourd\'hui',
                                    style: TextStyle(
                                      color: subtleText,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                ..._messages.map(
                                  (chat) => Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _ChatBubble(
                                      message: chat.message,
                                      time: chat.time,
                                      isMine: chat.isMine,
                                      attachmentType: chat.attachmentType,
                                      attachmentLabel: chat.attachmentLabel,
                                      attachmentBytes: chat.attachmentBytes,
                                      avatarUrl: avatarUrl,
                                      isDark: isDark,
                                      primary: primary,
                                      cardColor: cardColor,
                                      subtleText: subtleText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                        child: AppMessageComposer(
                          controller: _messageController,
                          onAttachmentTap: _openAttachmentSheet,
                          onSend: _sendMessage,
                          primary: primary,
                          panelColor: panelColor,
                        ),
                      ),
                    ],
                  ),
                  Positioned(top: 18, left: 18, child: const AppBackButton()),
                  if (isOffline) const AppOfflineBanner(bottomOffset: 78),
                ],
              ),
            ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final Color primary;
  final Color cardColor;
  final Color subtleText;
  final String sellerName;
  final String sellerRole;
  final String avatarUrl;

  const _ChatHeader({
    required this.primary,
    required this.cardColor,
    required this.subtleText,
    required this.sellerName,
    required this.sellerRole,
    required this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 32, 18, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary.withOpacity(0.92), const Color(0xFF123C2E)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: AppCircleNetworkAvatar(radius: 26, imageUrl: avatarUrl),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sellerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFF7DFFB0),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$sellerRole • En ligne maintenant',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.82),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Text(
                  'Actif',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 7,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cardColor.withOpacity(0.22),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Discutez en toute securite avant de confirmer la transaction.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.86),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductContextCard extends StatelessWidget {
  final Color primary;
  final Color cardColor;
  final Color subtleText;
  final bool isDark;

  const _ProductContextCard({
    required this.primary,
    required this.cardColor,
    required this.subtleText,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE1EBE4),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AppNetworkImage(
              imageUrl:
                  'https://images.unsplash.com/photo-1598327105666-5b89351aff97?w=600',
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Samsung Galaxy S20',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF12201B),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Produit verifie • Disponible',
                  style: TextStyle(
                    color: subtleText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '2 375 000 MGA',
                    style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String message;
  final String time;
  final bool isMine;
  final _AttachmentType? attachmentType;
  final String? attachmentLabel;
  final Uint8List? attachmentBytes;

  const _ChatMessage({
    required this.message,
    required this.time,
    required this.isMine,
    this.attachmentType,
    this.attachmentLabel,
    this.attachmentBytes,
  });
}

enum _AttachmentType { photo, document, text }

class _ChatBubble extends StatelessWidget {
  final String message;
  final String time;
  final bool isMine;
  final _AttachmentType? attachmentType;
  final String? attachmentLabel;
  final Uint8List? attachmentBytes;
  final String avatarUrl;
  final bool isDark;
  final Color primary;
  final Color cardColor;
  final Color subtleText;

  const _ChatBubble({
    required this.message,
    required this.time,
    required this.isMine,
    this.attachmentType,
    this.attachmentLabel,
    this.attachmentBytes,
    required this.avatarUrl,
    required this.isDark,
    required this.primary,
    required this.cardColor,
    required this.subtleText,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine
        ? primary.withOpacity(isDark ? 0.90 : 0.96)
        : cardColor;
    final textColor = isMine
        ? Colors.white
        : (isDark ? Colors.white : const Color(0xFF15211C));
    final metaColor = isMine ? Colors.white70 : subtleText;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMine) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 10),
              child: AppCircleNetworkAvatar(radius: 16, imageUrl: avatarUrl),
            ),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isMine ? 290 : 248),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(22),
                  topRight: const Radius.circular(22),
                  bottomLeft: Radius.circular(isMine ? 22 : 8),
                  bottomRight: Radius.circular(isMine ? 8 : 22),
                ),
                border: Border.all(
                  color: isMine
                      ? Colors.white10
                      : (isDark ? Colors.white10 : const Color(0xFFE3ECE6)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (attachmentType != null) ...[
                    _AttachmentPreview(
                      type: attachmentType!,
                      label: attachmentLabel ?? message,
                      bytes: attachmentBytes,
                      isMine: isMine,
                      isDark: isDark,
                      primary: primary,
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    message,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          color: metaColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isMine) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.done_all_rounded,
                          size: 15,
                          color: Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  final _AttachmentType type;
  final String label;
  final Uint8List? bytes;
  final bool isMine;
  final bool isDark;
  final Color primary;

  const _AttachmentPreview({
    required this.type,
    required this.label,
    this.bytes,
    required this.isMine,
    required this.isDark,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isMine
        ? Colors.white.withOpacity(0.14)
        : (isDark ? Colors.white10 : primary.withOpacity(0.08));
    final textColor = isMine
        ? Colors.white
        : (isDark ? Colors.white : const Color(0xFF15211C));

    IconData icon;
    String title;
    switch (type) {
      case _AttachmentType.photo:
        icon = Icons.photo_outlined;
        title = 'Photo';
        break;
      case _AttachmentType.document:
        icon = Icons.insert_drive_file_outlined;
        title = 'Document';
        break;
      case _AttachmentType.text:
        icon = Icons.notes_outlined;
        title = 'Texte';
        break;
    }

    if (type == _AttachmentType.photo && bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Image.memory(
              bytes!,
              height: 164,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.42),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.photo_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isMine ? Colors.white24 : primary.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: textColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: textColor.withOpacity(0.82),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
