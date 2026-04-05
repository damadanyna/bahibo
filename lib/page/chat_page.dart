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

    _typingStopTimer?.cancel();
    _emitTyping(false);
    setState(() => _isSending = true);
    try {
      final data = (widget.conversationProductId?.isNotEmpty ?? false)
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
      Navigator.pushReplacement(
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

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => productPageBuilder(currentProduct, openedFromChat: true),
        ),
      );
      return;
    }

    try {
      final fetchedProduct = await _catalogApiService.fetchProductById(productId);
      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => productPageBuilder(fetchedProduct, openedFromChat: true),
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
    final isDark = theme.brightness == Brightness.dark;
    final appColors = theme.appColors;
    final primary = theme.colorScheme.primary;
    final background = appColors.backgroundBase;
    final cardColor = appColors.panelBackground;
    final panelColor = appColors.inputFill;
    final subtleText = appColors.mutedText;
    final sellerName = _sellerNameValue;
    final sellerRole = _sellerRoleValue;
    final avatarUrl = _avatarUrlValue;

    return Scaffold(
      backgroundColor: background,
      body: _showEntrySkeleton
          ? const SafeArea(child: SellerChatSkeleton())
          : SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            primary.withValues(alpha: isDark ? 0.12 : 0.08),
                            background,
                            background,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: refreshPageWithDialog,
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                            child: Column(
                              children: [
                                _ChatHeader(
                                  primary: primary,
                                  cardColor: cardColor,
                                  subtleText: subtleText,
                                  sellerName: sellerName,
                                  sellerRole: sellerRole,
                                  avatarUrl: avatarUrl,
                                ),
                                if (_productTitleValue.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  _ProductContextCard(
                                    primary: primary,
                                    cardColor: cardColor,
                                    subtleText: subtleText,
                                    onTap: _openProductCard,
                                    productTitle: _productTitleValue,
                                    productSubtitle: _productSubtitleValue,
                                    productPriceLabel: _productPriceLabelValue,
                                    productImageUrl: _productImageUrlValue,
                                  ),
                                ],
                                const SizedBox(height: 18),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: panelColor,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: theme.appColors.inputBorder,
                                    ),
                                  ),
                                  child: Text(
                                    'Aujourd\'hui',
                                    style: TextStyle(
                                      color: subtleText,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                if (_loadError != null)
                                  _ChatInfoCard(
                                    text: _loadError!,
                                    color: theme.colorScheme.error,
                                    cardColor: cardColor,
                                  )
                                else if (_messages.isEmpty)
                                  _ChatInfoCard(
                                    text: 'Aucun message pour le moment.',
                                    color: subtleText,
                                    cardColor: cardColor,
                                  )
                                else
                                  ..._messages.map(
                                    (chat) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 14,
                                      ),
                                      child: _ChatBubble(
                                        message: chat.message,
                                        time: chat.time,
                                        isMine: chat.isMine,
                                        product: chat.product,
                                        onProductTap: chat.product == null
                                            ? null
                                            : () => _openMessageProductCard(
                                                chat.product!,
                                              ),
                                        avatarUrl: avatarUrl,
                                        isDark: isDark,
                                        primary: primary,
                                        cardColor: cardColor,
                                        subtleText: subtleText,
                                      ),
                                    ),
                                  ),
                                if (_isParticipantTyping) ...[
                                  const SizedBox(height: 6),
                                  _TypingIndicatorBubble(
                                    avatarUrl: avatarUrl,
                                    cardColor: cardColor,
                                    subtleText: subtleText,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                        child: UiChatMessageInput(
                          controller: _messageController,
                          onAttachmentSelected: _handleAttachment,
                          onTextChanged: _handleComposerChanged,
                          onSend: _sendMessage,
                          primary: primary,
                          panelColor: panelColor,
                        ),
                      ),
                    ],
                  ),
                  Positioned(top: 18, left: 18, child: const AppBackButton()),
                  if (isOffline) const AppOfflineBanner(bottomOffset: 78),
                ],
              ),
            ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final Color primary;
  final Color cardColor;
  final Color subtleText;
  final String sellerName;
  final String sellerRole;
  final String avatarUrl;

  const _ChatHeader({
    required this.primary,
    required this.cardColor,
    required this.subtleText,
    required this.sellerName,
    required this.sellerRole,
    required this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).appColors;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 32, 18, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary.withValues(alpha: 0.92), appColors.heroAccent],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: appColors.heroBorder),
            ),
            child: AppCircleNetworkAvatar(radius: 26, imageUrl: avatarUrl),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sellerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: appColors.heroForeground,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sellerRole,
                  style: TextStyle(
                    color: appColors.heroForegroundMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductContextCard extends StatelessWidget {
  final Color primary;
  final Color cardColor;
  final Color subtleText;
  final VoidCallback? onTap;
  final String productTitle;
  final String productSubtitle;
  final String productPriceLabel;
  final String productImageUrl;

  const _ProductContextCard({
    required this.primary,
    required this.cardColor,
    required this.subtleText,
    this.onTap,
    required this.productTitle,
    required this.productSubtitle,
    required this.productPriceLabel,
    required this.productImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Theme.of(context).appColors.inputBorder),
          ),
          child: Row(
            children: [
              if (productImageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: AppNetworkImage(
                    imageUrl: productImageUrl,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              if (productImageUrl.isNotEmpty) const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productTitle,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
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
                          horizontal: 10,
                          vertical: 6,
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

    if (
        title.isEmpty &&
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
  final bool isDark;
  final Color primary;
  final Color cardColor;
  final Color subtleText;

  const _ChatBubble({
    required this.message,
    required this.time,
    required this.isMine,
    this.product,
    this.onProductTap,
    required this.avatarUrl,
    required this.isDark,
    required this.primary,
    required this.cardColor,
    required this.subtleText,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).appColors;
    final bubbleColor = isMine
        ? primary.withValues(alpha: isDark ? 0.90 : 0.96)
        : cardColor;
    final textColor = isMine
        ? appColors.heroForeground
        : Theme.of(context).colorScheme.onSurface;
    final metaColor = isMine ? appColors.heroForegroundMuted : subtleText;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMine) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 10),
              child: AppCircleNetworkAvatar(radius: 16, imageUrl: avatarUrl),
            ),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isMine ? 290 : 248),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(22),
                  topRight: const Radius.circular(22),
                  bottomLeft: Radius.circular(isMine ? 22 : 8),
                  bottomRight: Radius.circular(isMine ? 8 : 22),
                ),
                border: Border.all(
                  color: isMine
                      ? appColors.heroBorder
                      : Theme.of(context).appColors.inputBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product != null) ...[
                    _InlineProductSnapshotCard(
                      product: product!,
                      isMine: isMine,
                      primary: primary,
                      cardColor: cardColor,
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
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                        const SizedBox(width: 6),
                        Icon(
                          Icons.done_all_rounded,
                          size: 15,
                          color: Theme.of(context).appColors.heroForeground,
                        ),
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
    final surfaceColor = isMine
        ? Colors.white.withValues(alpha: 0.14)
        : Theme.of(context).appColors.panelBackground;
    final borderColor = isMine
        ? Colors.white.withValues(alpha: 0.24)
        : Theme.of(context).appColors.inputBorder;
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
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).appColors.inputBorder),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TypingIndicatorBubble extends StatefulWidget {
  final String avatarUrl;
  final Color cardColor;
  final Color subtleText;

  const _TypingIndicatorBubble({
    required this.avatarUrl,
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
    final borderColor = Theme.of(context).appColors.inputBorder;

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 10),
            child: AppCircleNetworkAvatar(
              radius: 16,
              imageUrl: widget.avatarUrl,
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: widget.cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(22),
              ),
              border: Border.all(color: borderColor),
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
                    final scale =
                        0.82 + ((phase < 0.5 ? phase : 1 - phase) * 0.5);

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
        ],
      ),
    );
  }
}
