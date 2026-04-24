import 'dart:async';

import 'package:bahibo/component/profile_models.dart';
import 'package:bahibo/component/navigation/navigation_message_components.dart';
import 'package:bahibo/component/theme_menu_button.dart';
import 'package:bahibo/component/user_list_page.dart';
import 'package:bahibo/page/chat_page.dart';
import 'package:bahibo/page/productDetail.dart';
import 'package:bahibo/services/app_api_client.dart';
import 'package:bahibo/services/catalog_api_service.dart';
import 'package:bahibo/services/chat_realtime_service.dart';
import 'package:bahibo/services/conversations_api_service.dart';
import 'package:bahibo/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';

final ValueNotifier<int> mainNavigationUnreadMessageCountNotifier =
    ValueNotifier<int>(0);

int get mainNavigationUnreadMessageCount =>
    mainNavigationUnreadMessageCountNotifier.value;

enum _MessagesPanelMenuAction { theme, blockedUsers }

class MainNavigationMessagesPanel extends StatefulWidget {
  const MainNavigationMessagesPanel({super.key});

  @override
  State<MainNavigationMessagesPanel> createState() =>
      _MainNavigationMessagesPanelState();
}

class _MainNavigationMessagesPanelState
    extends State<MainNavigationMessagesPanel> {
  static const Duration _conversationsPollInterval = Duration(seconds: 5);

  final ConversationsApiService _conversationsApiService =
      ConversationsApiService();
  final CatalogApiService _catalogApiService = CatalogApiService();
  final TextEditingController _searchController = TextEditingController();

  Timer? _conversationsPollTimer;
  StreamSubscription<Map<String, dynamic>>? _realtimeEventsSubscription;
  List<Map<String, dynamic>> _conversations = const [];
  final Map<String, bool> _typingConversationStates = {};
  bool _isLoading = true;
  bool _isLoadingConversations = false;
  String? _loadError;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _bindRealtimeUpdates();
    _startConversationsPolling();
    _loadConversations();
  }

  @override
  void dispose() {
    _realtimeEventsSubscription?.cancel();
    _conversationsPollTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _startConversationsPolling() {
    _conversationsPollTimer?.cancel();
    _conversationsPollTimer = Timer.periodic(
      _conversationsPollInterval,
      (_) => unawaited(_loadConversations(silent: true)),
    );
  }

  void _bindRealtimeUpdates() {
    ChatRealtimeService.instance.ensureConnected();
    _realtimeEventsSubscription?.cancel();
    _realtimeEventsSubscription = ChatRealtimeService.instance.events.listen((
      event,
    ) {
      final eventType = event['type']?.toString();
      final conversationId = event['conversationId']?.toString();

      if (eventType == 'typing:update' && conversationId != null) {
        final isTyping = event['isTyping'] == true;
        if (mounted) {
          setState(() {
            if (isTyping) {
              _typingConversationStates[conversationId] = true;
            } else {
              _typingConversationStates.remove(conversationId);
            }
          });
        }
        return;
      }

      if (conversationId != null) {
        _typingConversationStates.remove(conversationId);
      }

      unawaited(_loadConversations(silent: true));
    });
  }

  String? _conversationId(Map<String, dynamic> conversation) {
    final value = conversation['id'];
    if (value == null) {
      return null;
    }

    final normalized = value.toString().trim();
    if (normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  String? _participantId(Map<String, dynamic> conversation) {
    final participant = conversation['participant'];
    if (participant is! Map) {
      return null;
    }

    final value = participant['id'];
    if (value == null) {
      return null;
    }

    final normalized = value.toString().trim();
    if (normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  DateTime? _conversationLastMessageDate(Map<String, dynamic> conversation) {
    final value = conversation['lastMessageAt'];
    if (value is! String || value.trim().isEmpty) {
      return null;
    }

    return DateTime.tryParse(value)?.toLocal();
  }

  List<Map<String, dynamic>> _groupConversationsByParticipant(
    List<Map<String, dynamic>> conversations,
  ) {
    final grouped = <String, Map<String, dynamic>>{};

    for (final conversation in conversations) {
      final participantId = _participantId(conversation);
      final conversationId = _conversationId(conversation);
      final groupKey = participantId ?? conversationId;

      if (groupKey == null) {
        continue;
      }

      final existing = grouped[groupKey];
      if (existing == null) {
        grouped[groupKey] = Map<String, dynamic>.from(conversation);
        continue;
      }

      final existingUnread = ((existing['unreadCount'] as num?)?.toInt()) ?? 0;
      final currentUnread =
          ((conversation['unreadCount'] as num?)?.toInt()) ?? 0;
      final existingDate = _conversationLastMessageDate(existing);
      final currentDate = _conversationLastMessageDate(conversation);
      final useCurrentConversation =
          existingDate == null ||
          (currentDate != null && currentDate.isAfter(existingDate));

      final merged = Map<String, dynamic>.from(
        useCurrentConversation ? conversation : existing,
      );
      merged['unreadCount'] = existingUnread + currentUnread;
      grouped[groupKey] = merged;
    }

    final groupedList = grouped.values.toList();
    groupedList.sort((first, second) {
      final secondDate = _conversationLastMessageDate(second);
      final firstDate = _conversationLastMessageDate(first);
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

  bool _conversationIsTyping(Map<String, dynamic> conversation) {
    final conversationId = _conversationId(conversation);
    if (conversationId == null) {
      return false;
    }

    return _typingConversationStates[conversationId] == true;
  }

  Future<void> _loadConversations({bool silent = false}) async {
    if (_isLoadingConversations) {
      return;
    }

    _isLoadingConversations = true;

    if (mounted && !silent) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final conversations = await _conversationsApiService.fetchConversations();
      final unreadCount = conversations.fold<int>(
        0,
        (total, conversation) =>
            total + (((conversation['unreadCount'] as num?)?.toInt()) ?? 0),
      );

      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _isLoading = false;
        _loadError = null;
      });
      mainNavigationUnreadMessageCountNotifier.value = unreadCount;
    } on AppApiException catch (error) {
      if (!mounted) return;
      setState(() {
        if (!silent) {
          _conversations = const [];
        }
        _isLoading = false;
        _loadError = silent ? _loadError : error.message;
      });
      if (!silent) {
        mainNavigationUnreadMessageCountNotifier.value = 0;
      }
    } finally {
      _isLoadingConversations = false;
    }
  }

  bool _conversationIsUnread(Map<String, dynamic> conversation) {
    return ((conversation['unreadCount'] as num?)?.toInt() ?? 0) > 0;
  }

  String _conversationName(Map<String, dynamic> conversation) {
    final participant = conversation['participant'];
    if (participant is Map) {
      final value = participant['displayName'];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return 'Conversation';
  }

  String _conversationAvatar(Map<String, dynamic> conversation) {
    final participant = conversation['participant'];
    if (participant is Map) {
      final value = participant['avatarUrl'];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=600';
  }

  bool _conversationParticipantIsOnline(Map<String, dynamic> conversation) {
    final participant = conversation['participant'];
    if (participant is! Map) {
      return false;
    }

    return participant['isOnline'] == true;
  }

  DateTime? _conversationParticipantLastSeen(
    Map<String, dynamic> conversation,
  ) {
    final participant = conversation['participant'];
    if (participant is! Map) {
      return null;
    }

    final value = participant['lastSeenAt'];
    if (value is! String || value.trim().isEmpty) {
      return null;
    }

    return DateTime.tryParse(value)?.toLocal();
  }

  String? _conversationStatusLabel(Map<String, dynamic> conversation) {
    if (_conversationParticipantIsOnline(conversation)) {
      return null;
    }

    final lastSeenAt = _conversationParticipantLastSeen(conversation);
    if (lastSeenAt == null) {
      return null;
    }

    final difference = DateTime.now().difference(lastSeenAt);
    if (difference.inSeconds < 45) {
      return 'En ligne il y a quelques secondes';
    }
    if (difference.inMinutes < 60) {
      return 'En ligne il y a ${difference.inMinutes} min';
    }
    if (difference.inHours < 24) {
      return 'En ligne il y a ${difference.inHours} h';
    }
    if (difference.inDays < 7) {
      return 'En ligne il y a ${difference.inDays} j';
    }
    final weeks = (difference.inDays / 7).floor();
    if (weeks < 5) {
      return 'En ligne il y a $weeks sem';
    }
    final months = (difference.inDays / 30).floor();
    if (months < 12) {
      return 'En ligne il y a $months mois';
    }
    final years = (difference.inDays / 365).floor();
    return 'En ligne il y a $years an${years > 1 ? 's' : ''}';
  }

  String _conversationPreview(Map<String, dynamic> conversation) {
    final lastMessage = conversation['lastMessage'];
    if (lastMessage is Map) {
      final value = lastMessage['content'];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    final product = conversation['product'];
    if (product is Map) {
      final title = product['title'];
      if (title is String && title.trim().isNotEmpty) {
        return 'Discussion sur ${title.trim()}';
      }
    }

    return 'Nouvelle conversation';
  }

  int _conversationUnreadCount(Map<String, dynamic> conversation) {
    return ((conversation['unreadCount'] as num?)?.toInt()) ?? 0;
  }

  bool _conversationIsMuted(Map<String, dynamic> conversation) {
    return conversation['muted'] == true ||
        conversation['isMuted'] == true ||
        conversation['notificationsMuted'] == true;
  }

  bool _conversationShowsReplyChip(Map<String, dynamic> conversation) {
    final preview = _conversationPreview(conversation).toLowerCase();
    return preview.contains('d\'accord') ||
        preview.contains('ok') ||
        preview.contains('reponse') ||
        preview.contains('réponse');
  }

  int get _invitationBadgeCount {
    final unreadConversations = _conversations
        .where(_conversationIsUnread)
        .length;
    if (unreadConversations <= 0) {
      return 0;
    }
    return unreadConversations > 9 ? 9 : unreadConversations;
  }

  Future<void> _refreshPanel() async {
    await _loadConversations();
  }

  void _handleBackPressed() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).maybePop();
    }
  }

  Future<bool> _unblockUserFromList(String userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final appColors = theme.appColors;

        return AlertDialog(
          backgroundColor: appColors.panelBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Debloquer $userName',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Voulez-vous vraiment debloquer cette Personne ?',
            style: TextStyle(
              color: appColors.mutedText,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Annuler',
                style: TextStyle(color: appColors.mutedText),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Debloquer',
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return false;
    }

    try {
      await _catalogApiService.unblockUser(userId);
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Utilisateur debloque.')));
      await _loadConversations(silent: true);
      return true;
    } on AppApiException catch (error) {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return false;
    }
  }

  Future<void> _openBlockedUsers() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          const Center(child: CircularProgressIndicator()),
    );

    try {
      final blocks = await _catalogApiService.fetchCurrentUserBlockedUsers();
      if (!mounted) {
        return;
      }

      final blockedUsers = blocks.map((block) {
        final blocked = Map<String, dynamic>.from(
          (block['blocked'] as Map?) ?? const <String, dynamic>{},
        );
        final name = blocked['displayName']?.toString().trim();
        final avatarUrl = blocked['avatarUrl']?.toString().trim() ?? '';
        final userId = blocked['id']?.toString().trim();
        final subtitle = 'Utilisateur bloque dans vos conversations.';

        return UserListItemData(
          name: name != null && name.isNotEmpty ? name : 'Utilisateur Bahibo',
          subtitle: subtitle,
          imageUrl: avatarUrl,
          trailingText: 'Debloquer',
          userId: userId != null && userId.isNotEmpty ? userId : null,
          profileData: buildProfileFromUser(
            userId: userId != null && userId.isNotEmpty ? userId : null,
            name: name != null && name.isNotEmpty ? name : 'Utilisateur Bahibo',
            avatarUrl: avatarUrl,
            subtitle: subtitle,
          ),
          onTrailingTap: userId == null || userId.isEmpty
              ? null
              : () => _unblockUserFromList(
                  userId,
                  name != null && name.isNotEmpty ? name : 'cet utilisateur',
                ),
        );
      }).toList();

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserListPage(
            title: 'Personnes bloquees',
            users: blockedUsers,
            totalCount: blockedUsers.length,
          ),
        ),
      );
    } on AppApiException catch (error) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _handleMenuSelection(_MessagesPanelMenuAction action) async {
    switch (action) {
      case _MessagesPanelMenuAction.theme:
        await showThemeSelectionSheet(context);
        return;
      case _MessagesPanelMenuAction.blockedUsers:
        await _openBlockedUsers();
        return;
    }
  }

  String _conversationTime(Map<String, dynamic> conversation) {
    final value = conversation['lastMessageAt'];
    if (value is! String || value.isEmpty) {
      return '';
    }

    final dateTime = DateTime.tryParse(value)?.toLocal();
    if (dateTime == null) {
      return '';
    }

    final now = DateTime.now();
    final isToday =
        now.year == dateTime.year &&
        now.month == dateTime.month &&
        now.day == dateTime.day;
    if (isToday) {
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday =
        yesterday.year == dateTime.year &&
        yesterday.month == dateTime.month &&
        yesterday.day == dateTime.day;
    if (isYesterday) {
      return 'Hier';
    }

    const weekdayLabels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    final difference = now.difference(dateTime).inDays;
    if (difference < 7) {
      return weekdayLabels[dateTime.weekday - 1];
    }

    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  void _openConversation(Map<String, dynamic> conversation) {
    final conversationId = _conversationId(conversation);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          conversationId: conversationId,
          productPageBuilder: (product, {openedFromChat = false}) =>
              ProductDetailPage(
                product: product,
                openedFromChat: openedFromChat,
              ),
          sellerName: _conversationName(conversation),
          sellerRole:
              ((conversation['participant'] as Map?)?['roleLabel']
                  as String?) ??
              'Utilisateur',
          avatarUrl: _conversationAvatar(conversation),
        ),
      ),
    ).then((_) => _loadConversations());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final primary = theme.colorScheme.primary;
    final scaffoldColor = appColors.backgroundBase;
    final surfaceColor = theme.cardColor;
    final titleColor = theme.colorScheme.onSurface;
    final mutedColor = appColors.mutedText;
    final strongTextColor = theme.colorScheme.onSurface;
    final groupedConversations = _groupConversationsByParticipant(
      _conversations,
    );
    final normalizedQuery = _searchQuery.trim().toLowerCase();
    final filteredConversations = normalizedQuery.isEmpty
        ? groupedConversations
        : groupedConversations.where((conversation) {
            final name = _conversationName(conversation).toLowerCase();
            final preview = _conversationPreview(conversation).toLowerCase();
            return name.contains(normalizedQuery) ||
                preview.contains(normalizedQuery);
          }).toList();

    return Scaffold(
      backgroundColor: scaffoldColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshPanel,
          color: primary,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 6, 0, 26),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Row(
                  children: [
                    NavigationIconActionButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      backgroundColor: surfaceColor,
                      iconColor: theme.colorScheme.onSurface,
                      onTap: _handleBackPressed,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Messages',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    PopupMenuButton<_MessagesPanelMenuAction>(
                      onSelected: (action) => _handleMenuSelection(action),
                      tooltip: 'Plus',
                      padding: EdgeInsets.zero,
                      color: surfaceColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _MessagesPanelMenuAction.theme,
                          child: _MessagesPanelMenuItem(
                            icon: Icons.palette_outlined,
                            label: 'Theme',
                          ),
                        ),
                        PopupMenuItem(
                          value: _MessagesPanelMenuAction.blockedUsers,
                          child: _MessagesPanelMenuItem(
                            icon: Icons.block_rounded,
                            label: 'Personnes bloquees',
                          ),
                        ),
                      ],
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: Icon(
                          Icons.more_vert_rounded,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: NavigationMessageSearchBar(
                  controller: _searchController,
                  fillColor: surfaceColor,
                  iconColor: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                  hintColor: appColors.mutedText,
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                  borderColor: appColors.borderColor.withValues(alpha: 0.2),
                ),
              ),
              if (filteredConversations.isNotEmpty) ...[
                const SizedBox(height: 14),
                SizedBox(
                  height: 98,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    scrollDirection: Axis.horizontal,
                    itemCount: filteredConversations.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      final conversation = filteredConversations[index];
                      return NavigationMessageStoryAvatar(
                        name: _conversationName(conversation).split(' ').first,
                        avatarUrl: _conversationAvatar(conversation),
                        userId: _participantId(conversation),
                        isActive: _conversationIsUnread(conversation),
                        isOnline: _conversationParticipantIsOnline(
                          conversation,
                        ),
                        primary: primary,
                        labelColor: strongTextColor,
                        haloColor: theme.colorScheme.onSurface,
                        onTap: () => _openConversation(conversation),
                      );
                    },
                  ),
                ),
              ],
              if (_invitationBadgeCount > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {},
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            constraints: const BoxConstraints(minWidth: 24),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _invitationBadgeCount > 9
                                  ? '9+'
                                  : '$_invitationBadgeCount',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Nouvelles invitations par message',
                              style: TextStyle(
                                color: strongTextColor.withValues(alpha: 0.92),
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_isLoading)
                _buildInfoCard(
                  context,
                  text: 'Chargement des conversations...',
                  color: mutedColor,
                )
              else if (_loadError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _loadError!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _loadConversations,
                          child: const Text('Reessayer'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (filteredConversations.isEmpty)
                _buildInfoCard(
                  context,
                  text: normalizedQuery.isEmpty
                      ? 'Aucune conversation pour le moment.'
                      : 'Aucun message ne correspond a votre recherche.',
                  color: mutedColor,
                )
              else
                ...List.generate(filteredConversations.length, (index) {
                  final conversation = filteredConversations[index];
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      14,
                      index == 0 ? 4 : 2,
                      14,
                      index == filteredConversations.length - 1 ? 0 : 2,
                    ),
                    child: NavigationConversationTile(
                      name: _conversationName(conversation),
                      preview: _conversationPreview(conversation),
                      statusLabel: _conversationStatusLabel(conversation),
                      time: _conversationTime(conversation),
                      avatarUrl: _conversationAvatar(conversation),
                      userId: _participantId(conversation),
                      isTyping: _conversationIsTyping(conversation),
                      unread: _conversationIsUnread(conversation),
                      unreadCount: _conversationUnreadCount(conversation),
                      isOnline: _conversationParticipantIsOnline(conversation),
                      isMuted: _conversationIsMuted(conversation),
                      showReplyChip: _conversationShowsReplyChip(conversation),
                      primary: primary,
                      isDark: theme.brightness == Brightness.dark,
                      onTap: () => _openConversation(conversation),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String text,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _MessagesPanelMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MessagesPanelMenuItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
      ],
    );
  }
}
