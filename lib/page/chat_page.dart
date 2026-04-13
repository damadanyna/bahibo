import 'dart:async';

import 'package:bahibo/component/app_back_button.dart';
import 'package:bahibo/component/app_network_image.dart';
import 'package:bahibo/component/app_page_refresh.dart';
import 'package:bahibo/component/app_page_skeletons.dart';
import 'package:bahibo/component/ui/chat_message_input.dart';
import 'package:bahibo/formatter/price_formatter.dart';
import 'package:bahibo/services/app_api_client.dart';
import 'package:bahibo/services/catalog_api_service.dart';
import 'package:bahibo/services/chat_realtime_service.dart';
import 'package:bahibo/services/conversations_api_service.dart';
import 'package:bahibo/services/presence_service.dart';
import 'package:bahibo/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';

typedef ChatProductPageBuilder =
    Widget Function(Map<String, dynamic> product, {bool openedFromChat});

class ChatPage extends StatefulWidget {
  final String? conversationId;
  final String? conversationProductId;
  final String? conversationUserId;
  final String sellerName;
  final String sellerRole;
  final String avatarUrl;
  final Map<String, dynamic>? product;
  final ChatProductPageBuilder? productPageBuilder;
  final String productTitle;
  final String productDescription;
  final String productSubtitle;
  final String productPriceLabel;
  final String productImageUrl;
  final String? initialMessage;
  final bool embedProductContextInInitialMessage;
  final bool showProductContextCard;
  final bool showInlineProductSnapshots;

