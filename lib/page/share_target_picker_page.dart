import 'dart:io';

import 'package:banay/component/app_network_image.dart';
import 'package:banay/component/ui/chat_message_input.dart';
import 'package:banay/page/chat_page.dart';
import 'package:banay/page/productDetail.dart';
import 'package:banay/services/conversation_share_target_utils.dart';
import 'package:banay/services/conversations_api_service.dart';
import 'package:banay/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class _ResolvedSharedContent {
  const _ResolvedSharedContent({this.attachment, this.text});

  final UiChatAttachment? attachment;
  final String? text;
}

/// "Choose a conversation" screen shown when content is shared into Banay
/// from another app (Android share sheet / iOS share extension). Only the
/// first shared item is forwarded — multi-item shares aren't supported yet.
class ShareTargetPickerPage extends StatefulWidget {
  const ShareTargetPickerPage({super.key, required this.sharedFiles});

  final List<SharedMediaFile> sharedFiles;

  @override
  State<ShareTargetPickerPage> createState() => _ShareTargetPickerPageState();
}

class _ShareTargetPickerPageState extends State<ShareTargetPickerPage> {
  final ConversationsApiService _conversationsApiService =
      ConversationsApiService();
  late final Future<List<Map<String, dynamic>>> _conversationsFuture;
  bool _isOpeningConversation = false;

  @override
  void initState() {
    super.initState();
    _conversationsFuture = loadConversationsForSharing(_conversationsApiService);
  }

  String get _sharePreviewLabel {
    if (widget.sharedFiles.isEmpty) {
      return 'Choisir une conversation';
    }

    final type = widget.sharedFiles.first.type;
    final count = widget.sharedFiles.length;
    switch (type) {
      case SharedMediaType.image:
        return count > 1 ? 'Partager $count photos' : 'Partager une photo';
      case SharedMediaType.video:
        return count > 1 ? 'Partager $count videos' : 'Partager une video';
      case SharedMediaType.file:
        return count > 1 ? 'Partager $count fichiers' : 'Partager un fichier';
      case SharedMediaType.text:
      case SharedMediaType.url:
        return 'Partager ce contenu';
    }
  }

  Future<_ResolvedSharedContent> _resolveSharedContent() async {
    if (widget.sharedFiles.isEmpty) {
      return const _ResolvedSharedContent();
    }

    final first = widget.sharedFiles.first;
    if (first.type == SharedMediaType.text || first.type == SharedMediaType.url) {
      final text = first.path.trim();
      return _ResolvedSharedContent(text: text.isEmpty ? null : text);
    }

    final file = File(first.path);
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      return const _ResolvedSharedContent();
    }

    final separator = Platform.isWindows ? '\\' : '/';
    final fileName = first.path.split(separator).last;

    if (first.type == SharedMediaType.image) {
      final decodedImage = await decodeImageFromList(bytes);
      return _ResolvedSharedContent(
        attachment: UiChatAttachment(
          type: UiChatAttachmentType.photo,
          label: fileName,
          bytes: bytes,
          sizeBytes: bytes.length,
          width: decodedImage.width,
          height: decodedImage.height,
          messageText: 'Photo partagee depuis une autre application',
        ),
      );
    }

    return _ResolvedSharedContent(
      attachment: UiChatAttachment(
        type: UiChatAttachmentType.document,
        label: fileName,
        bytes: bytes,
        sizeBytes: bytes.length,
        messageText: 'Fichier partage depuis une autre application',
      ),
    );
  }

  Future<void> _openConversation(Map<String, dynamic> conversation) async {
    if (_isOpeningConversation) {
      return;
    }
    setState(() => _isOpeningConversation = true);

    _ResolvedSharedContent resolved;
    try {
      resolved = await _resolveSharedContent();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isOpeningConversation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de lire le contenu partage.'),
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    final conversationId = conversationShareId(conversation);
    final participant = conversation['participant'];
    final sellerRole = participant is Map
        ? (participant['roleLabel']?.toString().trim() ?? '')
        : '';

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          conversationId: conversationId,
          conversationUserId: conversationId == null
              ? conversationShareParticipantId(conversation)
              : null,
          productPageBuilder: (product, {openedFromChat = false}) =>
              ProductDetailPage(product: product, openedFromChat: openedFromChat),
          sellerName: conversationShareName(conversation),
          sellerRole: sellerRole.isEmpty ? 'Utilisateur' : sellerRole,
          avatarUrl: conversationShareAvatar(conversation),
          initialMessage: resolved.text,
          initialSharedAttachment: resolved.attachment,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;

    return Scaffold(
      backgroundColor: appColors.backgroundBase,
      appBar: AppBar(title: Text(_sharePreviewLabel)),
      body: SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _conversationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Impossible de charger la liste des discussions.',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              );
            }

            final conversations = snapshot.data ?? const <Map<String, dynamic>>[];
            if (conversations.isEmpty) {
              return Center(
                child: Text(
                  'Aucune discussion disponible.',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              );
            }

            return Stack(
              children: [
                ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: conversations.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final conversation = conversations[index];
                    return ListTile(
                      leading: AppCircleNetworkAvatar(
                        radius: 22,
                        imageUrl: conversationShareAvatar(conversation),
                        userId: conversationShareParticipantId(conversation),
                      ),
                      title: Text(
                        conversationShareName(conversation),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onTap: _isOpeningConversation
                          ? null
                          : () => _openConversation(conversation),
                    );
                  },
                ),
                if (_isOpeningConversation)
                  Container(
                    color: appColors.backgroundBase.withValues(alpha: 0.6),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
