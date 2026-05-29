import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:banay/component/app_attachment_sheet.dart';
import 'package:banay/component/app_message_composer.dart';
import 'package:banay/component/app_network_image.dart';
import 'package:banay/component/profile_models.dart';
import 'package:banay/component/seller_profile_page.dart';
import 'package:banay/component/user_profile_page.dart';
import 'package:banay/services/catalog_api_service.dart';
import 'package:banay/theme/app_theme_extensions.dart';

class AppCommentMention {
  final String? id;
  final String userId;
  final String displayName;
  final String avatarUrl;

  const AppCommentMention({
    this.id,
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
  });

  String get trigger => '@$displayName';
}

class AppCommentSubmission {
  final String content;
  final String? parentCommentId;
  final List<String> mentionUserIds;

  const AppCommentSubmission({
    required this.content,
    this.parentCommentId,
    this.mentionUserIds = const <String>[],
  });
}

class AppCommentItem {
  final String? id;
  final String? parentCommentId;
  final String? authorId;
  final String authorName;
  final String avatarUrl;
  final String timeLabel;
  final String message;
  final List<AppCommentMention> mentions;
  List<AppCommentItem> replies;

  AppCommentItem({
    this.id,
    this.parentCommentId,
    this.authorId,
    required this.authorName,
    required this.avatarUrl,
    required this.timeLabel,
    required this.message,
    this.mentions = const <AppCommentMention>[],
    List<AppCommentItem> replies = const <AppCommentItem>[],
  }) : replies = List<AppCommentItem>.from(replies);

  String? get normalizedId {
    final value = id?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  String? get threadRootCommentId {
    final parentId = parentCommentId?.trim();
    if (parentId != null && parentId.isNotEmpty) {
      return parentId;
    }
    return normalizedId;
  }
}

List<AppCommentItem> defaultAppComments() {
  return <AppCommentItem>[
    AppCommentItem(
      id: 'default-1',
      authorName: 'Miora Andrianiaina',
      avatarUrl:
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=600',
      timeLabel: 'il y a 5 min',
      message: 'Tres beau produit, il est toujours disponible ?',
      replies: <AppCommentItem>[
        AppCommentItem(
          id: 'default-1-1',
          parentCommentId: 'default-1',
          authorName: 'BANAY Shop',
          avatarUrl:
              'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=600',
          timeLabel: 'il y a 2 min',
          message:
              'Oui, il est disponible. Vous pouvez nous ecrire en message prive.',
        ),
      ],
    ),
    AppCommentItem(
      id: 'default-2',
      authorName: 'Aina Ravelona',
      avatarUrl:
          'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=600',
      timeLabel: 'il y a 19 min',
      message: 'La finition a l\'air propre, j\'aime beaucoup.',
    ),
    AppCommentItem(
      id: 'default-3',
      authorName: 'Toky Rajaonarison',
      avatarUrl:
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=600',
      timeLabel: 'il y a 1 h',
      message:
          '@Miora Andrianiaina je me pose la meme question pour la livraison.',
      mentions: const <AppCommentMention>[
        AppCommentMention(
          userId: 'default-user-1',
          displayName: 'Miora Andrianiaina',
          avatarUrl:
              'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=600',
        ),
      ],
    ),
  ];
}

typedef AppCommentSubmitHandler =
    Future<AppCommentItem?> Function(AppCommentSubmission submission);
typedef AppCommentMentionSearch =
    Future<List<AppCommentMention>> Function(String query);

Future<void> showAppCommentsSheet(
  BuildContext context, {
  required int currentCommentCount,
  required List<AppCommentItem> comments,
  required ValueChanged<int> onCommentCountChanged,
  AppCommentSubmitHandler? onSubmitComment,
  AppCommentMentionSearch? onSearchMentions,
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
      onSearchMentions: onSearchMentions,
    ),
  );
}

class _AppCommentsSheetContent extends StatefulWidget {
  final int initialCommentCount;
  final List<AppCommentItem> comments;
  final ValueChanged<int> onCommentCountChanged;
  final AppCommentSubmitHandler? onSubmitComment;
  final AppCommentMentionSearch? onSearchMentions;