  const ChatPage({
    super.key,
    this.conversationId,
    this.conversationProductId,
    this.conversationUserId,
    this.sellerName = 'Conversation',
    this.sellerRole = 'Utilisateur',
    this.avatarUrl =
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200',
    this.product,
    this.productPageBuilder,
    this.productTitle = '',
    this.productDescription = 'Aucune description disponible.',
    this.productSubtitle = '',
    this.productPriceLabel = '',
    this.productImageUrl = '',
    this.initialMessage,
    this.embedProductContextInInitialMessage = false,
    this.showProductContextCard = false,
    this.showInlineProductSnapshots = true,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage>
    with AppPageRefreshMixin<ChatPage> {
  static const Duration _conversationPollInterval = Duration(seconds: 3);
  static const Duration _typingStopDelay = Duration(milliseconds: 1200);
  final ConversationsApiService _conversationsApiService =
      ConversationsApiService();
  final CatalogApiService _catalogApiService = CatalogApiService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  StreamSubscription<Map<String, dynamic>>? _realtimeEventsSubscription;
  Timer? _conversationPollTimer;
  Timer? _typingStopTimer;
  static const int _scrollRetryCount = 4;
  bool _showEntrySkeleton = true;
  bool _isSending = false;
  bool _isParticipantTyping = false;
  bool _isTypingEventActive = false;
  bool _initialMessageHandled = false;
  bool _initialProductContextSent = false;
  String? _conversationId;
  String? _loadError;
  Map<String, dynamic>? _conversation;

  @override
  void initState() {
    super.initState();
    initializePageRefresh();
    _conversationId = widget.conversationId;

    if (_usesLiveConversation) {
      _bindRealtimeUpdates();
      _startConversationPolling();
      _loadConversation();
      return;
    }

    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      setState(() => _showEntrySkeleton = false);
    });
  }

  @override
  void dispose() {
    _realtimeEventsSubscription?.cancel();
    _conversationPollTimer?.cancel();
    _typingStopTimer?.cancel();
    _emitTyping(false);
    disposePageRefresh();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Future<void> onPageReload() async {
    if (_usesLiveConversation) {
      await _loadConversation();
      return;
    }

    if (!mounted) return;
    setState(() => _showEntrySkeleton = false);
  }

  bool get _usesLiveConversation =>
      (widget.conversationId?.isNotEmpty ?? false) ||
      (widget.conversationProductId?.isNotEmpty ?? false) ||
      (widget.conversationUserId?.isNotEmpty ?? false);

  String get _sellerNameValue {
    final participant = _conversation?['participant'];
    if (participant is Map) {
      final value = participant['displayName'];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return widget.sellerName;
  }

  String get _sellerRoleValue {
    final participant = _conversation?['participant'];
    if (participant is Map) {
      final value = participant['roleLabel'];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return widget.sellerRole;
  }

  String get _avatarUrlValue {
    final participant = _conversation?['participant'];
    if (participant is Map) {
      final value = participant['avatarUrl'];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return widget.avatarUrl;
  }

  bool get _participantIsOnlineValue {
    final participant = _conversation?['participant'];
    if (participant is Map) {
      return participant['isOnline'] == true;
    }
    return false;
  }

  String get _participantStatusValue {
    if (_participantIsOnlineValue) {
      return 'En ligne';
    }

    final participant = _conversation?['participant'];
    if (participant is Map) {
      final lastSeenAt = participant['lastSeenAt'] as String?;
      final lastSeenDate = lastSeenAt == null
          ? null
          : DateTime.tryParse(lastSeenAt)?.toLocal();
      if (lastSeenDate != null) {
        final difference = DateTime.now().difference(lastSeenDate);
        if (difference.inMinutes < 1) {
          return 'Vu a l\'instant';
        }
        if (difference.inMinutes < 60) {
          return 'Vu il y a ${difference.inMinutes} min';
        }
        if (difference.inHours < 24) {
          return 'Vu il y a ${difference.inHours} h';
        }
      }
    }

    return _sellerRoleValue;
  }

  String? get _participantUserId {
    final participant = _conversation?['participant'];
    if (participant is Map) {
      final value = participant['id'];
      if (value != null) {
        final normalized = value.toString().trim();
        if (normalized.isNotEmpty) {
          return normalized;
        }
      }
    }
    return null;
  }

  Map<String, dynamic>? get _productValue {
    final product = _conversation?['product'];
    if (product is Map) {
      return Map<String, dynamic>.from(product);
    }
    return widget.product;
  }

  String get _productTitleValue {
    final value = _productValue?['title'];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return widget.productTitle;
  }

  String get _productSubtitleValue {
    final value = _productValue?['subtitle'];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return widget.productSubtitle;
  }

  String get _productImageUrlValue {
    final value = _productValue?['imageUrl'];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return widget.productImageUrl;
  }

  String get _productPriceLabelValue {
    final price = _productValue?['price'];
    final currency = _productValue?['currency'];
    if (price is num && currency is String && currency.trim().isNotEmpty) {
      return '${formatPriceAmount(price.toDouble())} ${currency.trim()}';
    }
    return widget.productPriceLabel;
  }

  void _startConversationPolling() {
    _conversationPollTimer?.cancel();
    _conversationPollTimer = Timer.periodic(
      _conversationPollInterval,
      (_) => _refreshConversationSilently(),
    );
  }

  void _bindRealtimeUpdates() {
    ChatRealtimeService.instance.ensureConnected();
    _realtimeEventsSubscription?.cancel();
    _realtimeEventsSubscription = ChatRealtimeService.instance.events.listen((
      event,
    ) {
      final eventConversationId = event['conversationId']?.toString();
      final currentConversationId = _conversationId;
      if (eventConversationId == null || currentConversationId == null) {
        return;
      }

      if (eventConversationId != currentConversationId) {
        return;
      }

      if (event['type'] == 'typing:update') {
        final actorUserId = event['actorUserId']?.toString();
        if (actorUserId != null && actorUserId == _participantUserId) {
          final isTyping = event['isTyping'] == true;
          if (mounted) {
            setState(() => _isParticipantTyping = isTyping);
          } else {
            _isParticipantTyping = isTyping;
          }
        }
        return;
      }

      unawaited(_refreshConversationSilently());
    });
  }

  void _handleComposerChanged(String text) {
    if (_conversationId == null || _participantUserId == null) {
      return;
    }

    final hasContent = text.trim().isNotEmpty;
    if (hasContent) {
      if (!_isTypingEventActive) {
        _emitTyping(true);
      }
      _typingStopTimer?.cancel();
      _typingStopTimer = Timer(_typingStopDelay, () {
        _emitTyping(false);
      });
      return;
    }

    _typingStopTimer?.cancel();
    _emitTyping(false);
  }

  void _emitTyping(bool isTyping) {
    final conversationId = _conversationId;
    final participantUserId = _participantUserId;
    if (conversationId == null || participantUserId == null) {
      return;
    }

    if (_isTypingEventActive == isTyping) {
      return;
    }

    _isTypingEventActive = isTyping;
    ChatRealtimeService.instance.emitTyping(
      conversationId: conversationId,
      recipientUserId: participantUserId,
      isTyping: isTyping,
    );
  }

  Future<Map<String, dynamic>> _fetchConversationData() {
    if (widget.conversationUserId?.isNotEmpty ?? false) {
      return _conversationsApiService.fetchConversationForUser(
        widget.conversationUserId!,
      );
    }
    if (_conversationId != null) {
      return _conversationsApiService.fetchConversationById(_conversationId!);
    }
    if (widget.conversationProductId?.isNotEmpty ?? false) {
      return _conversationsApiService.fetchConversationForProduct(
        widget.conversationProductId!,
      );
    }
    return _conversationsApiService.fetchConversationById(_conversationId!);
  }

  Future<void> _refreshConversationSilently() async {
    if (!mounted || !_usesLiveConversation || _isSending) {
      return;
    }

    try {
      final previousLastMessageId = _messages.isEmpty
          ? null
          : _messages.last.id;
      final previousMessageCount = _messages.length;
      final data = await _fetchConversationData();
      if (!mounted) return;
      _applyConversation(data);
      final hasNewMessage =
          _messages.length != previousMessageCount ||
          (_messages.isNotEmpty && _messages.last.id != previousLastMessageId);
      if (hasNewMessage) {
        setState(() {
          _loadError = null;
          _showEntrySkeleton = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _animateToBottom());
      } else {
        setState(() {
          _loadError = null;
          _showEntrySkeleton = false;
        });
      }
    } on AppApiException {
      if (!mounted) return;
    }
  }

  Future<void> _loadConversation() async {
    if (mounted) {
      setState(() {
        _showEntrySkeleton = true;
        _loadError = null;
      });
    }

    try {
      final data = await _fetchConversationData();
      _applyConversation(data);

      if (!_initialMessageHandled) {
        _initialMessageHandled = true;
        final initialMessage = widget.initialMessage?.trim() ?? '';
        if (initialMessage.isNotEmpty) {
          await _sendMessage(initialMessage);
          return;
        }
      }

      if (!mounted) return;
      setState(() => _showEntrySkeleton = false);
      _scheduleScrollToBottom();
    } on AppApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _showEntrySkeleton = false;
        _loadError = error.message;
      });
    }
  }

  void _applyConversation(Map<String, dynamic> data) {
    final previousConversationId = _conversationId;
    _conversationId = data['id']?.toString() ?? _conversationId;
    _conversation = Map<String, dynamic>.from(data);
    if (_conversationId != null && _conversationId != previousConversationId) {
      _bindRealtimeUpdates();
    }
    final rawMessages = (data['messages'] as List?) ?? const [];
    _messages
      ..clear()
      ..addAll(
        rawMessages.whereType<Map>().map(
          (message) => _ChatMessage(
            id: message['id']?.toString(),
            message: (message['content'] as String?) ?? '',
            time: _formatMessageTime(message['createdAt'] as String?),
            isMine: message['isMine'] == true,
            product: _ChatMessageProduct.fromApi(message['product']),
          ),
        ),
      );
  }

  String _formatMessageTime(String? isoValue) {
    final dateTime = isoValue == null
        ? null
        : DateTime.tryParse(isoValue)?.toLocal();
    if (dateTime == null) {
      return '';
    }
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _sendMessage(String text) async {
    final content = text.trim();
    if (content.isEmpty || !_usesLiveConversation || _isSending) {
      return;
    }

    final shouldAttachInitialProductContext =
        widget.embedProductContextInInitialMessage &&
        !_initialProductContextSent &&
        _productTitleValue.isNotEmpty;

    _typingStopTimer?.cancel();
    _emitTyping(false);
    setState(() => _isSending = true);
    try {
      final data =
          shouldAttachInitialProductContext &&
              (widget.conversationUserId?.isNotEmpty ?? false)
          ? await _conversationsApiService.sendUserMessage(
              targetUserId: widget.conversationUserId!,
              content: content,
              productSnapshot: {
                'productId': widget.conversationProductId,
                'productTitle': _productTitleValue,
                'productSubtitle': _productSubtitleValue,
                'productPriceLabel': _productPriceLabelValue,
                'productImageUrl': _productImageUrlValue,
              },
            )
          : (widget.conversationProductId?.isNotEmpty ?? false) &&
                (widget.conversationUserId?.isNotEmpty ?? false) == false
          ? await _conversationsApiService.sendProductMessage(
              productId: widget.conversationProductId!,
              content: content,
            )
          : (widget.conversationUserId?.isNotEmpty ?? false)
          ? await _conversationsApiService.sendUserMessage(
              targetUserId: widget.conversationUserId!,
              content: content,
            )
          : _conversationId != null
          ? await _conversationsApiService.sendMessage(
              conversationId: _conversationId!,
              content: content,
            )
          : await _conversationsApiService.sendMessage(
              conversationId: _conversationId!,
              content: content,
            );
      _applyConversation(data);
      if (!mounted) return;
      _messageController.clear();
      _initialProductContextSent = true;
      setState(() => _showEntrySkeleton = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _animateToBottom());
    } on AppApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _handleAttachment(UiChatAttachment attachment) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${attachment.label} n\'est pas encore supporte.'),
      ),
    );
  }

  void _scheduleScrollToBottom({int remaining = _scrollRetryCount}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _jumpToBottom();
      if (remaining > 0) {
        _scheduleScrollToBottom(remaining: remaining - 1);
      }
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

  void _openProductCard() {
    final product = _productValue;
    final productPageBuilder = widget.productPageBuilder;
    if (product != null && productPageBuilder != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => productPageBuilder(product, openedFromChat: true),
        ),
      );
    }
  }

