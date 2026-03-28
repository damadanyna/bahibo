import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:bahibo/component/app_attachment_sheet.dart';
import 'package:bahibo/component/app_network_image.dart';
import 'package:bahibo/component/app_text_input.dart';

class AppCommentData {
  final String authorName;
  final String avatarUrl;
  final String timeLabel;
  final String message;

  const AppCommentData({
    required this.authorName,
    required this.avatarUrl,
    required this.timeLabel,
    required this.message,
  });
}

Future<void> showAppCommentsSheet(
  BuildContext context, {
  required List<dynamic> comments,
  required int totalCount,
  required ValueChanged<AppCommentData> onAuthorTap,
  ValueChanged<int>? onCountChanged,
}) async {
  final commentController = TextEditingController();
  final imagePicker = ImagePicker();
  var currentCount = totalCount;

  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            void addComment(AppCommentData comment) {
              comments.insert(0, comment);
              currentCount += 1;
              onCountChanged?.call(currentCount);
              setSheetState(() {});
            }

            AppCommentData normalizeComment(dynamic comment) {
              if (comment is AppCommentData) return comment;

              final dynamic source = comment;
              return AppCommentData(
                authorName: source.authorName as String,
                avatarUrl: source.avatarUrl as String,
                timeLabel: source.timeLabel as String,
                message: source.message as String,
              );
            }

            void submitComment() {
              final text = commentController.text.trim();
              if (text.isEmpty) return;

              addComment(
                AppCommentData(
                  authorName: 'Vous',
                  avatarUrl:
                      'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=600',
                  timeLabel: 'maintenant',
                  message: text,
                ),
              );
              commentController.clear();
            }

            void insertQuickText() {
              const template =
                  'Bonjour, je souhaite avoir plus de details sur ce produit.';
              commentController
                ..text = template
                ..selection = TextSelection.collapsed(offset: template.length);
              setSheetState(() {});
            }

            Future<void> pickImage() async {
              final file = await imagePicker.pickImage(
                source: ImageSource.gallery,
              );
              if (file == null) return;

              addComment(
                AppCommentData(
                  authorName: 'Vous',
                  avatarUrl:
                      'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=600',
                  timeLabel: 'maintenant',
                  message: 'Photo ajoutee depuis la galerie: ${file.name}',
                ),
              );
            }

            Future<void> pickDocument() async {
              final result = await FilePicker.platform.pickFiles(
                withData: false,
                allowMultiple: false,
                type: FileType.custom,
                allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
              );

              if (result == null || result.files.isEmpty) return;
              final file = result.files.single;
              addComment(
                AppCommentData(
                  authorName: 'Vous',
                  avatarUrl:
                      'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=600',
                  timeLabel: 'maintenant',
                  message:
                      'Document ajoute depuis le gestionnaire de fichiers: ${file.name}',
                ),
              );
            }

            return SafeArea(
              child: FractionallySizedBox(
                heightFactor: 0.72,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    14,
                    18,
                    20 + MediaQuery.of(sheetContext).viewInsets.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 46,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Commentaires',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$currentCount reactions de la communaute',
                        style: TextStyle(
                          color: Colors.green.withOpacity(0.66),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.separated(
                          itemCount: comments.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final comment = normalizeComment(comments[index]);
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.08),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => onAuthorTap(comment),
                                      customBorder: const CircleBorder(),
                                      child: Container(
                                        padding: const EdgeInsets.all(1.5),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(
                                              0xFF2DA56A,
                                            ).withOpacity(0.32),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: AppCircleNetworkAvatar(
                                          radius: 18,
                                          imageUrl: comment.avatarUrl,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: () =>
                                                      onAuthorTap(comment),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 2,
                                                        ),
                                                    child: Text(
                                                      comment.authorName,
                                                      style: const TextStyle(
                                                        color: Colors.green,
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
                                                color: Colors.green.withOpacity(
                                                  0.46,
                                                ),
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
                                            color: Colors.white.withOpacity(
                                              0.88,
                                            ),
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
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F2A23),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFF23493D)),
                        ),
                        child: Row(
                          children: [
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  showAppAttachmentSheet(
                                    context,
                                    onPhotoTap: pickImage,
                                    onDocumentTap: pickDocument,
                                    onQuickTextTap: insertQuickText,
                                  );
                                },
                                borderRadius: BorderRadius.circular(999),
                                child: Ink(
                                  width: 36,
                                  height: 36,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1B3B30),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: Color(0xFF62C95F),
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: commentController,
                                minLines: 1,
                                maxLines: 3,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => submitComment(),
                                decoration: appInputDecoration(
                                  sheetContext,
                                  hintText: 'Ecrire votre message...',
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                ),
                                style: appInputTextStyle(sheetContext),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: submitComment,
                                borderRadius: BorderRadius.circular(999),
                                child: Ink(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF57C84D),
                                        Color(0xFF2EA84B),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF2EA84B,
                                        ).withOpacity(0.30),
                                        blurRadius: 18,
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
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  } finally {
    commentController.dispose();
  }
}
