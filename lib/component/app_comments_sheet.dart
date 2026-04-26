import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:banay/component/app_attachment_sheet.dart';
import 'package:banay/component/app_message_composer.dart';
import 'package:banay/component/app_network_image.dart';
import 'package:banay/component/profile_models.dart';
import 'package:banay/component/seller_profile_page.dart';
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SellerProfilePage(
          profile: buildProfileFromUser(
            userId: comment.authorId,
            name: comment.authorName,
            avatarUrl: comment.avatarUrl,
            subtitle: 'Membre de la communaute BANAY',
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
    final horizontalInset = effectiveDepth * 18.0;

    return Padding(
      padding: EdgeInsets.only(left: horizontalInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: depth == 0
                  ? appColors.heroSurface
                  : appColors.heroSurface.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: appColors.heroBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
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
                        radius: depth == 0 ? 18 : 16,
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
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _openCommentAuthorProfile(comment),
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    comment.authorName,
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontSize: depth == 0 ? 13.5 : 12.8,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Text(
                            comment.timeLabel,
                            style: TextStyle(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.52,
                              ),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _buildMessageText(context, comment),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: <Widget>[
                          GestureDetector(
                            onTap: () => _startReply(comment),
                            child: Text(
                              'Repondre',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (comment.replies.isNotEmpty)
                            Text(
                              '${comment.replies.length} reponse${comment.replies.length > 1 ? 's' : ''}',
                              style: TextStyle(
                                color: appColors.mutedText,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (comment.replies.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Column(
              children: comment.replies
                  .map(
                    (reply) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildCommentThread(context, reply, depth: 1),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMentionSuggestions(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;

    if (_activeMentionQuery == null) {
      return const SizedBox.shrink();
    }

    if (_isSearchingMentions) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: appColors.heroSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: appColors.heroBorder),
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
              'Recherche des membres...',
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

    if (_mentionSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: appColors.heroSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: appColors.heroBorder),
      ),
      child: Column(
        children: _mentionSuggestions
            .map(
              (mention) => ListTile(
                dense: true,
                leading: AppCircleNetworkAvatar(
                  radius: 17,
                  imageUrl: mention.avatarUrl,
                  userId: mention.userId,
                ),
                title: Text(
                  mention.displayName,
                  style: TextStyle(
                    color: appColors.heroForeground,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  mention.trigger,
                  style: TextStyle(
                    color: appColors.mutedText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => _selectMention(mention),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.8,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            14,
            18,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
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
                '$_commentCount commentaires et reponses',
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
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, index) => _buildCommentThread(
                          context,
                          widget.comments[index],
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              if (_replyingTo != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: appColors.heroSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: appColors.heroBorder),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Reponse a ${_replyingTo!.authorName}',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _replyingTo!.message,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: appColors.mutedText,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _resetComposer,
                        child: const Text('Annuler'),
                      ),
                    ],
                  ),
                ),
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


