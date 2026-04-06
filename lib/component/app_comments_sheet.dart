import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:bahibo/component/app_attachment_sheet.dart';
import 'package:bahibo/component/app_message_composer.dart';
import 'package:bahibo/component/app_network_image.dart';
import 'package:bahibo/component/profile_models.dart';
import 'package:bahibo/component/seller_profile_page.dart';
import 'package:bahibo/theme/app_theme_extensions.dart';

class AppCommentItem {
  final String? authorId;
  final String authorName;
  final String avatarUrl;
  final String timeLabel;
  final String message;

  const AppCommentItem({
    this.authorId,
    required this.authorName,
    required this.avatarUrl,
    required this.timeLabel,
    required this.message,
  });
}

List<AppCommentItem> defaultAppComments() {
  return const [
    AppCommentItem(
      authorName: 'Miora Andrianiaina',
      avatarUrl:
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=600',
      timeLabel: 'il y a 5 min',
      message: 'Très beau produit, il est toujours disponible ?',
    ),
    AppCommentItem(
      authorName: 'Aina Ravelona',
      avatarUrl:
          'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=600',
      timeLabel: 'il y a 19 min',
      message: 'La finition a l’air propre, j’aime beaucoup.',
    ),
    AppCommentItem(
      authorName: 'Toky Rajaonarison',
      avatarUrl:
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=600',
      timeLabel: 'il y a 1 h',
      message: 'Possible d’avoir plus de détails sur la livraison ?',
    ),
  ];
}

Future<void> showAppCommentsSheet(
  BuildContext context, {
  required int currentCommentCount,
  required List<AppCommentItem> comments,
  required ValueChanged<int> onCommentCountChanged,
  Future<AppCommentItem?> Function(String message)? onSubmitComment,
}) {
  final appColors = Theme.of(context).appColors;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    barrierColor: appColors.overlaySurface,
    backgroundColor: appColors.panelBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _AppCommentsSheetContent(
      initialCommentCount: currentCommentCount,
      comments: comments,
      onCommentCountChanged: onCommentCountChanged,
      onSubmitComment: onSubmitComment,
    ),
  );
}

class _AppCommentsSheetContent extends StatefulWidget {
  final int initialCommentCount;
  final List<AppCommentItem> comments;
  final ValueChanged<int> onCommentCountChanged;
  final Future<AppCommentItem?> Function(String message)? onSubmitComment;

  const _AppCommentsSheetContent({
    required this.initialCommentCount,
    required this.comments,
    required this.onCommentCountChanged,
    this.onSubmitComment,
  });

  @override
  State<_AppCommentsSheetContent> createState() =>
      _AppCommentsSheetContentState();
}

class _AppCommentsSheetContentState extends State<_AppCommentsSheetContent> {
  late final TextEditingController _commentController;
  final ImagePicker _imagePicker = ImagePicker();
  late int _commentCount;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
    _commentCount = widget.initialCommentCount;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _openCommentAuthorProfile(AppCommentItem comment) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SellerProfilePage(
          profile: buildProfileFromUser(
            name: comment.authorName,
            avatarUrl: comment.avatarUrl,
            subtitle: 'Membre de la communaute Bahibo',
          ),
        ),
      ),
    );
  }

  void _openCommentAttachmentSheet() {
    showAppAttachmentSheet(
      context,
      onPhotoTap: _pickCommentImageFromGallery,
      onDocumentTap: _pickCommentDocumentFromFiles,
      onQuickTextTap: _insertQuickCommentText,
    );
  }

  void _insertQuickCommentText() {
    const template =
        'Bonjour, je souhaite avoir plus de details sur ce produit.';
    _commentController
      ..text = template
      ..selection = TextSelection.collapsed(offset: template.length);
    setState(() {});
  }

  Future<void> _pickCommentImageFromGallery() async {
    final file = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    final text = 'Photo ajoutee depuis la galerie: ${file.name}';
    if (widget.onSubmitComment != null) {
      _commentController
        ..text = text
        ..selection = TextSelection.collapsed(offset: text.length);
      setState(() {});
      return;
    }

    _addComment(message: text);
  }

  Future<void> _pickCommentDocumentFromFiles() async {
    final result = await FilePicker.platform.pickFiles(
      withData: false,
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final text =
        'Document ajoute depuis le gestionnaire de fichiers: ${file.name}';
    if (widget.onSubmitComment != null) {
      _commentController
        ..text = text
        ..selection = TextSelection.collapsed(offset: text.length);
      setState(() {});
      return;
    }

    _addComment(message: text);
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    if (widget.onSubmitComment == null) {
      _addComment(message: text);
      _commentController.clear();
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final addedComment = await widget.onSubmitComment!(text);
      if (!mounted) {
        return;
      }
      if (addedComment != null) {
        setState(() {
          widget.comments.insert(0, addedComment);
          _commentCount += 1;
        });
        widget.onCommentCountChanged(_commentCount);
        _commentController.clear();
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _addComment({required String message}) {
    final newComment = AppCommentItem(
      authorName: 'Vous',
      avatarUrl:
          'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=600',
      timeLabel: 'maintenant',
      message: message,
    );

    setState(() {
      widget.comments.insert(0, newComment);
      _commentCount += 1;
    });
    widget.onCommentCountChanged(_commentCount);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.72,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            14,
            18,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: appColors.heroBorder,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Commentaires',
                style: TextStyle(
                  color: appColors.heroForeground,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$_commentCount reactions de la communaute',
                style: TextStyle(
                  color: theme.colorScheme.primary.withValues(alpha: 0.72),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: widget.comments.isEmpty
                    ? Center(
                        child: Text(
                          'Aucun commentaire pour le moment.',
                          style: TextStyle(
                            color: appColors.mutedText,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: widget.comments.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final comment = widget.comments[index];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: appColors.heroSurface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: appColors.heroBorder),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _openCommentAuthorProfile(comment),
                                    customBorder: const CircleBorder(),
                                    child: Container(
                                      padding: const EdgeInsets.all(1.5),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: appColors.success.withValues(alpha: 0.32),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: AppCircleNetworkAvatar(
                                        radius: 18,
                                        imageUrl: comment.avatarUrl,
                                        userId: comment.authorId,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () =>
                                                    _openCommentAuthorProfile(
                                                      comment,
                                                    ),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 2,
                                                      ),
                                                  child: Text(
                                                    comment.authorName,
                                                    style: TextStyle(
                                                      color: theme
                                                          .colorScheme
                                                          .primary,
                                                      fontSize: 13.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Text(
                                            comment.timeLabel,
                                            style: TextStyle(
                                              color: theme.colorScheme.primary
                                                  .withValues(alpha: 0.52),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        comment.message,
                                        style: TextStyle(
                                          color: appColors.heroForeground,
                                          fontSize: 13,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 14),
              const SizedBox.shrink(),
              AppMessageComposer(
                controller: _commentController,
                onAttachmentTap: _openCommentAttachmentSheet,
                onSend: _submitComment,
                primary: theme.colorScheme.primary,
                panelColor: appColors.inputFill,
                borderColor: appColors.inputBorder,
                minLines: 1,
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