  Future<void> _openMessageProductCard(_ChatMessageProduct product) async {
    final productPageBuilder = widget.productPageBuilder;
    if (productPageBuilder == null) {
      return;
    }

    final productId = product.id?.trim() ?? '';
    if (productId.isEmpty) {
      return;
    }

    final currentProduct = _productValue;
    final currentProductId = currentProduct?['id']?.toString().trim() ?? '';
    if (currentProduct != null && currentProductId == productId) {
      if (!mounted) {
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              productPageBuilder(currentProduct, openedFromChat: true),
        ),
      );
      return;
    }

    try {
      final fetchedProduct = await _catalogApiService.fetchProductById(
        productId,
      );
      if (!mounted) {
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              productPageBuilder(fetchedProduct, openedFromChat: true),
        ),
      );
    } on AppApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final primary = appColors.onlineStatus;
    final background = appColors.backgroundBase;
    final headerColor = appColors.panelBackground;
    final incomingBubbleColor = appColors.panelBackground;
    final outgoingBubbleColor = appColors.onlineStatus.withValues(alpha: 0.28);
    const panelColor = Colors.transparent;
    final subtleText = appColors.mutedText;
    final sellerName = _sellerNameValue;
    final avatarUrl = _avatarUrlValue;

    return Scaffold(
      backgroundColor: background,
      body: _showEntrySkeleton
          ? const SafeArea(child: SellerChatSkeleton())
          : SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(child: const _ChatPatternBackground()),
                  Column(
                    children: [
                      _ChatHeader(
                        primary: primary,
                        headerColor: headerColor,
                        subtleText: subtleText,
                        sellerName: sellerName,
                        statusText: _participantStatusValue,
                        avatarUrl: avatarUrl,
                        userId: _participantUserId,
                        isOnline: _participantIsOnlineValue,
                      ),
                      if (widget.showProductContextCard &&
                          _productTitleValue.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                          child: _ProductContextCard(
                            primary: primary,
                            subtleText: subtleText,
                            onTap: _openProductCard,
                            productTitle: _productTitleValue,
                            productSubtitle: _productSubtitleValue,
                            productPriceLabel: _productPriceLabelValue,
                            productImageUrl: _productImageUrlValue,
                          ),
                        ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: refreshPageWithDialog,
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(10, 12, 10, 18),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: appColors.panelBackground,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Aujourd\'hui',
                                    style: TextStyle(
                                      color: subtleText,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (_loadError != null)
                                  _ChatInfoCard(
                                    text: _loadError!,
                                    color: theme.colorScheme.error,
                                    cardColor: incomingBubbleColor,
                                  )
                                else if (_messages.isEmpty)
                                  _ChatInfoCard(
                                    text: 'Aucun message pour le moment.',
                                    color: subtleText,
                                    cardColor: incomingBubbleColor,
                                  )
                                else
                                  ..._messages.map(
                                    (chat) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: _ChatBubble(
                                        message: chat.message,
                                        time: chat.time,
                                        isMine: chat.isMine,
                                        product: chat.product,
                                        onProductTap:
                                            !widget.showInlineProductSnapshots ||
                                                chat.product == null
                                            ? null
                                            : () => _openMessageProductCard(
                                                chat.product!,
                                              ),
                                        avatarUrl: avatarUrl,
                                        participantUserId: _participantUserId,
                                        primary: primary,
                                        incomingBubbleColor:
                                            incomingBubbleColor,
                                        outgoingBubbleColor:
                                            outgoingBubbleColor,
                                        subtleText: subtleText,
                                      ),
                                    ),
                                  ),
                                if (_isParticipantTyping) ...[
                                  const SizedBox(height: 6),
                                  _TypingIndicatorBubble(
                                    cardColor: incomingBubbleColor,
                                    subtleText: subtleText,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        color: headerColor,
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                        child: UiChatMessageInput(
                          controller: _messageController,
                          onAttachmentSelected: _handleAttachment,
                          onTextChanged: _handleComposerChanged,
                          onSend: _sendMessage,
                          primary: primary,
                          panelColor: panelColor,
                          borderColor: appColors.inputBorder,
                          hintText: 'Message',
                        ),
                      ),
                    ],
                  ),
                  if (isOffline) const AppOfflineBanner(bottomOffset: 78),
                ],
              ),
            ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final Color primary;
  final Color headerColor;
  final Color subtleText;
  final String sellerName;
  final String statusText;
  final String avatarUrl;
  final String? userId;
  final bool isOnline;

  const _ChatHeader({
    required this.primary,
    required this.headerColor,
    required this.subtleText,
    required this.sellerName,
    required this.statusText,
    required this.avatarUrl,
    this.userId,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).appColors;
    final normalizedUserId = userId?.trim() ?? '';
    if (normalizedUserId.isNotEmpty) {
      PresenceService.instance.watchUser(normalizedUserId);
    }

    return ValueListenableBuilder<int>(
      valueListenable: PresenceService.instance.changes,
      builder: (context, value, child) {
        final livePresence = normalizedUserId.isEmpty
            ? null
            : PresenceService.instance.presenceOf(normalizedUserId);
        final resolvedIsOnline = livePresence ?? isOnline;
        final resolvedStatusText = resolvedIsOnline ? 'En ligne' : statusText;

        return Container(
          height: 72,
          color: headerColor,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                splashRadius: 20,
              ),
              AppCircleNetworkAvatar(
                radius: 21,
                imageUrl: avatarUrl,
                userId: userId,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sellerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      resolvedStatusText,
                      style: TextStyle(
                        color: resolvedIsOnline
                            ? Colors.white.withValues(alpha: 0.88)
                            : subtleText,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _ChatHeaderAction(icon: Icons.videocam_outlined, onTap: () {}),
              _ChatHeaderAction(icon: Icons.call_outlined, onTap: () {}),
              _ChatHeaderAction(icon: Icons.more_vert, onTap: () {}),
            ],
          ),
        );
      },
    );
  }
}

