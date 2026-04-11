import 'dart:async';

import 'package:bahibo/component/navigation/navigation_message_components.dart';
import 'package:bahibo/page/chat_page.dart';
import 'package:bahibo/services/app_api_client.dart';
import 'package:bahibo/services/chat_realtime_service.dart';
import 'package:bahibo/services/conversations_api_service.dart';
import 'package:bahibo/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';

final ValueNotifier<int> mainNavigationUnreadMessageCountNotifier =
    ValueNotifier<int>(0);

int get mainNavigationUnreadMessageCount =>
    mainNavigationUnreadMessageCountNotifier.value;

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
  static const double _searchBarHeight = 58;
  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _searchAnchorKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  Timer? _conversationsPollTimer;
  StreamSubscription<Map<String, dynamic>>? _realtimeEventsSubscription;
  List<Map<String, dynamic>> _conversations = const [];
  final Map<String, bool> _typingConversationStates = {};
  bool _isLoading = true;
  bool _isLoadingConversations = false;
  bool _searchAnchorCaptureScheduled = false;
  String? _loadError;
  String _searchQuery = '';
  double? _searchAnchorTop;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _bindRealtimeUpdates();
    _startConversationsPolling();
    _loadConversations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureSearchAnchorTop();
    });
  }

  @override
  void dispose() {
    _realtimeEventsSubscription?.cancel();
    _conversationsPollTimer?.cancel();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
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

  void _handleScroll() {
    if (!mounted) return;
    _scheduleSearchAnchorCapture();
    setState(() {});
  }

  void _scheduleSearchAnchorCapture() {
    if (_searchAnchorCaptureScheduled) {
      return;
    }

    _searchAnchorCaptureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchAnchorCaptureScheduled = false;
      if (!mounted) {
        return;
      }
      _captureSearchAnchorTop();
    });
  }

  void _captureSearchAnchorTop() {
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final anchorBox =
        _searchAnchorKey.currentContext?.findRenderObject() as RenderBox?;

    if (stackBox == null || anchorBox == null) {
      return;
    }

    final top = anchorBox.localToGlobal(Offset.zero, ancestor: stackBox).dy;
    if (_searchAnchorTop == null || (_searchAnchorTop! - top).abs() > 0.5) {
      setState(() => _searchAnchorTop = top);
    }
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
    final participantId = _participantId(conversation);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          conversationId: participantId == null
              ? conversation['id']?.toString()
              : null,
          conversationUserId: participantId,
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
    final isDark = theme.brightness == Brightness.dark;
    final appColors = theme.appColors;
    final primary = theme.colorScheme.primary;
    final heroColor = appColors.panelMuted;
    final searchFillColor = appColors.panelBackground;
    final titleColor = theme.colorScheme.onSurface;
    final mutedColor = appColors.mutedText;
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
    final currentScrollOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    final rawSearchTop = _searchAnchorTop == null
        ? null
        : _searchAnchorTop! - currentScrollOffset;
    final isSearchPinned = rawSearchTop != null && rawSearchTop <= 0;
    final floatingSearchTop = rawSearchTop?.clamp(0.0, double.infinity);

    return Scaffold(
      backgroundColor: appColors.backgroundBase,
      body: SafeArea(
        child: Stack(
          key: _stackKey,
          children: [
            ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(18, 20, 18, 0),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primary.withValues(alpha: isDark ? 0.2 : 0.14),
                        heroColor,
                        heroColor,
                      ],
                    ),
                    border: Border.all(
                      color: isDark
                          ? appColors.overlayBorder
                          : primary.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Messages',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        key: _searchAnchorKey,
                        height: _searchBarHeight,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 120),
                          opacity: isSearchPinned ? 0 : 1,
                          child: IgnorePointer(
                            ignoring: isSearchPinned,
                            child: NavigationMessageSearchBar(
                              controller: _searchController,
                              fillColor: searchFillColor,
                              iconColor: mutedColor,
                              hintColor: mutedColor,
                              onChanged: (value) {
                                setState(() => _searchQuery = value);
                              },
                              borderColor: appColors.inputBorder,
                            ),
                          ),
                        ),
                      ),
                      if (filteredConversations.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 92,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: filteredConversations.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 16),
                            itemBuilder: (context, index) {
                              final conversation = filteredConversations[index];
                              return NavigationMessageStoryAvatar(
                                name: _conversationName(
                                  conversation,
                                ).split(' ').first,
                                avatarUrl: _conversationAvatar(conversation),
                                userId: _participantId(conversation),
                                isActive: _conversationIsUnread(conversation),
                                primary: primary,
                                labelColor: titleColor,
                                haloColor: heroColor,
                                onTap: () => _openConversation(conversation),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (_isLoading)
                  _buildInfoCard(
                    context,
                    text: 'Chargement des conversations...',
                    color: mutedColor,
                  )
                else if (_loadError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: appColors.inputBorder),
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
                        18,
                        index == 0 ? 0 : 12,
                        18,
                        index == filteredConversations.length - 1 ? 0 : 12,
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
                        primary: primary,
                        isDark: isDark,
                        onTap: () => _openConversation(conversation),
                      ),
                    );
                  }),
              ],
            ),
            if (isSearchPinned && floatingSearchTop != null)
              Positioned(
                top: floatingSearchTop,
                left: 18,
                right: 18,
                child: NavigationMessageSearchBar(
                  controller: _searchController,
                  fillColor: searchFillColor,
                  iconColor: mutedColor,
                  hintColor: mutedColor,
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                  borderColor: appColors.inputBorder,
                ),
              ),
          ],
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
    final appColors = theme.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: appColors.inputBorder),
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
