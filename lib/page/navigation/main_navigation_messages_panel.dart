import 'dart:async';

import 'package:banay/auth/phoneNumber.dart';
import 'package:banay/component/app_page_skeletons.dart';
import 'package:banay/component/profile_models.dart';
import 'package:banay/component/navigation/navigation_message_components.dart';
import 'package:banay/component/theme_menu_button.dart';
import 'package:banay/component/ui/dinamic_icon_input.dart';
import 'package:banay/component/user_list_page.dart';
import 'package:banay/page/chat_page.dart';
import 'package:banay/page/productDetail.dart';
import 'package:banay/services/app_api_client.dart';
import 'package:banay/services/app_auth_service.dart';
import 'package:banay/services/catalog_api_service.dart';
import 'package:banay/services/chat/chat_participant_profile_update.dart';
import 'package:banay/services/chat_realtime_service.dart';
import 'package:banay/services/conversations_api_service.dart';
import 'package:banay/services/presence_service.dart';
import 'package:banay/services/app_performance.dart';
import 'package:banay/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';

final ValueNotifier<int> mainNavigationUnreadMessageCountNotifier =
    ValueNotifier<int>(0);
final ValueNotifier<bool> mainNavigationChatOpenNotifier = ValueNotifier<bool>(
  false,
);

int get mainNavigationUnreadMessageCount =>
    mainNavigationUnreadMessageCountNotifier.value;

enum _MessagesPanelMenuAction { theme, blockedUsers, logout }

class MainNavigationMessagesPanel extends StatefulWidget {
  static final GlobalKey panelKey = GlobalKey();

  const MainNavigationMessagesPanel({super.key});

  static bool closeEmbeddedConversationIfOpen() {
    final state = panelKey.currentState;
    if (state is! _MainNavigationMessagesPanelState) {
      return false;
    }

    return state._closeEmbeddedConversationIfOpen();
  }

  @override
  State<MainNavigationMessagesPanel> createState() =>
      _MainNavigationMessagesPanelState();
}