class _ChatHeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ChatHeaderAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      splashRadius: 20,
      icon: Icon(icon, color: Colors.white.withValues(alpha: 0.94), size: 23),
    );
  }
}

class _ChatPatternBackground extends StatelessWidget {
  const _ChatPatternBackground();

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).appColors;

    return DecoratedBox(
      decoration: BoxDecoration(color: appColors.backgroundBase),
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = (constraints.maxWidth / 72).ceil();
            final rows = (constraints.maxHeight / 72).ceil();
            return Stack(
              children: [
                for (var row = 0; row < rows; row++)
                  for (var column = 0; column < columns; column++)
                    Positioned(
                      left: column * 72.0 + (row.isEven ? 8 : 26),
                      top: row * 72.0 + (column.isEven ? 10 : 28),
                      child: Opacity(
                        opacity: 0.06,
                        child: Icon(
                          (row + column).isEven
                              ? Icons.chat_bubble_outline_rounded
                              : Icons.star_border_rounded,
                          size: ((row + column) % 3 == 0) ? 18 : 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProductContextCard extends StatelessWidget {
  final Color primary;
  final Color subtleText;
  final VoidCallback? onTap;
  final String productTitle;
  final String productSubtitle;
  final String productPriceLabel;
  final String productImageUrl;

  const _ProductContextCard({
    required this.primary,
    required this.subtleText,
    this.onTap,
    required this.productTitle,
    required this.productSubtitle,
    required this.productPriceLabel,
    required this.productImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).appColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: appColors.panelBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: appColors.inputBorder),
          ),
          child: Row(
            children: [
              if (productImageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AppNetworkImage(
                    imageUrl: productImageUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              if (productImageUrl.isNotEmpty) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productTitle,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (productSubtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        productSubtitle,
                        style: TextStyle(
                          color: subtleText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (productPriceLabel.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          productPriceLabel,
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String? id;
  final String message;
  final String time;
  final bool isMine;
  final _ChatMessageProduct? product;

  const _ChatMessage({
    this.id,
    required this.message,
    required this.time,
    required this.isMine,
    this.product,
  });
}

class _ChatMessageProduct {
  final String? id;
  final String title;
  final String subtitle;
  final String priceLabel;
  final String imageUrl;

  const _ChatMessageProduct({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.priceLabel,
    required this.imageUrl,
  });

  static _ChatMessageProduct? fromApi(dynamic value) {
    if (value is! Map) {
      return null;
    }

    final title = (value['title'] as String? ?? '').trim();
    final subtitle = (value['subtitle'] as String? ?? '').trim();
    final priceLabel = (value['priceLabel'] as String? ?? '').trim();
    final imageUrl = (value['imageUrl'] as String? ?? '').trim();
    final id = value['id']?.toString().trim();

    if (title.isEmpty &&
        subtitle.isEmpty &&
        priceLabel.isEmpty &&
        imageUrl.isEmpty &&
        (id == null || id.isEmpty)) {
      return null;
    }

    return _ChatMessageProduct(
      id: id,
      title: title,
      subtitle: subtitle,
      priceLabel: priceLabel,
      imageUrl: imageUrl,
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String message;
  final String time;
  final bool isMine;
  final _ChatMessageProduct? product;
  final VoidCallback? onProductTap;
  final String avatarUrl;
  final String? participantUserId;
  final Color primary;
  final Color incomingBubbleColor;
  final Color outgoingBubbleColor;
  final Color subtleText;

  const _ChatBubble({
    required this.message,
    required this.time,
    required this.isMine,
    this.product,
    this.onProductTap,
    required this.avatarUrl,
    this.participantUserId,
    required this.primary,
    required this.incomingBubbleColor,
    required this.outgoingBubbleColor,
    required this.subtleText,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine ? outgoingBubbleColor : incomingBubbleColor;
    final textColor = Colors.white.withValues(alpha: 0.96);
    final metaColor = isMine
        ? primary.withValues(alpha: 0.74)
        : subtleText.withValues(alpha: 0.92);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isMine ? 290 : 276),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isMine ? 12 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product != null && onProductTap != null) ...[
                    _InlineProductSnapshotCard(
                      product: product!,
                      isMine: isMine,
                      primary: primary,
                      cardColor: incomingBubbleColor,
                      subtleText: metaColor,
                      onTap: onProductTap,
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    message,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
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
                        const SizedBox(width: 4),
                        Icon(Icons.done_all_rounded, size: 15, color: primary),
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

class _InlineProductSnapshotCard extends StatelessWidget {
  final _ChatMessageProduct product;
  final bool isMine;
  final Color primary;
  final Color cardColor;
  final Color subtleText;
  final VoidCallback? onTap;

  const _InlineProductSnapshotCard({
    required this.product,
    required this.isMine,
    required this.primary,
    required this.cardColor,
    required this.subtleText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).appColors;
    final surfaceColor = isMine
        ? primary.withValues(alpha: 0.18)
        : appColors.panelMuted;
    final borderColor = isMine
        ? primary.withValues(alpha: 0.26)
        : appColors.inputBorder;
    final titleColor = isMine
        ? Theme.of(context).appColors.heroForeground
        : Theme.of(context).colorScheme.onSurface;
    final priceColor = isMine ? Colors.white : primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              if (product.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AppNetworkImage(
                    imageUrl: product.imageUrl,
                    width: 58,
                    height: 58,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              if (product.imageUrl.isNotEmpty) const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (product.title.isNotEmpty)
                      Text(
                        product.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    if (product.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        product.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: subtleText,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (product.priceLabel.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        product.priceLabel,
                        style: TextStyle(
                          color: priceColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatInfoCard extends StatelessWidget {
  final String text;
  final Color color;
  final Color cardColor;

  const _ChatInfoCard({
    required this.text,
    required this.color,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TypingIndicatorBubble extends StatefulWidget {
  final Color cardColor;
  final Color subtleText;

  const _TypingIndicatorBubble({
    required this.cardColor,
    required this.subtleText,
  });

  @override
  State<_TypingIndicatorBubble> createState() => _TypingIndicatorBubbleState();
}

class _TypingIndicatorBubbleState extends State<_TypingIndicatorBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: widget.cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(12),
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                final phase = (_controller.value - (index * 0.18)) % 1.0;
                final opacity =
                    0.28 + ((phase < 0.5 ? phase : 1 - phase) * 1.4);
                final scale = 0.82 + ((phase < 0.5 ? phase : 1 - phase) * 0.5);

                return Padding(
                  padding: EdgeInsets.only(right: index == 2 ? 0 : 6),
                  child: Transform.scale(
                    scale: scale.clamp(0.82, 1.12),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: widget.subtleText.withValues(
                          alpha: opacity.clamp(0.28, 0.92),
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