  const _AppCommentsSheetContent({
    required this.initialCommentCount,
    required this.comments,
    required this.onCommentCountChanged,
    this.onSubmitComment,
    this.onSearchMentions,
  });

  @override
  State<_AppCommentsSheetContent> createState() =>
      _AppCommentsSheetContentState();
}

class _AppCommentsSheetContentState extends State<_AppCommentsSheetContent> {
  static const String _defaultAvatarUrl =
      'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=600';

  late final TextEditingController _commentController;
  final ImagePicker _imagePicker = ImagePicker();
  final CatalogApiService _catalogApiService = CatalogApiService();
  late int _commentCount;
  bool _isSubmitting = false;
  bool _isSearchingMentions = false;
  AppCommentItem? _replyingTo;
  _ActiveMentionQuery? _activeMentionQuery;
  List<AppCommentMention> _mentionSuggestions = const <AppCommentMention>[];
  final Map<String, AppCommentMention> _insertedMentions =
      <String, AppCommentMention>{};
  int _mentionSearchRequestId = 0;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController()
      ..addListener(_handleComposerChanged);
    _commentCount = widget.initialCommentCount;
  }

  @override
  void dispose() {
    _commentController
      ..removeListener(_handleComposerChanged)
      ..dispose();
    super.dispose();
  }

  void _openCommentAuthorProfile(AppCommentItem comment) {
    final authorId = comment.authorId?.trim() ?? '';
    if (authorId.isEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserProfilePage(
            profile: buildProfileFromUser(
              userId: null,
              name: comment.authorName,
              avatarUrl: comment.avatarUrl,
              subtitle: 'Membre de la communaute BANAY',
            ),
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FutureBuilder<Map<String, dynamic>>(
          future: _catalogApiService.fetchUserProfile(authorId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Scaffold(
                backgroundColor: Theme.of(context).appColors.backgroundBase,
                body: const Center(child: CircularProgressIndicator()),
              );
            }
            final data = snapshot.data!;
            final profile = buildPublicUserProfileFromApi(data);
            final role =
                (data['role'] as String?)?.trim().toUpperCase() ?? '';
            if (role == 'SELLER' &&
                (profile.sellerProfileId?.isNotEmpty == true)) {
              return SellerProfilePage(profile: profile);
            }
            return UserProfilePage(profile: profile);
          },
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
  }

  Future<void> _pickCommentImageFromGallery() async {
    final file = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (file == null) {
      return;
    }

    final text = 'Photo ajoutee depuis la galerie: ${file.name}';
    _commentController
      ..text = text
      ..selection = TextSelection.collapsed(offset: text.length);
  }

  Future<void> _pickCommentDocumentFromFiles() async {
    final result = await FilePicker.platform.pickFiles(
      withData: false,
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: <String>['pdf', 'doc', 'docx', 'txt'],
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    final text =
        'Document ajoute depuis le gestionnaire de fichiers: ${file.name}';
    _commentController
      ..text = text
      ..selection = TextSelection.collapsed(offset: text.length);
  }

  void _handleComposerChanged() {
    _pruneMentions();
    _refreshMentionSuggestions();
    if (mounted) {
      setState(() {});
    }
  }

  void _pruneMentions() {
    final text = _commentController.text;
    final keysToRemove = _insertedMentions.entries
        .where((entry) => !text.contains(entry.value.trigger))
        .map((entry) => entry.key)
        .toList();

    for (final key in keysToRemove) {
      _insertedMentions.remove(key);
    }
  }

  Future<void> _refreshMentionSuggestions() async {
    final nextMentionQuery = _extractActiveMentionQuery();
    if (nextMentionQuery == null || widget.onSearchMentions == null) {
      if (_activeMentionQuery != null ||
          _mentionSuggestions.isNotEmpty ||
          _isSearchingMentions) {
        setState(() {
          _activeMentionQuery = null;
          _mentionSuggestions = const <AppCommentMention>[];
          _isSearchingMentions = false;
        });
      }
      return;
    }

    if (nextMentionQuery.query.trim().isEmpty) {
      setState(() {
        _activeMentionQuery = nextMentionQuery;
        _mentionSuggestions = const <AppCommentMention>[];
        _isSearchingMentions = false;
      });
      return;
    }

    final requestId = ++_mentionSearchRequestId;
    setState(() {
      _activeMentionQuery = nextMentionQuery;
      _isSearchingMentions = true;
    });

    final suggestions = await widget.onSearchMentions!(nextMentionQuery.query);
    if (!mounted || requestId != _mentionSearchRequestId) {
      return;
    }

    setState(() {
      _mentionSuggestions = suggestions;
      _isSearchingMentions = false;
    });
  }

  _ActiveMentionQuery? _extractActiveMentionQuery() {
    final selection = _commentController.selection;
    if (!selection.isValid || selection.baseOffset < 0) {
      return null;
    }

    final cursorOffset = selection.baseOffset;
    final textBeforeCursor = _commentController.text.substring(0, cursorOffset);
    final mentionStart = textBeforeCursor.lastIndexOf('@');
    if (mentionStart < 0) {
      return null;
    }

    if (mentionStart > 0) {
      final previousCharacter = textBeforeCursor[mentionStart - 1];
      if (!RegExp(r'\s').hasMatch(previousCharacter)) {
        return null;
      }
    }

    final mentionText = textBeforeCursor.substring(mentionStart + 1);
    if (mentionText.contains(RegExp(r'\s'))) {
      return null;
    }

    return _ActiveMentionQuery(
      query: mentionText,
      start: mentionStart,
      end: cursorOffset,
    );
  }

  void _selectMention(AppCommentMention mention) {
    final activeMentionQuery = _activeMentionQuery;
    if (activeMentionQuery == null) {
      return;
    }

    final replacement = '${mention.trigger} ';
    final currentText = _commentController.text;
    final updatedText = currentText.replaceRange(
      activeMentionQuery.start,
      activeMentionQuery.end,
      replacement,
    );
    final updatedOffset = activeMentionQuery.start + replacement.length;

    _insertedMentions[_normalizeMentionKey(mention.trigger)] = mention;
    _commentController.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(offset: updatedOffset),
    );

    setState(() {
      _activeMentionQuery = null;
      _mentionSuggestions = const <AppCommentMention>[];
      _isSearchingMentions = false;
    });
  }

  String _normalizeMentionKey(String value) {
    return value.trim().toLowerCase();
  }

  List<AppCommentMention> _collectMentionObjects(String text) {
    return _insertedMentions.values
        .where((mention) => text.contains(mention.trigger))
        .toList(growable: false);
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSubmitting) {
      return;
    }

    final mentionedUsers = _collectMentionObjects(text);
    final threadRootCommentId = _replyingTo?.threadRootCommentId;
    final submission = AppCommentSubmission(
      content: text,
      parentCommentId: threadRootCommentId,
      mentionUserIds: mentionedUsers
          .map((mention) => mention.userId.trim())
          .where((userId) => userId.isNotEmpty)
          .toList(growable: false),
    );

    if (widget.onSubmitComment == null) {
      _insertComment(
        AppCommentItem(
          id: 'local-${DateTime.now().microsecondsSinceEpoch}',
          parentCommentId: threadRootCommentId,
          authorName: 'Vous',
          avatarUrl: _defaultAvatarUrl,
          timeLabel: 'maintenant',
          message: text,
          mentions: mentionedUsers,
        ),
      );
      _resetComposer();
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final addedComment = await widget.onSubmitComment!(submission);
      if (!mounted) {
        return;
      }
      if (addedComment != null) {
        _insertComment(addedComment);
        _resetComposer();
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _insertComment(AppCommentItem comment) {
    setState(() {
      if (!_insertIntoReplies(widget.comments, comment)) {
        widget.comments.insert(0, comment);
      }
      _commentCount += 1;
    });
    widget.onCommentCountChanged(_commentCount);
  }

  bool _insertIntoReplies(
    List<AppCommentItem> items,
    AppCommentItem newComment,
  ) {
    final parentCommentId = newComment.parentCommentId?.trim();
    if (parentCommentId == null || parentCommentId.isEmpty) {
      return false;
    }

    for (final item in items) {
      final itemId = item.normalizedId;
      if (itemId != null && itemId == parentCommentId) {
        item.replies.add(newComment);
        return true;
      }
    }

    return false;
  }

  void _resetComposer() {
    _commentController.clear();
    setState(() {
      _replyingTo = null;
      _activeMentionQuery = null;
      _mentionSuggestions = const <AppCommentMention>[];
      _insertedMentions.clear();
    });
  }

  void _startReply(AppCommentItem comment) {
    final replyPrefix = '@${comment.authorName} ';
    _insertedMentions[_normalizeMentionKey(
      replyPrefix.trim(),
    )] = AppCommentMention(
      userId: comment.authorId ?? '',
      displayName: comment.authorName,
      avatarUrl: comment.avatarUrl,
    );
    _commentController
      ..text = replyPrefix
      ..selection = TextSelection.collapsed(offset: replyPrefix.length);
    setState(() => _replyingTo = comment);
  }

  int _effectiveDepth(AppCommentItem comment, int depth) {
    final threadRootCommentId = comment.threadRootCommentId;
    final commentId = comment.normalizedId;
    if (threadRootCommentId != null && commentId != null) {
      return threadRootCommentId == commentId ? 0 : 1;
    }
    return depth > 0 ? 1 : 0;
  }

  Widget _buildMessageText(BuildContext context, AppCommentItem comment) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    if (comment.mentions.isEmpty) {
      return Text(
        comment.message,
        style: TextStyle(
          color: appColors.heroForeground,
          fontSize: 13,
          height: 1.35,
        ),
      );
    }

    final spans = <TextSpan>[];
    final lowerMessage = comment.message.toLowerCase();
    var cursor = 0;

    while (cursor < comment.message.length) {
      var nextIndex = -1;
      AppCommentMention? nextMention;
      for (final mention in comment.mentions) {
        final index = lowerMessage.indexOf(
          mention.trigger.toLowerCase(),
          cursor,
        );
        if (index >= 0 && (nextIndex < 0 || index < nextIndex)) {
          nextIndex = index;
          nextMention = mention;
        }
      }

      if (nextIndex < 0 || nextMention == null) {
        spans.add(
          TextSpan(
            text: comment.message.substring(cursor),
            style: TextStyle(
              color: appColors.heroForeground,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        );
        break;
      }

      if (nextIndex > cursor) {
        spans.add(
          TextSpan(
            text: comment.message.substring(cursor, nextIndex),
            style: TextStyle(
              color: appColors.heroForeground,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        );
      }

      spans.add(
        TextSpan(
          text: comment.message.substring(
            nextIndex,
            nextIndex + nextMention.trigger.length,
          ),
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

      cursor = nextIndex + nextMention.trigger.length;
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildCommentThread(
    BuildContext context,
    AppCommentItem comment, {
    int depth = 0,
  }) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final effectiveDepth = _effectiveDepth(comment, depth);
    final isReply = effectiveDepth > 0;
    final avatarRadius = isReply ? 15.0 : 19.0;
    final hasReplies = comment.replies.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            GestureDetector(
              onTap: () => _openCommentAuthorProfile(comment),
              child: Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                ),
                child: AppCircleNetworkAvatar(
                  radius: avatarRadius,
                  imageUrl: comment.avatarUrl,
                  userId: comment.authorId,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _openCommentAuthorProfile(comment),
                          child: Text(
                            comment.authorName,
                            style: TextStyle(
                              color: appColors.heroForeground,
                              fontSize: isReply ? 12.5 : 13.5,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        comment.timeLabel,
                        style: TextStyle(
                          color: appColors.mutedText,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  _buildMessageText(context, comment),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      GestureDetector(
                        onTap: () => _startReply(comment),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.reply_rounded,
                              size: 13,
                              color: appColors.mutedText,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Répondre',
                              style: TextStyle(
                                color: appColors.mutedText,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (hasReplies && !isReply) ...<Widget>[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.10,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${comment.replies.length} réponse${comment.replies.length > 1 ? 's' : ''}',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                ],
              ),
            ),
          ],
        ),
        if (hasReplies && !isReply) ...<Widget>[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.18),
                    width: 2,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: comment.replies
                      .map(
                        (reply) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildCommentThread(
                            context,
                            reply,
                            depth: 1,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMentionSuggestions(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;

    if (_activeMentionQuery == null) return const SizedBox.shrink();

    if (_isSearchingMentions) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: appColors.panelBackground,
          borderRadius: BorderRadius.circular(18),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
          border: Border.all(
            color: appColors.heroBorder.withValues(alpha: 0.50),
          ),
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Recherche...',
              style: TextStyle(
                color: appColors.mutedText,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (_mentionSuggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: appColors.panelBackground,
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border.all(
          color: appColors.heroBorder.withValues(alpha: 0.50),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _mentionSuggestions.asMap().entries.map((entry) {
          final index = entry.key;
          final mention = entry.value;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (index > 0)
                Divider(
                  height: 1,
                  color: appColors.heroBorder.withValues(alpha: 0.50),
                ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _selectMention(mention),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: <Widget>[
                        AppCircleNetworkAvatar(
                          radius: 18,
                          imageUrl: mention.avatarUrl,
                          userId: mention.userId,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                mention.displayName,
                                style: TextStyle(
                                  color: appColors.heroForeground,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                mention.trigger,
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.north_west_rounded,
                          size: 14,
                          color: appColors.mutedText,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _buildReplyBanner(ThemeData theme, dynamic appColors) {
    final replyingTo = _replyingTo!;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
        border: Border(
          left: BorderSide(color: theme.colorScheme.primary, width: 3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(
          children: <Widget>[
            AppCircleNetworkAvatar(
              radius: 13,
              imageUrl: replyingTo.avatarUrl,
              userId: replyingTo.authorId,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Réponse à ${replyingTo.authorName}',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    replyingTo.message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: appColors.mutedText,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _resetComposer,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: appColors.heroBorder,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 11,
                  color: appColors.mutedText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.88,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // — Drag handle —
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 16),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: appColors.heroBorder,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            // — Header —
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
              child: Row(
                children: <Widget>[
                  Text(
                    'Commentaires',
                    style: TextStyle(
                      color: appColors.heroForeground,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$_commentCount',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: appColors.heroBorder.withValues(alpha: 0.50),
            ),
            // — Comment list —
            Expanded(
              child: widget.comments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.50),
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Aucun commentaire',
                            style: TextStyle(
                              color: appColors.heroForeground,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Soyez le premier à commenter.',
                            style: TextStyle(
                              color: appColors.mutedText,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                      itemCount: widget.comments.length,
                      separatorBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Divider(
                          height: 1,
                          color: appColors.heroBorder.withValues(alpha: 0.30),
                        ),
                      ),
                      itemBuilder: (context, index) => _buildCommentThread(
                        context,
                        widget.comments[index],
                      ),
                    ),
            ),
            // — Bottom composer zone —
            Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                0,
                18,
                14 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Divider(
                    height: 1,
                    color: appColors.heroBorder.withValues(alpha: 0.50),
                  ),
                  const SizedBox(height: 10),
                  if (_replyingTo != null) _buildReplyBanner(theme, appColors),
                  _buildMentionSuggestions(context),
                  AppMessageComposer(
                    controller: _commentController,
                    onAttachmentTap: _openCommentAttachmentSheet,
                    onSend: _submitComment,
                    primary: theme.colorScheme.primary,
                    panelColor: appColors.inputFill,
                    borderColor: appColors.inputBorder,
                    minLines: 1,
                    maxLines: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveMentionQuery {
  final String query;
  final int start;
  final int end;

  const _ActiveMentionQuery({
    required this.query,
    required this.start,
    required this.end,
  });
}