class _MainNavigationMessagesPanelState
    extends State<MainNavigationMessagesPanel> {
  static const Duration _conversationsPollInterval = Duration(seconds: 15);
  static const int _warmConversationLimit = 3;
  static const int _warmConversationMessageLimit = 8;
  static const int _maxEmbeddedConversations = 5;

  final AppAuthService _authService = AppAuthService();
  final ConversationsApiService _conversationsApiService =
      ConversationsApiService();
  final CatalogApiService _catalogApiService = CatalogApiService();
  final TextEditingController _searchController = TextEditingController();

  Timer? _conversationsPollTimer;
  StreamSubscription<Map<String, dynamic>>? _realtimeEventsSubscription;
  List<Map<String, dynamic>> _conversations = const [];
  List<Map<String, dynamic>> _cachedGroupedConversations = const [];
  final Map<String, bool> _typingConversationStates = {};
  final Map<String, Widget> _embeddedConversationPages = <String, Widget>{};
  String? _activeEmbeddedConversationKey;
  bool _isRealtimeConnected = false;
  bool _isLoading = true;
  bool _isLoadingConversations = false;
  String? _loadError;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchQueryChanged);
    _bindRealtimeUpdates();
    _startConversationsPolling();
    _loadConversations();
  }

  @override
  void dispose() {
    _realtimeEventsSubscription?.cancel();
    _conversationsPollTimer?.cancel();
    _searchController.removeListener(_handleSearchQueryChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchQueryChanged() {
    final nextQuery = _searchController.text;
    if (_searchQuery == nextQuery) {
      return;
    }

    setState(() => _searchQuery = nextQuery);
  }

  bool _closeEmbeddedConversationIfOpen() {
    if (_activeEmbeddedConversationKey == null) {
      return false;
    }

    if (mounted) {
      setState(() => _activeEmbeddedConversationKey = null);
    } else {
      _activeEmbeddedConversationKey = null;
    }
    mainNavigationChatOpenNotifier.value = false;
    return true;
  }

  void _startConversationsPolling() {
    _conversationsPollTimer?.cancel();
    _conversationsPollTimer = Timer.periodic(
      _conversationsPollInterval,
      (_) => unawaited(_loadConversations(silent: true)),
    );
  }

  void _stopConversationsPolling() {
    _conversationsPollTimer?.cancel();
    _conversationsPollTimer = null;
  }

  void _setRealtimeConnectionState(bool isConnected) {
    if (_isRealtimeConnected == isConnected) {
      return;
    }

    _isRealtimeConnected = isConnected;
    if (isConnected) {
      _stopConversationsPolling();
      unawaited(_loadConversations(silent: true));
      return;
    }

    _startConversationsPolling();
  }

  void _bindRealtimeUpdates() {
    ChatRealtimeService.instance.ensureConnected();
    _realtimeEventsSubscription?.cancel();
    _realtimeEventsSubscription = ChatRealtimeService.instance.events.listen((
      event,
    ) {
      final eventType = event['type']?.toString();
      if (eventType == ChatRealtimeService.connectedEventType) {
        _setRealtimeConnectionState(true);
        return;
      }
      if (eventType == ChatRealtimeService.disconnectedEventType) {
        _setRealtimeConnectionState(false);
        return;
      }

      if (eventType == 'profile:public-updated') {
        _applyPublicProfileUpdate(event);
        return;
      }

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

      if (_applyIncrementalConversationEvent(event)) {
        return;
      }

      unawaited(_loadConversations(silent: true));
    });
  }

  void _updateUnreadCountNotifier([List<Map<String, dynamic>>? conversations]) {
    final source = conversations ?? _conversations;
    mainNavigationUnreadMessageCountNotifier.value = source.fold<int>(
      0,
      (total, conversation) =>
          total + (((conversation['unreadCount'] as num?)?.toInt()) ?? 0),
    );
  }

  bool _applyIncrementalConversationEvent(Map<String, dynamic> event) {
    final eventType = event['type']?.toString();
    final conversationId = event['conversationId']?.toString().trim() ?? '';
    if (conversationId.isEmpty) {
      return false;
    }

    final conversationIndex = _conversations.indexWhere(
      (conversation) => _conversationId(conversation) == conversationId,
    );
    if (conversationIndex < 0) {
      return false;
    }

    switch (eventType) {
      case 'message:new':
        final rawMessage = event['message'];
        if (rawMessage is! Map) {
          return false;
        }

        final currentConversation = _conversations[conversationIndex];
        final nextConversation = Map<String, dynamic>.from(currentConversation);
        final participantId = _participantId(currentConversation)?.trim() ?? '';
        final actorUserId = event['actorUserId']?.toString().trim() ?? '';
        final isIncoming =
            participantId.isNotEmpty && actorUserId == participantId;
        final nextLastMessage = Map<String, dynamic>.from(rawMessage)
          ..['isMine'] = !isIncoming;

        nextConversation['lastMessage'] = nextLastMessage;
        nextConversation['lastMessageAt'] =
            nextLastMessage['createdAt']?.toString() ??
            currentConversation['lastMessageAt'];
        if (isIncoming) {
          final unreadCount = _conversationUnreadCount(currentConversation);
          nextConversation['unreadCount'] = unreadCount + 1;
        }

        _replaceConversationInList(nextConversation);
        return true;
      case 'conversation:read':
        final currentConversation = _conversations[conversationIndex];
        final participantId = _participantId(currentConversation)?.trim() ?? '';
        final actorUserId = event['actorUserId']?.toString().trim() ?? '';
        final nextConversation = Map<String, dynamic>.from(currentConversation);
        if (participantId.isNotEmpty && actorUserId != participantId) {
          nextConversation['unreadCount'] = 0;
        }
        _replaceConversationInList(nextConversation, preserveOrdering: true);
        return true;
      default:
        return false;
    }
  }

  void _replaceConversationInList(
    Map<String, dynamic> nextConversation, {
    bool preserveOrdering = false,
  }) {
    final nextConversationId = _conversationId(nextConversation);
    if (nextConversationId == null) {
      return;
    }

    final nextConversations = _conversations
        .map((conversation) {
          if (_conversationId(conversation) != nextConversationId) {
            return conversation;
          }

          return nextConversation;
        })
        .map((conversation) => Map<String, dynamic>.from(conversation))
        .toList(growable: false);

    if (!preserveOrdering) {
      nextConversations.sort((first, second) {
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
    }

    if (!mounted) {
      _conversations = nextConversations;
      _updateGroupedConversations();
      _updateUnreadCountNotifier(nextConversations);
      return;
    }

    setState(() {
      _conversations = nextConversations;
    });
    _updateGroupedConversations();
    _watchConversationParticipants(nextConversations);
    _updateUnreadCountNotifier(nextConversations);
  }

  void _applyPublicProfileUpdate(Map<String, dynamic> event) {
    final userId = event['userId']?.toString().trim() ?? '';
    final profile = event['profile'];
    if (userId.isEmpty || profile is! Map || !mounted) {
      return;
    }

    final rawSellerProfile = profile['sellerProfile'];
    final sellerProfile = rawSellerProfile is Map
        ? Map<String, dynamic>.from(rawSellerProfile)
        : const <String, dynamic>{};
    final displayName = profile['displayName']?.toString().trim() ?? '';
    final studioName = sellerProfile['studioName']?.toString().trim() ?? '';
    final resolvedName = studioName.isNotEmpty ? studioName : displayName;
    final avatarUrl = profile['avatarUrl']?.toString().trim() ?? '';
    final coverImageUrl = profile['coverImageUrl']?.toString().trim() ?? '';
    final role = profile['role']?.toString().trim();

    var hasChanged = false;
    final updatedConversations = _conversations.map((conversation) {
      final nextConversation = mergeConversationParticipantProfileUpdate(
        conversation,
        userId: userId,
        displayName: resolvedName,
        avatarUrl: avatarUrl,
        coverImageUrl: coverImageUrl,
        role: role,
      );
      if (nextConversation == null) {
        return conversation;
      }
      hasChanged = true;
      return nextConversation;
    }).toList();

    if (!hasChanged) {
      return;
    }

    setState(() {
      _conversations = updatedConversations;
    });
    _updateGroupedConversations();
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
      if (!silent) {
        final cachedConversations = await _conversationsApiService
            .getCachedConversations();
        if (cachedConversations != null &&
            cachedConversations.isNotEmpty &&
            mounted) {
          setState(() {
            _conversations = cachedConversations;
            _isLoading = false;
            _loadError = null;
          });
          _updateGroupedConversations();
          _watchConversationParticipants(cachedConversations);
          _updateUnreadCountNotifier(cachedConversations);
        }
      }

      final conversations = await AppPerformance.traceAsync(
        'fetch_conversations',
        _conversationsApiService.fetchConversations,
      );

      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _isLoading = false;
        _loadError = null;
      });
      _updateGroupedConversations();
      _watchConversationParticipants(conversations);
      _warmRecentConversations(conversations);
      _updateUnreadCountNotifier(conversations);
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
        _updateUnreadCountNotifier(const <Map<String, dynamic>>[]);
      }
    } finally {
      _isLoadingConversations = false;
    }
  }

  bool _conversationIsUnread(Map<String, dynamic> conversation) {
    return ((conversation['unreadCount'] as num?)?.toInt() ?? 0) > 0;
  }

  void _warmRecentConversations(List<Map<String, dynamic>> conversations) {
    final groupedConversations = _groupConversationsByParticipant(
      conversations,
    );
    final conversationIds = groupedConversations
        .map(_conversationId)
        .whereType<String>()
        .take(_warmConversationLimit);

    for (final conversationId in conversationIds) {
      unawaited(
        _conversationsApiService.warmConversationById(
          conversationId,
          limit: _warmConversationMessageLimit,
        ),
      );
    }
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

  void _watchConversationParticipants(
    Iterable<Map<String, dynamic>> conversations,
  ) {
    for (final conversation in conversations) {
      final participantId = _participantId(conversation);
      if (participantId == null) {
        continue;
      }

      PresenceService.instance.watchUser(participantId);
    }
  }

  void _updateGroupedConversations() {
    _cachedGroupedConversations = _groupConversationsByParticipant(
      _conversations,
    );
  }

  bool _conversationParticipantIsOnline(Map<String, dynamic> conversation) {
    final participantId = _participantId(conversation);
    if (participantId != null) {
      final livePresence = PresenceService.instance.presenceOf(participantId);
      if (livePresence != null) {
        return livePresence;
      }
    }

    final participant = conversation['participant'];
    if (participant is! Map) {
      return false;
    }

    return participant['isOnline'] == true;
  }

  DateTime? _conversationParticipantLastSeen(
    Map<String, dynamic> conversation,
  ) {
    final participantId = _participantId(conversation);
    if (participantId != null) {
      final liveLastSeen = PresenceService.instance.lastSeenOf(participantId);
      if (liveLastSeen != null) {
        return liveLastSeen;
      }
    }

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
    final participantId = _participantId(conversation);
    if (participantId != null) {
      final livePresence = PresenceService.instance.presenceOf(participantId);
      if (livePresence == true) {
        return null;
      }
    }

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
          name: name != null && name.isNotEmpty ? name : 'Utilisateur BANAY',
          subtitle: subtitle,
          imageUrl: avatarUrl,
          trailingText: 'Debloquer',
          userId: userId != null && userId.isNotEmpty ? userId : null,
          profileData: buildProfileFromUser(
            userId: userId != null && userId.isNotEmpty ? userId : null,
            name: name != null && name.isNotEmpty ? name : 'Utilisateur BANAY',
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
      case _MessagesPanelMenuAction.logout:
        await _logout();
        return;
    }
  }

  Future<bool> _confirmLogout() async {
    final decision = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Deconnexion'),
        content: const Text(
          'Voulez-vous vraiment vous deconnecter de ce compte ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Deconnecter'),
          ),
        ],
      ),
    );

    return decision ?? false;
  }

  Future<void> _logout() async {
    final shouldLogout = await _confirmLogout();
    if (!shouldLogout || !mounted) {
      return;
    }

    try {
      await _authService.logout();
    } on AppApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
      return;
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PhoneNumberPage()),
      (route) => false,
    );
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
    if (conversationId != null) {
      unawaited(
        _conversationsApiService.warmConversationById(
          conversationId,
          limit: _warmConversationMessageLimit,
        ),
      );
    }

    final conversationKey =
        conversationId ??
        'participant:${_participantId(conversation) ?? _conversationName(conversation)}';

    if (!_embeddedConversationPages.containsKey(conversationKey)) {
      // Evict the oldest non-active entry when the cache is full.
      if (_embeddedConversationPages.length >= _maxEmbeddedConversations) {
        final evictKey = _embeddedConversationPages.keys.firstWhere(
          (key) => key != _activeEmbeddedConversationKey,
          orElse: () => _embeddedConversationPages.keys.first,
        );
        _embeddedConversationPages.remove(evictKey);
      }

      _embeddedConversationPages[conversationKey] = ChatPage(
        key: ValueKey<String>('messages-panel:$conversationKey'),
        conversationId: conversationId,
        onCloseRequested: _closeEmbeddedConversationIfOpen,
        productPageBuilder: (product, {openedFromChat = false}) =>
            ProductDetailPage(product: product, openedFromChat: openedFromChat),
        sellerName: _conversationName(conversation),
        sellerRole:
            ((conversation['participant'] as Map?)?['roleLabel'] as String?) ??
            'Utilisateur',
        avatarUrl: _conversationAvatar(conversation),
      );
    }

    if (!mounted) {
      _activeEmbeddedConversationKey = conversationKey;
      mainNavigationChatOpenNotifier.value = true;
      return;
    }

    setState(() => _activeEmbeddedConversationKey = conversationKey);
    mainNavigationChatOpenNotifier.value = true;
  }

  List<Widget> _buildEmbeddedConversationLayers() {
    return _embeddedConversationPages.entries
        .map((entry) {
          final isVisible = entry.key == _activeEmbeddedConversationKey;
          return Positioned.fill(
            child: Offstage(
              offstage: !isVisible,
              child: IgnorePointer(ignoring: !isVisible, child: entry.value),
            ),
          );
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final primary = theme.colorScheme.primary;
    final scaffoldColor = appColors.backgroundBase;
    final surfaceColor = theme.cardColor;
    final mutedColor = appColors.mutedText;
    final strongTextColor = theme.colorScheme.onSurface;
    final groupedConversations = _cachedGroupedConversations;
    final normalizedQuery = _searchQuery.trim().toLowerCase();
    final filteredConversations = normalizedQuery.isEmpty
        ? groupedConversations
        : groupedConversations.where((conversation) {
            final name = _conversationName(conversation).toLowerCase();
            final preview = _conversationPreview(conversation).toLowerCase();
            return name.contains(normalizedQuery) ||
                preview.contains(normalizedQuery);
          }).toList();

    final listContent = RefreshIndicator(
      onRefresh: _refreshPanel,
      color: primary,
      child: ValueListenableBuilder<int>(
        valueListenable: PresenceService.instance.changes,
        builder: (context, presenceVersion, child) {
          if (_isLoading) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(0, 6, 0, 26),
              children: const [
                MainNavigationMessagesSkeleton(
                  showStories: true,
                  showInvitationCard: true,
                ),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 120),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Messages',
                      style: theme.textTheme.headlineMedium?.copyWith(
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
                      PopupMenuItem(
                        value: _MessagesPanelMenuAction.logout,
                        child: _MessagesPanelMenuItem(
                          icon: Icons.logout_rounded,
                          label: 'Deconnexion',
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
              const SizedBox(height: 18),
              DynamicIconInput(
                controller: _searchController,
                primary: theme.colorScheme.primary,
                panelColor: theme.cardColor,
                borderColor: appColors.inputBorder,
                hintText: 'Rechercher dans les messages...',
                contentPadding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                leadingSize: 24,
                leadingIcon: Icon(
                  Icons.search_rounded,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
                trailingIcon: _searchController.text.trim().isEmpty
                    ? null
                    : Icon(
                        Icons.close_rounded,
                        color: theme.appColors.mutedText,
                        size: 20,
                      ),
                trailingSize: 32,
                onTrailingTap: () {
                  _searchController.clear();
                  if (mounted) {
                    setState(() => _searchQuery = '');
                  }
                },
              ),
              const SizedBox(height: 20),
              if (filteredConversations.isNotEmpty) ...[
                SizedBox(
                  height: 98,
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
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
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
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
              if (_loadError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
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
                      0,
                      index == 0 ? 4 : 2,
                      0,
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
          );
        },
      ),
    );

    return PopScope(
      canPop: _activeEmbeddedConversationKey == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _closeEmbeddedConversationIfOpen();
        }
      },
      child: Scaffold(
        backgroundColor: scaffoldColor,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: Offstage(
                  offstage: _activeEmbeddedConversationKey != null,
                  child: listContent,
                ),
              ),
              ..._buildEmbeddedConversationLayers(),
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
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
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
