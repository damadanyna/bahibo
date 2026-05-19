import 'package:banay/component/app_network_image.dart';
import 'package:banay/services/app_api_client.dart';
import 'package:banay/services/conversations_api_service.dart';
import 'package:flutter/material.dart';
import 'package:banay/theme/app_theme_extensions.dart';

Future<int> showAppShareSheet(
  BuildContext context, {
  required String messageContent,
  Map<String, dynamic>? productSnapshot,
  String title = 'Partager avec',
  String selectionHint = 'Cochez pour partager ce contenu',
  String successLabel = 'Element',
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final theme = Theme.of(context);
  final appColors = theme.appColors;
  final conversationsApiService = ConversationsApiService();
  final normalizedMessageContent = messageContent.trim();

  if (normalizedMessageContent.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Aucun contenu a partager.')),
    );
    return 0;
  }

  String conversationSelectionKey(Map<String, dynamic> conversation) {
    final conversationId = _shareConversationId(conversation);
    if (conversationId != null && conversationId.isNotEmpty) {
      return 'id:$conversationId';
    }

    final participantId = _shareParticipantId(conversation);
    if (participantId != null && participantId.isNotEmpty) {
      return 'user:$participantId';
    }

    return conversation.hashCode.toString();
  }

  final conversationsFuture = _loadShareConversations(conversationsApiService);
  final selectedConversations =
      await showModalBottomSheet<List<Map<String, dynamic>>>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: appColors.overlaySurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (sheetContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: conversationsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const SizedBox(
                      height: 280,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    return SizedBox(
                      height: 280,
                      child: Center(
                        child: Text(
                          'Impossible de charger la liste des discussions.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }

                  final conversations =
                      snapshot.data ?? const <Map<String, dynamic>>[];
                  if (conversations.isEmpty) {
                    return SizedBox(
                      height: 280,
                      child: Center(
                        child: Text(
                          'Aucune discussion disponible.',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }

                  final selectedKeys = <String>{};

                  return StatefulBuilder(
                    builder: (context, setModalState) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: conversations.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final conversation = conversations[index];
                              final selectionKey = conversationSelectionKey(
                                conversation,
                              );
                              final isSelected = selectedKeys.contains(
                                selectionKey,
                              );

                              return CheckboxListTile(
                                value: isSelected,
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.trailing,
                                secondary: AppCircleNetworkAvatar(
                                  radius: 22,
                                  imageUrl: _shareConversationAvatar(
                                    conversation,
                                  ),
                                  userId: _shareParticipantId(conversation),
                                ),
                                title: Text(
                                  _shareConversationName(conversation),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  selectionHint,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onChanged: (_) {
                                  setModalState(() {
                                    if (!selectedKeys.add(selectionKey)) {
                                      selectedKeys.remove(selectionKey);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: selectedKeys.isEmpty
                                ? null
                                : () {
                                    final selected = conversations
                                        .where(
                                          (conversation) =>
                                              selectedKeys.contains(
                                                conversationSelectionKey(
                                                  conversation,
                                                ),
                                              ),
                                        )
                                        .toList(growable: false);
                                    Navigator.of(sheetContext).pop(selected);
                                  },
                            child: Text(
                              selectedKeys.length <= 1
                                  ? 'Partager vers 1 discussion'
                                  : 'Partager vers ${selectedKeys.length} discussions',
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      );

  if (selectedConversations == null || selectedConversations.isEmpty) {
    return 0;
  }

  try {
    for (final conversation in selectedConversations) {
      await _forwardShareToConversation(
        conversationsApiService,
        conversation,
        content: normalizedMessageContent,
        productSnapshot: productSnapshot,
      );
    }
  } on AppApiException catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
    return 0;
  }

  messenger.showSnackBar(
    SnackBar(
      content: Text(
        selectedConversations.length == 1
            ? '$successLabel partage avec ${_shareConversationName(selectedConversations.first)}.'
            : '$successLabel partage avec ${selectedConversations.length} discussions.',
      ),
    ),
  );

  return selectedConversations.length;
}

String? _shareConversationId(Map<String, dynamic> conversation) {
  final value = conversation['id'];
  if (value == null) {
    return null;
  }

  final normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}

String? _shareParticipantId(Map<String, dynamic> conversation) {
  final participant = conversation['participant'];
  if (participant is! Map) {
    return null;
  }

  final value = participant['id'];
  if (value == null) {
    return null;
  }

  final normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}

String _shareConversationName(Map<String, dynamic> conversation) {
  final participant = conversation['participant'];
  if (participant is Map) {
    final value = participant['displayName'];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }

  return 'Conversation';
}

String _shareConversationAvatar(Map<String, dynamic> conversation) {
  final participant = conversation['participant'];
  if (participant is Map) {
    final value = participant['avatarUrl'];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }

  return 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=600';
}

DateTime? _shareConversationLastMessageDate(Map<String, dynamic> conversation) {
  final value = conversation['lastMessageAt'];
  if (value is! String || value.trim().isEmpty) {
    return null;
  }

  return DateTime.tryParse(value)?.toLocal();
}

List<Map<String, dynamic>> _groupShareConversations(
  List<Map<String, dynamic>> conversations,
) {
  final grouped = <String, Map<String, dynamic>>{};

  for (final conversation in conversations) {
    final participantId = _shareParticipantId(conversation);
    final conversationId = _shareConversationId(conversation);
    final groupKey = participantId ?? conversationId;

    if (groupKey == null) {
      continue;
    }

    final existing = grouped[groupKey];
    if (existing == null) {
      grouped[groupKey] = Map<String, dynamic>.from(conversation);
      continue;
    }

    final existingDate = _shareConversationLastMessageDate(existing);
    final currentDate = _shareConversationLastMessageDate(conversation);
    final useCurrentConversation =
        existingDate == null ||
        (currentDate != null && currentDate.isAfter(existingDate));

    grouped[groupKey] = Map<String, dynamic>.from(
      useCurrentConversation ? conversation : existing,
    );
  }

  final groupedList = grouped.values.toList(growable: false);
  groupedList.sort((first, second) {
    final firstDate = _shareConversationLastMessageDate(first);
    final secondDate = _shareConversationLastMessageDate(second);
    if (firstDate == null && secondDate == null) {
      return 0;
    }
    if (firstDate == null) {
      return 1;
    }
    if (secondDate == null) {
      return -1;
    }
    return secondDate.compareTo(firstDate);
  });
  return groupedList;
}

Future<List<Map<String, dynamic>>> _loadShareConversations(
  ConversationsApiService conversationsApiService,
) async {
  final cachedConversations = await conversationsApiService
      .getCachedConversations();
  if (cachedConversations != null && cachedConversations.isNotEmpty) {
    return _groupShareConversations(cachedConversations);
  }

  final conversations = await conversationsApiService.fetchConversations();
  return _groupShareConversations(conversations);
}

Future<void> _forwardShareToConversation(
  ConversationsApiService conversationsApiService,
  Map<String, dynamic> conversation, {
  required String content,
  Map<String, dynamic>? productSnapshot,
}) async {
  final conversationId = _shareConversationId(conversation);
  if (conversationId != null) {
    await conversationsApiService.sendMessage(
      conversationId: conversationId,
      content: content,
      productSnapshot: productSnapshot,
    );
    return;
  }

  final participantId = _shareParticipantId(conversation);
  if (participantId != null) {
    await conversationsApiService.sendUserMessage(
      targetUserId: participantId,
      content: content,
      productSnapshot: productSnapshot,
    );
    return;
  }

  throw AppApiException('Conversation introuvable pour ce partage.');
}
