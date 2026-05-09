import 'dart:async';

import 'package:banay/component/app_network_image.dart';
import 'package:banay/component/app_page_refresh.dart';
import 'package:banay/component/app_page_skeletons.dart';
import 'package:banay/component/chat_media_cached_image.dart';
import 'package:banay/component/profile_models.dart';
import 'package:banay/component/seller_profile_page.dart';
import 'package:banay/component/ui/chat_message_input.dart';
import 'package:banay/component/user_profile_page.dart';
import 'package:banay/formatter/price_formatter.dart';
import 'package:banay/page/image_viewer_page.dart';
import 'package:banay/services/app_api_client.dart';
import 'package:banay/services/catalog_api_service.dart';
import 'package:banay/services/chat_realtime_service.dart';
import 'package:banay/services/cloudinary_image_url.dart';
import 'package:banay/services/chat_media_cache_service.dart';
import 'package:banay/services/conversations_api_service.dart';
import 'package:banay/services/presence_service.dart';
import 'package:banay/services/push_notification_service.dart';
import 'package:banay/services/session_storage.dart';
import 'package:banay/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

typedef ChatProductPageBuilder =
    Widget Function(Map<String, dynamic> product, {bool openedFromChat});

enum _ChatHeaderMenuAction { viewProfile, report }

const String _photoAttachmentIdPrefix = 'attachment:photo:';
const String _documentAttachmentIdPrefix = 'attachment:document:';

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
    with AppPageRefreshMixin<ChatPage>, RouteAware {
  static const Duration _conversationPollInterval = Duration(seconds: 3);
  static const Duration _typingStopDelay = Duration(milliseconds: 1200);
  static const Duration _photoUploadProgressTick = Duration(milliseconds: 18);
  final ConversationsApiService _conversationsApiService =
      ConversationsApiService();
  final CatalogApiService _catalogApiService = CatalogApiService();
  final SessionStorage _sessionStorage = SessionStorage();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  final List<_ChatMessage> _pendingMessages = [];
  final Map<String, GlobalKey> _messageKeys = {};
  StreamSubscription<Map<String, dynamic>>? _realtimeEventsSubscription;
  Timer? _conversationPollTimer;
  Timer? _messageHighlightTimer;
  Timer? _typingStopTimer;
  Timer? _photoUploadProgressTimer;
  static const int _scrollRetryCount = 4;
  bool _showEntrySkeleton = true;
  bool _isSending = false;
  bool _isParticipantTyping = false;
  bool _isTypingEventActive = false;
  bool _initialMessageHandled = false;
  bool _initialProductContextSent = false;
  bool _conversationBlocked = false;
  int? _photoUploadProgressPercent;
  int _photoUploadTargetPercent = 0;
  String? _uploadingPhotoLabel;
  String? _photoUploadStatusLabel;
  String? _conversationId;
  String? _loadError;
  Map<String, dynamic>? _conversation;
  _ChatMessage? _replyingToMessage;
  String? _highlightedMessageId;
  bool _highlightVisible = false;
  ModalRoute<dynamic>? _route;

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
    final currentConversationId = _conversationId?.trim();
    if (currentConversationId != null && currentConversationId.isNotEmpty) {
      PushNotificationService.setVisibleConversation(null);
    }
    PushNotificationService.routeObserver.unsubscribe(this);
    _realtimeEventsSubscription?.cancel();
    _conversationPollTimer?.cancel();
    _messageHighlightTimer?.cancel();
    _typingStopTimer?.cancel();
    _photoUploadProgressTimer?.cancel();
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);
    if (route == null || identical(route, _route)) {
      return;
    }

    if (_route != null) {
      PushNotificationService.routeObserver.unsubscribe(this);
    }

    _route = route;
    if (route is PageRoute<dynamic>) {
      PushNotificationService.routeObserver.subscribe(this, route);
    }
  }

  void _syncVisibleConversationRegistration() {
    PushNotificationService.setVisibleConversation(_conversationId);
  }

  @override
  void didPush() {
    _syncVisibleConversationRegistration();
  }

  @override
  void didPopNext() {
    _syncVisibleConversationRegistration();
  }

  @override
  void didPushNext() {
    PushNotificationService.setVisibleConversation(null);
  }

  @override
  void didPop() {
    PushNotificationService.setVisibleConversation(null);
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
          return 'En ligne a l\'instant';
        }
        if (difference.inMinutes < 60) {
          return 'En ligne il y a ${difference.inMinutes} min';
        }
        if (difference.inHours < 24) {
          return 'En ligne il y a ${difference.inHours} h';
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
      if (event['type'] == 'profile:public-updated') {
        final updatedUserId = event['userId']?.toString();
        if (updatedUserId != null && updatedUserId == _participantUserId) {
          _applyParticipantProfileUpdate(event);
        }
        return;
      }

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

  void _applyParticipantProfileUpdate(Map<String, dynamic> event) {
    final conversation = _conversation;
    final profile = event['profile'];
    if (!mounted || conversation == null || profile is! Map) {
      return;
    }

    final participant = conversation['participant'];
    if (participant is! Map) {
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

    final nextConversation = Map<String, dynamic>.from(conversation);
    final nextParticipant = Map<String, dynamic>.from(participant);
    var hasChanged = false;

    if (resolvedName.isNotEmpty &&
        nextParticipant['displayName'] != resolvedName) {
      nextParticipant['displayName'] = resolvedName;
      nextParticipant['name'] = resolvedName;
      hasChanged = true;
    }
    if (avatarUrl.isNotEmpty && nextParticipant['avatarUrl'] != avatarUrl) {
      nextParticipant['avatarUrl'] = avatarUrl;
      hasChanged = true;
    }
    if (coverImageUrl.isNotEmpty &&
        nextParticipant['coverImageUrl'] != coverImageUrl) {
      nextParticipant['coverImageUrl'] = coverImageUrl;
      hasChanged = true;
    }
    if (role != null && role.isNotEmpty && nextParticipant['role'] != role) {
      nextParticipant['role'] = role;
      hasChanged = true;
    }

    if (!hasChanged) {
      return;
    }

    nextConversation['participant'] = nextParticipant;
    setState(() {
      _conversation = nextConversation;
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
    } on AppApiException catch (error) {
      if (!mounted) return;
      _applyConversationError(error);
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
      _applyConversationError(error, showEntrySkeleton: false);
    }
  }

  void _applyConversation(Map<String, dynamic> data) {
    final previousConversationId = _conversationId;
    _conversationId = data['id']?.toString() ?? _conversationId;
    if (_route?.isCurrent ?? false) {
      _syncVisibleConversationRegistration();
    }
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
            kind: _ChatMessageKind.fromApi(message['kind']),
            time: _formatMessageTime(message['createdAt'] as String?),
            isMine: message['isMine'] == true,
            deliveryState: _resolveDeliveryState(
              isMine: message['isMine'] == true,
              readAt: message['readAt'] as String?,
            ),
            reply: _ChatMessageReply.fromApi(message['reply']),
            media: _ChatMessageMedia.fromApi(message['media']),
            product: _ChatMessageProduct.fromApi(message['product']),
          ),
        ),
      );
    _pendingMessages.clear();
    final participant = data['participant'];
    final participantUserId = participant is Map
        ? participant['id']?.toString().trim()
        : null;
    final blockedParticipantUserId = data['blockedParticipantUserId']
        ?.toString()
        .trim();
    _conversationBlocked =
        data['isBlocked'] == true &&
        participantUserId != null &&
        participantUserId.isNotEmpty &&
        blockedParticipantUserId != null &&
        blockedParticipantUserId.isNotEmpty &&
        blockedParticipantUserId == participantUserId;
    _loadError = _conversationBlocked
        ? (data['blockedMessage']?.toString().trim().isNotEmpty == true
              ? data['blockedMessage']!.toString().trim()
              : 'Cette discussion est bloquee. Vous pouvez lire l\'historique, mais vous ne pouvez plus envoyer de nouveaux messages.')
        : null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_precacheRecentChatImages());
    });
  }

  String _chatImageBubbleUrl(_ChatMessageMedia media) {
    final thumbnailUrl = media.thumbnailUrl?.trim() ?? '';
    if (thumbnailUrl.isNotEmpty) {
      return thumbnailUrl;
    }

    final previewUrl = media.previewUrl?.trim() ?? '';
    if (previewUrl.isNotEmpty) {
      return CloudinaryImageUrl.forChatThumbnail(previewUrl);
    }

    return CloudinaryImageUrl.forChatThumbnail(media.publicUrl);
  }

  String _chatImageViewerUrl(_ChatMessageMedia media) {
    final publicUrl = media.publicUrl.trim();
    if (publicUrl.isNotEmpty) {
      return CloudinaryImageUrl.forViewer(publicUrl);
    }

    final previewUrl = media.previewUrl?.trim() ?? '';
    if (previewUrl.isNotEmpty) {
      return CloudinaryImageUrl.forViewer(previewUrl);
    }

    return '';
  }

  Future<void> _precacheRecentChatImages() async {
    final mediaToPrecache = <String>{};

    for (final message in _messages.reversed) {
      final media = message.media;
      if (media == null || media.mediaType != 'image') {
        continue;
      }

      final imageUrl = _chatImageBubbleUrl(media);
      if (imageUrl.isEmpty) {
        continue;
      }

      mediaToPrecache.add(imageUrl);
      if (mediaToPrecache.length >= 6) {
        break;
      }
    }

    for (final imageUrl in mediaToPrecache) {
      await ChatMediaCacheService.instance.prefetch(imageUrl);
    }
  }

  bool _isBlockedError(AppApiException error) {
    final message = error.message.toLowerCase();
    return error.statusCode == 403 && message.contains('bloqu');
  }

  void _applyConversationError(
    AppApiException error, {
    bool? showEntrySkeleton,
  }) {
    setState(() {
      if (showEntrySkeleton != null) {
        _showEntrySkeleton = showEntrySkeleton;
      }
      _conversationBlocked = _isBlockedError(error);
      _loadError = error.message;
      _pendingMessages.clear();
    });
  }

  _ChatMessageDeliveryState? _resolveDeliveryState({
    required bool isMine,
    required String? readAt,
  }) {
    if (!isMine) {
      return null;
    }

    final normalizedReadAt = readAt?.trim() ?? '';
    if (normalizedReadAt.isNotEmpty) {
      return _ChatMessageDeliveryState.seen;
    }

    return _ChatMessageDeliveryState.sent;
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
    if (content.isEmpty ||
        !_usesLiveConversation ||
        _isSending ||
        _conversationBlocked) {
      return;
    }

    final pendingMessage = _ChatMessage(
      id: 'pending-${DateTime.now().microsecondsSinceEpoch}',
      message: content,
      time: _formatMessageTime(DateTime.now().toIso8601String()),
      isMine: true,
      deliveryState: _ChatMessageDeliveryState.sending,
      reply: _replyingToMessage == null
          ? null
          : _ChatMessageReply(
              messageId: _replyingToMessage!.id,
              senderLabel: _replyAuthorLabel(_replyingToMessage!),
              content: _replyingToMessage!.message,
            ),
    );
    final previousReplyingToMessage = _replyingToMessage;

    final shouldAttachInitialProductContext =
        widget.embedProductContextInInitialMessage &&
        !_initialProductContextSent &&
        _productTitleValue.isNotEmpty;

    _typingStopTimer?.cancel();
    _emitTyping(false);
    setState(() {
      _isSending = true;
      _pendingMessages.add(pendingMessage);
      _replyingToMessage = null;
    });
    _messageController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _animateToBottom());
    try {
      final replyPayload = await _replyPayload(previousReplyingToMessage);
      final data =
          shouldAttachInitialProductContext &&
              (widget.conversationUserId?.isNotEmpty ?? false)
          ? await _conversationsApiService.sendUserMessage(
              targetUserId: widget.conversationUserId!,
              content: content,
              reply: replyPayload,
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
              reply: replyPayload,
            )
          : (widget.conversationUserId?.isNotEmpty ?? false)
          ? await _conversationsApiService.sendUserMessage(
              targetUserId: widget.conversationUserId!,
              content: content,
              reply: replyPayload,
            )
          : _conversationId != null
          ? await _conversationsApiService.sendMessage(
              conversationId: _conversationId!,
              content: content,
              reply: replyPayload,
            )
          : await _conversationsApiService.sendMessage(
              conversationId: _conversationId!,
              content: content,
              reply: replyPayload,
            );
      _applyConversation(data);
      if (!mounted) return;
      _initialProductContextSent = true;
      setState(() {
        _showEntrySkeleton = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _animateToBottom());
    } on AppApiException catch (error) {
      if (!mounted) return;
      _messageController
        ..text = content
        ..selection = TextSelection.collapsed(offset: content.length);
      if (_isBlockedError(error)) {
        setState(() {
          _conversationBlocked = true;
          _loadError = error.message;
        });
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      setState(() {
        _pendingMessages.removeWhere(
          (message) => message.id == pendingMessage.id,
        );
        _replyingToMessage = previousReplyingToMessage;
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _setReplyingToMessage(_ChatMessage message) {
    if (!mounted) {
      return;
    }

    setState(() => _replyingToMessage = message);
  }

  void _clearReplyingToMessage() {
    if (!mounted || _replyingToMessage == null) {
      return;
    }

    setState(() => _replyingToMessage = null);
  }

  String _replyAuthorLabel(_ChatMessage message) {
    return message.isMine ? 'Vous' : _sellerNameValue;
  }

  String _messageReplyKey(_ChatMessage message) {
    return message.id ??
        '${message.time}-${message.isMine ? 'mine' : 'their'}-${message.message.hashCode}';
  }

  String _displayMessageReplyKey(_ChatDisplayMessage displayMessage) {
    if (displayMessage.groupId != null && displayMessage.groupId!.isNotEmpty) {
      return displayMessage.groupId!;
    }

    return _messageReplyKey(displayMessage.anchorMessage);
  }

  GlobalKey _displayMessageItemKey(_ChatDisplayMessage displayMessage) {
    final visualKey = _displayMessageReplyKey(displayMessage);
    final key = _messageKeys.putIfAbsent(visualKey, GlobalKey.new);

    for (final message in displayMessage.messages) {
      final messageId = message.id?.trim() ?? '';
      if (messageId.isNotEmpty) {
        _messageKeys[messageId] = key;
      }
    }

    return key;
  }

  List<_ChatDisplayMessage> _buildDisplayMessages(List<_ChatMessage> messages) {
    final displayMessages = <_ChatDisplayMessage>[];
    var index = 0;

    while (index < messages.length) {
      final current = messages[index];
      final groupId = current.media?.mediaGroupId?.trim() ?? '';
      if (groupId.isEmpty) {
        displayMessages.add(_ChatDisplayMessage(messages: [current]));
        index += 1;
        continue;
      }

      final groupedMessages = <_ChatMessage>[current];
      var nextIndex = index + 1;
      while (nextIndex < messages.length) {
        final nextMessage = messages[nextIndex];
        final nextGroupId = nextMessage.media?.mediaGroupId?.trim() ?? '';
        if (nextGroupId != groupId) {
          break;
        }

        groupedMessages.add(nextMessage);
        nextIndex += 1;
      }

      displayMessages.add(_ChatDisplayMessage(messages: groupedMessages));
      index = nextIndex;
    }

    return displayMessages;
  }

  Future<void> _focusRepliedMessage(String? messageId) async {
    final normalizedId = messageId?.trim() ?? '';
    if (normalizedId.isEmpty) {
      return;
    }

    final key = _messageKeys[normalizedId];
    final targetContext = key?.currentContext;
    if (targetContext == null) {
      return;
    }

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.35,
    );

    _blinkMessage(normalizedId);
  }

  void _blinkMessage(String messageId) {
    _messageHighlightTimer?.cancel();
    var tick = 0;

    if (!mounted) {
      return;
    }

    setState(() {
      _highlightedMessageId = messageId;
      _highlightVisible = true;
    });

    _messageHighlightTimer = Timer.periodic(const Duration(milliseconds: 170), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      tick += 1;
      if (tick >= 5) {
        timer.cancel();
        setState(() {
          _highlightedMessageId = null;
          _highlightVisible = false;
        });
        return;
      }

      setState(() => _highlightVisible = !_highlightVisible);
    });
  }

  Future<Map<String, dynamic>?> _replyPayload([
    _ChatMessage? sourceReply,
  ]) async {
    final reply = sourceReply ?? _replyingToMessage;
    if (reply == null) {
      return null;
    }

    final content = reply.message.trim();
    if (content.isEmpty) {
      return null;
    }

    final currentDisplayName =
        (await _sessionStorage.getDisplayName())?.trim() ?? 'Utilisateur';

    return {
      if (reply.id != null && reply.id!.trim().isNotEmpty)
        'replyToMessageId': reply.id!.trim(),
      'replyToSenderUserId': reply.isMine ? '' : (_participantUserId ?? ''),
      'replyToSenderName': reply.isMine ? currentDisplayName : _sellerNameValue,
      'replyToContent': content.length > 500
          ? '${content.substring(0, 497)}...'
          : content,
    };
  }

  Future<void> _handleAttachment(UiChatAttachment attachment) async {
    switch (attachment.type) {
      case UiChatAttachmentType.quickText:
        _handleComposerChanged(attachment.messageText);
        return;
      case UiChatAttachmentType.photo:
        await _sendPhotoAttachment(attachment);
        return;
      case UiChatAttachmentType.document:
        await _sendDocumentAttachment(attachment);
        return;
    }
  }

  Future<void> _sendPhotoAttachment(UiChatAttachment attachment) async {
    final bytes = attachment.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de lire la photo selectionnee.'),
        ),
      );
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _uploadingPhotoLabel = attachment.label;
          _photoUploadProgressPercent = 1;
          _photoUploadTargetPercent = 1;
          _photoUploadStatusLabel = 'Preparation de l\'envoi...';
        });
      }
      _animatePhotoUploadProgressTo(3);

      final upload = await _conversationsApiService.uploadPhotoAttachment(
        fileBytes: bytes,
        fileName: attachment.label,
        onProgress: (progress) {
          if (!mounted) {
            return;
          }

          setState(() {
            _photoUploadStatusLabel = 'Televersement de l\'image...';
          });

          final mappedPercent = (1 + (progress.clamp(0, 1) * 89)).round();
          _animatePhotoUploadProgressTo(mappedPercent);
        },
      );

      if (mounted) {
        setState(() {
          _photoUploadStatusLabel = 'Traitement de l\'image...';
        });
      }
      _animatePhotoUploadProgressTo(94);

      final attachmentUrl = upload['attachmentUrl']?.toString().trim() ?? '';
      if (attachmentUrl.isEmpty) {
        throw AppApiException('Photo invalide apres upload');
      }

      await _sendMediaAttachmentMessage(
        kind: _ChatMessageKind.image,
        content: 'Photo envoyee',
        mediaPayload: {
          'kind': 'IMAGE',
          'mediaType': 'image',
          'publicUrl':
              upload['originalUrl']?.toString().trim().isNotEmpty == true
              ? upload['originalUrl']!.toString().trim()
              : attachmentUrl,
          'fileName': attachment.label,
          'mimeType': _guessMimeTypeFromFileName(attachment.label, true),
          'fileSizeBytes': bytes.length,
          'mediaGroupId': attachment.mediaGroupId,
          'width': attachment.width,
          'height': attachment.height,
          'storageProvider': 'cloudinary',
          'storageKey': upload['publicId']?.toString(),
        },
        pendingMedia: _ChatMessageMedia(
          mediaType: 'image',
          publicUrl: upload['originalUrl']?.toString().trim().isNotEmpty == true
              ? upload['originalUrl']!.toString().trim()
              : attachmentUrl,
          previewUrl: attachmentUrl,
          thumbnailUrl: attachmentUrl,
          fileName: attachment.label,
          mimeType: _guessMimeTypeFromFileName(attachment.label, true),
          fileSizeBytes: bytes.length,
          mediaGroupId: attachment.mediaGroupId,
          width: attachment.width,
          height: attachment.height,
          storageProvider: 'cloudinary',
          storageKey: upload['publicId']?.toString(),
        ),
      );

      if (mounted) {
        setState(() {
          _photoUploadStatusLabel = 'Photo envoyee';
        });
      }
      _animatePhotoUploadProgressTo(100);
      await Future<void>.delayed(const Duration(milliseconds: 420));
    } on AppApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _photoUploadProgressPercent = null;
          _photoUploadTargetPercent = 0;
          _uploadingPhotoLabel = null;
          _photoUploadStatusLabel = null;
        });
      }
      _photoUploadProgressTimer?.cancel();
      _photoUploadProgressTimer = null;
    }
  }

  void _animatePhotoUploadProgressTo(int targetPercent) {
    final normalizedTarget = targetPercent.clamp(1, 100);
    _photoUploadTargetPercent = normalizedTarget;

    if (!mounted) {
      return;
    }

    final currentPercent = _photoUploadProgressPercent;
    if (currentPercent == null) {
      setState(() => _photoUploadProgressPercent = normalizedTarget);
      return;
    }

    if (currentPercent >= normalizedTarget) {
      return;
    }

    _photoUploadProgressTimer ??= Timer.periodic(_photoUploadProgressTick, (
      timer,
    ) {
      if (!mounted || _photoUploadProgressPercent == null) {
        timer.cancel();
        _photoUploadProgressTimer = null;
        return;
      }

      final currentValue = _photoUploadProgressPercent!;
      if (currentValue >= _photoUploadTargetPercent) {
        timer.cancel();
        _photoUploadProgressTimer = null;
        return;
      }

      setState(() {
        _photoUploadProgressPercent = currentValue + 1;
      });
    });
  }

  Future<void> _sendDocumentAttachment(UiChatAttachment attachment) async {
    final bytes = attachment.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de lire le document selectionne.'),
        ),
      );
      return;
    }

    try {
      final upload = await _conversationsApiService.uploadDocumentAttachment(
        fileBytes: bytes,
        fileName: attachment.label,
      );
      final attachmentUrl = upload['attachmentUrl']?.toString().trim() ?? '';
      if (attachmentUrl.isEmpty) {
        throw AppApiException('Document invalide apres upload');
      }

      await _sendMediaAttachmentMessage(
        kind: _ChatMessageKind.document,
        content: 'Document envoye',
        mediaPayload: {
          'kind': 'DOCUMENT',
          'mediaType': 'document',
          'publicUrl': attachmentUrl,
          'fileName': attachment.label,
          'mimeType': _guessMimeTypeFromFileName(attachment.label, false),
          'fileSizeBytes': bytes.length,
          'mediaGroupId': attachment.mediaGroupId,
          'storageProvider': 'cloudinary',
          'storageKey': upload['publicId']?.toString(),
        },
        pendingMedia: _ChatMessageMedia(
          mediaType: 'document',
          publicUrl: attachmentUrl,
          fileName: attachment.label,
          mimeType: _guessMimeTypeFromFileName(attachment.label, false),
          fileSizeBytes: bytes.length,
          mediaGroupId: attachment.mediaGroupId,
          storageProvider: 'cloudinary',
          storageKey: upload['publicId']?.toString(),
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

  String _fileExtensionLabel(String fileName) {
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot < 0 || lastDot == fileName.length - 1) {
      return 'Fichier';
    }

    return fileName.substring(lastDot + 1).toUpperCase();
  }

  String _guessMimeTypeFromFileName(String fileName, bool isImage) {
    final extension = _fileExtensionLabel(fileName).toLowerCase();
    if (isImage) {
      switch (extension) {
        case 'jpg':
        case 'jpeg':
          return 'image/jpeg';
        case 'png':
          return 'image/png';
        case 'webp':
          return 'image/webp';
        case 'heic':
          return 'image/heic';
        case 'heif':
          return 'image/heif';
      }
      return 'image/jpeg';
    }

    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _sendMediaAttachmentMessage({
    required _ChatMessageKind kind,
    required String content,
    required Map<String, dynamic> mediaPayload,
    required _ChatMessageMedia pendingMedia,
  }) async {
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty ||
        !_usesLiveConversation ||
        _isSending ||
        _conversationBlocked) {
      return;
    }

    final pendingMessage = _ChatMessage(
      id: 'pending-${DateTime.now().microsecondsSinceEpoch}',
      message: trimmedContent,
      kind: kind,
      time: _formatMessageTime(DateTime.now().toIso8601String()),
      isMine: true,
      deliveryState: _ChatMessageDeliveryState.sending,
      reply: _replyingToMessage == null
          ? null
          : _ChatMessageReply(
              messageId: _replyingToMessage!.id,
              senderLabel: _replyAuthorLabel(_replyingToMessage!),
              content: _replyingToMessage!.message,
            ),
      media: pendingMedia,
    );
    final previousReplyingToMessage = _replyingToMessage;

    _typingStopTimer?.cancel();
    _emitTyping(false);
    setState(() {
      _isSending = true;
      _pendingMessages.add(pendingMessage);
      _replyingToMessage = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _animateToBottom());

    try {
      final replyPayload = await _replyPayload(previousReplyingToMessage);
      final data =
          (widget.conversationProductId?.isNotEmpty ?? false) &&
              (widget.conversationUserId?.isNotEmpty ?? false) == false
          ? await _conversationsApiService.sendProductMediaMessage(
              productId: widget.conversationProductId!,
              mediaPayload: {'content': trimmedContent, ...mediaPayload},
              reply: replyPayload,
            )
          : (widget.conversationUserId?.isNotEmpty ?? false)
          ? await _conversationsApiService.sendUserMediaMessage(
              targetUserId: widget.conversationUserId!,
              mediaPayload: {'content': trimmedContent, ...mediaPayload},
              reply: replyPayload,
            )
          : _conversationId != null
          ? await _conversationsApiService.sendMediaMessage(
              conversationId: _conversationId!,
              mediaPayload: {'content': trimmedContent, ...mediaPayload},
              reply: replyPayload,
            )
          : await _conversationsApiService.sendMediaMessage(
              conversationId: _conversationId!,
              mediaPayload: {'content': trimmedContent, ...mediaPayload},
              reply: replyPayload,
            );

      _applyConversation(data);
      if (!mounted) {
        return;
      }

      setState(() {
        _showEntrySkeleton = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _animateToBottom());
    } on AppApiException catch (error) {
      if (!mounted) {
        return;
      }

      if (_isBlockedError(error)) {
        setState(() {
          _conversationBlocked = true;
          _loadError = error.message;
        });
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      setState(() {
        _pendingMessages.removeWhere(
          (message) => message.id == pendingMessage.id,
        );
        _replyingToMessage = previousReplyingToMessage;
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
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

  bool _matchesCurrentProductSnapshot(
    _ChatMessageProduct product,
    Map<String, dynamic> currentProduct,
  ) {
    final snapshotTitle = product.title.trim().toLowerCase();
    final currentTitle =
        (currentProduct['title'] ?? currentProduct['name'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    final snapshotImage = product.imageUrl.trim();
    final currentImage =
        (currentProduct['imageUrl'] ?? currentProduct['thumbnail'] ?? '')
            .toString()
            .trim();

    if (snapshotTitle.isNotEmpty && snapshotTitle == currentTitle) {
      return true;
    }

    if (snapshotImage.isNotEmpty && snapshotImage == currentImage) {
      return true;
    }

    return false;
  }

  Future<void> _openMessageProductCard(_ChatMessageProduct product) async {
    final productPageBuilder = widget.productPageBuilder;
    if (productPageBuilder == null) {
      return;
    }

    final productId = product.id?.trim() ?? '';
    final currentProduct = _productValue;
    final currentProductId = currentProduct?['id']?.toString().trim() ?? '';
    if (currentProduct != null &&
        (productId.isEmpty ||
            currentProductId == productId ||
            _matchesCurrentProductSnapshot(product, currentProduct))) {
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

    if (productId.isEmpty) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Detail du produit indisponible.')),
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
      if (currentProduct != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                productPageBuilder(currentProduct, openedFromChat: true),
          ),
        );
        return;
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  bool _isAttachmentSnapshot(_ChatMessageProduct product) {
    final id = product.id?.trim() ?? '';
    return id.startsWith(_photoAttachmentIdPrefix) ||
        id.startsWith(_documentAttachmentIdPrefix);
  }

  bool _isPhotoAttachmentSnapshot(_ChatMessageProduct product) {
    final id = product.id?.trim() ?? '';
    return id.startsWith(_photoAttachmentIdPrefix);
  }

  bool _isDocumentAttachmentSnapshot(_ChatMessageProduct product) {
    final id = product.id?.trim() ?? '';
    return id.startsWith(_documentAttachmentIdPrefix);
  }

  String? _extractAttachmentUrl(_ChatMessageProduct product) {
    final imageUrl = product.imageUrl.trim();
    if (imageUrl.isNotEmpty) {
      return imageUrl;
    }

    final id = product.id?.trim() ?? '';
    if (id.startsWith(_photoAttachmentIdPrefix)) {
      return Uri.decodeComponent(id.substring(_photoAttachmentIdPrefix.length));
    }
    if (id.startsWith(_documentAttachmentIdPrefix)) {
      return Uri.decodeComponent(
        id.substring(_documentAttachmentIdPrefix.length),
      );
    }

    return null;
  }

  Future<void> _downloadAttachmentImage(
    String imageUrl, {
    String? fileName,
  }) async {
    final normalizedUrl = imageUrl.trim();
    if (normalizedUrl.isEmpty) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image indisponible pour le telechargement.'),
        ),
      );
      return;
    }

    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lien de telechargement invalide.')),
      );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          opened
              ? 'Ouverture du telechargement${fileName == null || fileName.trim().isEmpty ? '' : ' : ${fileName.trim()}'}'
              : 'Impossible d\'ouvrir le telechargement pour le moment.',
        ),
      ),
    );
  }

  Future<void> _openAttachmentSnapshot(_ChatMessageProduct product) async {
    if (_isPhotoAttachmentSnapshot(product)) {
      final attachmentUrl = _extractAttachmentUrl(product);
      if (attachmentUrl == null || attachmentUrl.isEmpty) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Photo indisponible.')));
        return;
      }

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ImageViewerPage(
            imageUrls: [attachmentUrl],
            onDownloadImage: (imageUrl) =>
                _downloadAttachmentImage(imageUrl, fileName: product.subtitle),
            overlay: ImageViewerOverlayData(
              title: product.title,
              description: product.subtitle,
              sellerName: _sellerNameValue,
              sellerUserId: _participantUserId,
              sellerAvatarUrl: _avatarUrlValue,
            ),
          ),
        ),
      );
      return;
    }

    if (_isDocumentAttachmentSnapshot(product)) {
      final attachmentUrl = _extractAttachmentUrl(product);
      if (attachmentUrl == null || attachmentUrl.isEmpty) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Document indisponible.')));
        return;
      }

      final uri = Uri.tryParse(attachmentUrl);
      if (uri == null) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lien du document invalide.')),
        );
        return;
      }

      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir ce document pour le moment.'),
          ),
        );
      }
    }
  }

  Future<void> _openChatMedia(_ChatMessageMedia media) async {
    if (media.mediaType == 'image') {
      final imageUrl = _chatImageViewerUrl(media);
      if (imageUrl.isEmpty) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Photo indisponible.')));
        return;
      }

      if (!mounted) {
        return;
      }

      try {
        await ChatMediaCacheService.instance.prefetch(imageUrl);
      } catch (_) {
        // Ignore prefetch failures and continue to the viewer.
      }

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ImageViewerPage(
            imageUrls: [imageUrl],
            onDownloadImage: (imageUrl) =>
                _downloadAttachmentImage(imageUrl, fileName: media.fileName),
            overlay: ImageViewerOverlayData(
              title: 'Photo',
              description: media.fileName,
              sellerName: _sellerNameValue,
              sellerUserId: _participantUserId,
              sellerAvatarUrl: _avatarUrlValue,
            ),
          ),
        ),
      );
      return;
    }

    final uri = Uri.tryParse(media.publicUrl.trim());
    if (uri == null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lien du document invalide.')),
      );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'ouvrir ce document pour le moment.'),
        ),
      );
    }
  }

  Future<void> _openChatMediaGroup(
    List<_ChatMessageMedia> mediaItems, {
    int initialIndex = 0,
  }) async {
    if (mediaItems.isEmpty) {
      return;
    }

    final allImages = mediaItems.every((media) => media.mediaType == 'image');
    if (!allImages) {
      final normalizedIndex = initialIndex.clamp(0, mediaItems.length - 1);
      await _openChatMedia(mediaItems[normalizedIndex]);
      return;
    }

    final imageUrls = mediaItems
        .map(_chatImageViewerUrl)
        .where((imageUrl) => imageUrl.isNotEmpty)
        .toList(growable: false);
    if (imageUrls.isEmpty) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Photos indisponibles.')));
      return;
    }

    for (final imageUrl in imageUrls.take(4)) {
      try {
        await ChatMediaCacheService.instance.prefetch(imageUrl);
      } catch (_) {
        // Ignore prefetch failures and continue to the viewer.
      }
    }

    if (!mounted) {
      return;
    }

    final normalizedInitialIndex = initialIndex.clamp(0, imageUrls.length - 1);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImageViewerPage(
          imageUrls: imageUrls,
          initialIndex: normalizedInitialIndex,
          onDownloadImage: (imageUrl) => _downloadAttachmentImage(imageUrl),
          overlay: ImageViewerOverlayData(
            title: imageUrls.length > 1 ? 'Photos' : 'Photo',
            description: imageUrls.length > 1
                ? '${imageUrls.length} photos envoyees'
                : mediaItems.first.fileName,
            sellerName: _sellerNameValue,
            sellerUserId: _participantUserId,
            sellerAvatarUrl: _avatarUrlValue,
          ),
        ),
      ),
    );
  }

  Future<void> _openParticipantProfile() async {
    final userId = _participantUserId?.trim() ?? '';
    if (userId.isEmpty) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FutureBuilder<Map<String, dynamic>>(
          future: _catalogApiService.fetchUserProfile(userId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Scaffold(
                backgroundColor: Theme.of(context).appColors.backgroundBase,
                body: Center(
                  child: Text(
                    'Impossible de charger le profil.',
                    style: TextStyle(
                      color: Theme.of(context).appColors.mutedText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return Scaffold(
                backgroundColor: Theme.of(context).appColors.backgroundBase,
                body: const Center(child: CircularProgressIndicator()),
              );
            }

            final profile = buildPublicUserProfileFromApi(snapshot.data!);
            final sellerProfileId = profile.sellerProfileId?.trim() ?? '';

            if (sellerProfileId.isNotEmpty) {
              return SellerProfilePage(profile: profile);
            }

            return UserProfilePage(profile: profile);
          },
        ),
      ),
    );
  }

  Future<void> _showReportParticipantDialog() async {
    final userId = _participantUserId?.trim() ?? '';
    if (userId.isEmpty) {
      return;
    }

    var blockUser = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final appColors = theme.appColors;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: appColors.panelBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.thumb_down_alt_outlined,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                      size: 26,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Signaler a BANAY',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Les 5 derniers messages de cette discussion seront envoyes a BANAY. Cette personne ne saura pas que vous l\'avez bloquee ou signalee.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: appColors.mutedText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => setDialogState(() => blockUser = !blockUser),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: blockUser,
                              onChanged: (value) => setDialogState(
                                () => blockUser = value ?? false,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bloquer $_sellerNameValue',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Cette personne ne pourra plus vous envoyer de messages ni vous appeler.',
                                    style: TextStyle(
                                      color: appColors.mutedText,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: Text(
                            'Annuler',
                            style: TextStyle(color: appColors.onlineStatus),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          child: Text(
                            'Signaler',
                            style: TextStyle(color: appColors.onlineStatus),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await _catalogApiService.reportUser(
        userId,
        conversationId: _conversationId,
        reason: 'CHAT_REPORT',
        blockUser: blockUser,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            blockUser
                ? 'Signalement envoye. La demande de blocage a ete enregistree.'
                : 'Signalement envoye avec succes.',
          ),
        ),
      );

      if (blockUser) {
        setState(() {
          _conversationBlocked = true;
          _loadError =
              'Cette conversation est bloquee. Vous ne pouvez plus envoyer de messages.';
        });
      }
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
    final primary = theme.colorScheme.primary;
    final background = appColors.backgroundBase;
    final headerColor = appColors.backgroundBase;
    final incomingBubbleColor = appColors.panelBackground;
    final outgoingBubbleColor = primary.withValues(alpha: 0.28);
    const panelColor = Colors.transparent;
    final subtleText = appColors.mutedText;
    final sellerName = _sellerNameValue;
    final avatarUrl = _avatarUrlValue;
    final displayMessages = _buildDisplayMessages([
      ..._messages,
      ..._pendingMessages,
    ]);

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
                        onViewProfile: _openParticipantProfile,
                        onReport: _showReportParticipantDialog,
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
                                else if (displayMessages.isEmpty)
                                  _ChatInfoCard(
                                    text: 'Aucun message pour le moment.',
                                    color: subtleText,
                                    cardColor: incomingBubbleColor,
                                  )
                                else
                                  ...displayMessages.map((displayMessage) {
                                    final chat = displayMessage.anchorMessage;
                                    final visualKey = _displayMessageReplyKey(
                                      displayMessage,
                                    );
                                    return Padding(
                                      key: _displayMessageItemKey(
                                        displayMessage,
                                      ),
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: _SwipeReplyWrapper(
                                        isMine: chat.isMine,
                                        primary: primary,
                                        onReply: () =>
                                            _setReplyingToMessage(chat),
                                        child: _ChatBubble(
                                          message: displayMessage.messageText,
                                          kind: chat.kind,
                                          time: chat.time,
                                          isMine: chat.isMine,
                                          deliveryState: chat.deliveryState,
                                          reply: chat.reply,
                                          isHighlighted:
                                              _highlightedMessageId ==
                                                  visualKey &&
                                              _highlightVisible,
                                          onReplyTap:
                                              chat.reply?.messageId == null
                                              ? null
                                              : () => _focusRepliedMessage(
                                                  chat.reply!.messageId,
                                                ),
                                          mediaItems: displayMessage.mediaItems,
                                          onMediaTapAtIndex:
                                              displayMessage.mediaItems.isEmpty
                                              ? null
                                              : (mediaIndex) =>
                                                    _openChatMediaGroup(
                                                      displayMessage.mediaItems,
                                                      initialIndex: mediaIndex,
                                                    ),
                                          product: chat.product,
                                          onProductTap:
                                              displayMessage
                                                      .mediaItems
                                                      .isNotEmpty ||
                                                  !widget
                                                      .showInlineProductSnapshots ||
                                                  chat.product == null
                                              ? null
                                              : _isAttachmentSnapshot(
                                                  chat.product!,
                                                )
                                              ? () => _openAttachmentSnapshot(
                                                  chat.product!,
                                                )
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
                                    );
                                  }),
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
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_replyingToMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _ReplyComposerCard(
                                  primary: primary,
                                  appColors: appColors,
                                  authorLabel: _replyAuthorLabel(
                                    _replyingToMessage!,
                                  ),
                                  message: _replyingToMessage!.message,
                                  onClose: _clearReplyingToMessage,
                                ),
                              ),
                            if (_conversationBlocked)
                              _ChatInfoCard(
                                text:
                                    'Cette discussion est bloquee. Vous pouvez lire l\'historique, mais vous ne pouvez plus envoyer de nouveaux messages.',
                                color: theme.colorScheme.error,
                                cardColor: incomingBubbleColor,
                              )
                            else
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_photoUploadProgressPercent != null) ...[
                                    _AttachmentUploadProgressCard(
                                      label:
                                          _uploadingPhotoLabel ??
                                          'Photo en cours',
                                      statusLabel:
                                          _photoUploadStatusLabel ??
                                          'Televersement de l\'image...',
                                      progressPercent:
                                          _photoUploadProgressPercent!,
                                      primary: primary,
                                      cardColor: incomingBubbleColor,
                                      subtleText: subtleText,
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  AbsorbPointer(
                                    absorbing:
                                        _photoUploadProgressPercent != null,
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
                          ],
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

class _ChatHeader extends StatefulWidget {
  final Color primary;
  final Color headerColor;
  final Color subtleText;
  final String sellerName;
  final String statusText;
  final String avatarUrl;
  final String? userId;
  final bool isOnline;
  final VoidCallback onViewProfile;
  final VoidCallback onReport;

  const _ChatHeader({
    required this.primary,
    required this.headerColor,
    required this.subtleText,
    required this.sellerName,
    required this.statusText,
    required this.avatarUrl,
    this.userId,
    this.isOnline = false,
    required this.onViewProfile,
    required this.onReport,
  });

  @override
  State<_ChatHeader> createState() => _ChatHeaderState();
}

class _ChatHeaderState extends State<_ChatHeader> {
  Timer? _statusRefreshTimer;

  @override
  void initState() {
    super.initState();
    _statusRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _statusRefreshTimer?.cancel();
    super.dispose();
  }

  String _formatLiveLastSeen(DateTime lastSeenAt) {
    final difference = DateTime.now().difference(lastSeenAt);
    if (difference.inSeconds < 45) {
      return 'En ligne a l\'instant';
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

  @override
  Widget build(BuildContext context) {
    final normalizedUserId = widget.userId?.trim() ?? '';
    if (normalizedUserId.isNotEmpty) {
      PresenceService.instance.watchUser(normalizedUserId);
    }

    return ValueListenableBuilder<int>(
      valueListenable: PresenceService.instance.changes,
      builder: (context, value, child) {
        final livePresence = normalizedUserId.isEmpty
            ? null
            : PresenceService.instance.presenceOf(normalizedUserId);
        final liveLastSeen = normalizedUserId.isEmpty
            ? null
            : PresenceService.instance.lastSeenOf(normalizedUserId);
        final resolvedIsOnline = livePresence ?? widget.isOnline;
        final resolvedStatusText = resolvedIsOnline
            ? 'En ligne'
            : liveLastSeen != null
            ? _formatLiveLastSeen(liveLastSeen)
            : widget.statusText;

        return Container(
          height: 72,
          color: widget.headerColor,
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
                imageUrl: widget.avatarUrl,
                userId: widget.userId,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.sellerName,
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
                            : widget.subtleText,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_ChatHeaderMenuAction>(
                color: widget.headerColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (value) {
                  if (value == _ChatHeaderMenuAction.viewProfile) {
                    widget.onViewProfile();
                    return;
                  }
                  widget.onReport();
                },
                itemBuilder: (context) => [
                  PopupMenuItem<_ChatHeaderMenuAction>(
                    value: _ChatHeaderMenuAction.viewProfile,
                    child: Text(
                      'Voir le profil',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  PopupMenuItem<_ChatHeaderMenuAction>(
                    value: _ChatHeaderMenuAction.report,
                    child: Text(
                      'Signaler',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Icon(
                    Icons.more_vert,
                    color: Colors.white.withValues(alpha: 0.94),
                    size: 23,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChatPatternBackground extends StatelessWidget {
  const _ChatPatternBackground();

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).appColors;

    return ColoredBox(color: appColors.backgroundBase);
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
  final _ChatMessageKind kind;
  final String time;
  final bool isMine;
  final _ChatMessageDeliveryState? deliveryState;
  final _ChatMessageReply? reply;
  final _ChatMessageMedia? media;
  final _ChatMessageProduct? product;

  const _ChatMessage({
    this.id,
    required this.message,
    this.kind = _ChatMessageKind.text,
    required this.time,
    required this.isMine,
    this.deliveryState,
    this.reply,
    this.media,
    this.product,
  });
}

class _ChatDisplayMessage {
  final List<_ChatMessage> messages;

  const _ChatDisplayMessage({required this.messages})
    : assert(messages.length > 0);

  _ChatMessage get anchorMessage => messages.last;

  String? get groupId {
    final value = messages.first.media?.mediaGroupId?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  List<_ChatMessageMedia> get mediaItems => messages
      .map((message) => message.media)
      .whereType<_ChatMessageMedia>()
      .toList(growable: false);

  String get messageText {
    if (messages.length == 1) {
      return anchorMessage.message;
    }

    final normalizedMessages = messages
        .map((message) => message.message.trim())
        .where((message) => message.isNotEmpty)
        .toSet();
    if (normalizedMessages.length != 1) {
      return '';
    }

    final message = normalizedMessages.first;
    if (message == 'Photo envoyee' || message == 'Document envoye') {
      return '';
    }

    return message;
  }
}

enum _ChatMessageKind {
  text,
  image,
  document,
  product;

  static _ChatMessageKind fromApi(dynamic value) {
    final normalized = value?.toString().trim().toUpperCase() ?? '';
    switch (normalized) {
      case 'IMAGE':
        return _ChatMessageKind.image;
      case 'DOCUMENT':
        return _ChatMessageKind.document;
      case 'PRODUCT':
        return _ChatMessageKind.product;
      default:
        return _ChatMessageKind.text;
    }
  }
}

enum _ChatMessageDeliveryState { sending, sent, seen }

class _ChatMessageReply {
  final String? messageId;
  final String senderLabel;
  final String content;

  const _ChatMessageReply({
    required this.messageId,
    required this.senderLabel,
    required this.content,
  });

  static _ChatMessageReply? fromApi(dynamic value) {
    if (value is! Map) {
      return null;
    }

    final senderLabel = (value['senderLabel'] as String? ?? '').trim();
    final content = (value['content'] as String? ?? '').trim();
    final messageId = value['messageId']?.toString().trim();

    if (senderLabel.isEmpty && content.isEmpty) {
      return null;
    }

    return _ChatMessageReply(
      messageId: messageId,
      senderLabel: senderLabel.isNotEmpty ? senderLabel : 'Message',
      content: content,
    );
  }
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

class _ChatMessageMedia {
  final String mediaType;
  final String publicUrl;
  final String? previewUrl;
  final String? thumbnailUrl;
  final String? fileName;
  final String? mimeType;
  final int? fileSizeBytes;
  final String? mediaGroupId;
  final int? width;
  final int? height;
  final String storageProvider;
  final String? storageKey;

  const _ChatMessageMedia({
    required this.mediaType,
    required this.publicUrl,
    this.previewUrl,
    this.thumbnailUrl,
    this.fileName,
    this.mimeType,
    this.fileSizeBytes,
    this.mediaGroupId,
    this.width,
    this.height,
    required this.storageProvider,
    this.storageKey,
  });

  static _ChatMessageMedia? fromApi(dynamic value) {
    if (value is! Map) {
      return null;
    }

    final mediaType = value['mediaType']?.toString().trim().toLowerCase() ?? '';
    final publicUrl = value['publicUrl']?.toString().trim() ?? '';
    if (mediaType.isEmpty || publicUrl.isEmpty) {
      return null;
    }

    return _ChatMessageMedia(
      mediaType: mediaType,
      publicUrl: publicUrl,
      previewUrl: value['previewUrl']?.toString().trim(),
      thumbnailUrl: value['thumbnailUrl']?.toString().trim(),
      fileName: value['fileName']?.toString().trim(),
      mimeType: value['mimeType']?.toString().trim(),
      fileSizeBytes: value['fileSizeBytes'] is int
          ? value['fileSizeBytes'] as int
          : int.tryParse(value['fileSizeBytes']?.toString() ?? ''),
      mediaGroupId: value['mediaGroupId']?.toString().trim(),
      width: value['width'] is int
          ? value['width'] as int
          : int.tryParse(value['width']?.toString() ?? ''),
      height: value['height'] is int
          ? value['height'] as int
          : int.tryParse(value['height']?.toString() ?? ''),
      storageProvider:
          value['storageProvider']?.toString().trim().isNotEmpty == true
          ? value['storageProvider']!.toString().trim()
          : 'cloudinary',
      storageKey: value['storageKey']?.toString().trim(),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String message;
  final _ChatMessageKind kind;
  final String time;
  final bool isMine;
  final _ChatMessageDeliveryState? deliveryState;
  final _ChatMessageReply? reply;
  final bool isHighlighted;
  final VoidCallback? onReplyTap;
  final List<_ChatMessageMedia> mediaItems;
  final ValueChanged<int>? onMediaTapAtIndex;
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
    this.kind = _ChatMessageKind.text,
    required this.time,
    required this.isMine,
    this.deliveryState,
    this.reply,
    this.isHighlighted = false,
    this.onReplyTap,
    this.mediaItems = const <_ChatMessageMedia>[],
    this.onMediaTapAtIndex,
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
    final delivery = _ChatDeliveryPresentation.fromState(
      deliveryState,
      primary,
      metaColor,
    );

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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              decoration: BoxDecoration(
                color: bubbleColor,
                border: isHighlighted
                    ? Border.all(
                        color: primary.withValues(alpha: 0.9),
                        width: 1.4,
                      )
                    : null,
                boxShadow: isHighlighted
                    ? [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.24),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
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
                  if (reply != null) ...[
                    _MessageReplyCard(
                      primary: primary,
                      senderLabel: reply!.senderLabel,
                      content: reply!.content,
                      isMine: isMine,
                      subtleText: metaColor,
                      onTap: onReplyTap,
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (mediaItems.isNotEmpty && onMediaTapAtIndex != null) ...[
                    mediaItems.length == 1
                        ? _InlineChatMediaCard(
                            media: mediaItems.first,
                            isMine: isMine,
                            primary: primary,
                            cardColor: incomingBubbleColor,
                            subtleText: metaColor,
                            imageUrl: mediaItems.first.mediaType == 'image'
                                ? CloudinaryImageUrl.forChatThumbnail(
                                    mediaItems.first.thumbnailUrl
                                                ?.trim()
                                                .isNotEmpty ==
                                            true
                                        ? mediaItems.first.thumbnailUrl!.trim()
                                        : mediaItems.first.previewUrl
                                                  ?.trim()
                                                  .isNotEmpty ==
                                              true
                                        ? mediaItems.first.previewUrl!.trim()
                                        : mediaItems.first.publicUrl,
                                  )
                                : null,
                            onTap: () => onMediaTapAtIndex!(0),
                          )
                        : _InlineChatMediaGroupCard(
                            mediaItems: mediaItems,
                            isMine: isMine,
                            primary: primary,
                            cardColor: incomingBubbleColor,
                            subtleText: metaColor,
                            onTapAtIndex: onMediaTapAtIndex!,
                          ),
                    if (message.trim().isNotEmpty) const SizedBox(height: 10),
                  ],
                  if (product != null && onProductTap != null) ...[
                    _InlineProductSnapshotCard(
                      product: product!,
                      isMine: isMine,
                      primary: primary,
                      cardColor: incomingBubbleColor,
                      subtleText: metaColor,
                      onTap: onProductTap,
                    ),
                    if (message.trim().isNotEmpty) const SizedBox(height: 10),
                  ],
                  if (message.trim().isNotEmpty)
                    Text(
                      message,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  if (message.trim().isNotEmpty) const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          color: const Color.fromARGB(113, 192, 192, 192),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isMine && delivery != null) ...[
                        const SizedBox(width: 4),
                        Icon(delivery.icon, size: 15, color: delivery.color),
                        const SizedBox(width: 4),
                        Text(
                          delivery.label,
                          style: TextStyle(
                            color: delivery.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
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

class _AttachmentUploadProgressCard extends StatelessWidget {
  final String label;
  final String statusLabel;
  final int progressPercent;
  final Color primary;
  final Color cardColor;
  final Color subtleText;

  const _AttachmentUploadProgressCard({
    required this.label,
    required this.statusLabel,
    required this.progressPercent,
    required this.primary,
    required this.cardColor,
    required this.subtleText,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedPercent = progressPercent.clamp(1, 100);
    final normalizedProgress = normalizedPercent / 100;
    final percentLabel = '$normalizedPercent%';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_upload_outlined, color: primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Envoi de $label',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.96),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                percentLabel,
                style: TextStyle(
                  color: subtleText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            statusLabel,
            style: TextStyle(
              color: subtleText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: normalizedProgress,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation<Color>(primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatDeliveryPresentation {
  final String label;
  final IconData icon;
  final Color color;

  const _ChatDeliveryPresentation({
    required this.label,
    required this.icon,
    required this.color,
  });

  static _ChatDeliveryPresentation? fromState(
    _ChatMessageDeliveryState? state,
    Color primary,
    Color fallbackColor,
  ) {
    switch (state) {
      case _ChatMessageDeliveryState.sending:
        return _ChatDeliveryPresentation(
          label: 'Envoi...',
          icon: Icons.schedule_rounded,
          color: fallbackColor,
        );
      case _ChatMessageDeliveryState.sent:
        return _ChatDeliveryPresentation(
          label: 'Envoye',
          icon: Icons.done_rounded,
          color: fallbackColor,
        );
      case _ChatMessageDeliveryState.seen:
        return _ChatDeliveryPresentation(
          label: 'Vu',
          icon: Icons.done_all_rounded,
          color: primary,
        );
      case null:
        return null;
    }
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
    if (_isPhotoAttachmentProduct(product)) {
      return _InlineChatPhotoCard(
        product: product,
        isMine: isMine,
        primary: primary,
        cardColor: cardColor,
        subtleText: subtleText,
        onTap: onTap,
      );
    }

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

  bool _isPhotoAttachmentProduct(_ChatMessageProduct product) {
    final id = product.id?.trim() ?? '';
    return id.startsWith(_photoAttachmentIdPrefix) &&
        product.imageUrl.isNotEmpty;
  }
}

class _InlineChatMediaCard extends StatelessWidget {
  final _ChatMessageMedia media;
  final bool isMine;
  final Color primary;
  final Color cardColor;
  final Color subtleText;
  final VoidCallback? onTap;
  final String? imageUrl;

  const _InlineChatMediaCard({
    required this.media,
    required this.isMine,
    required this.primary,
    required this.cardColor,
    required this.subtleText,
    this.imageUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (media.mediaType == 'image') {
      return _InlineChatMediaImageCard(
        media: media,
        isMine: isMine,
        primary: primary,
        cardColor: cardColor,
        subtleText: subtleText,
        imageUrl: imageUrl ?? media.publicUrl,
        onTap: onTap,
      );
    }

    return _InlineChatDocumentCard(
      media: media,
      isMine: isMine,
      primary: primary,
      subtleText: subtleText,
      onTap: onTap,
    );
  }
}

class _InlineChatMediaGroupCard extends StatelessWidget {
  final List<_ChatMessageMedia> mediaItems;
  final bool isMine;
  final Color primary;
  final Color cardColor;
  final Color subtleText;
  final ValueChanged<int> onTapAtIndex;

  const _InlineChatMediaGroupCard({
    required this.mediaItems,
    required this.isMine,
    required this.primary,
    required this.cardColor,
    required this.subtleText,
    required this.onTapAtIndex,
  });

  String _resolveImageUrl(_ChatMessageMedia media) {
    final thumbnailUrl = media.thumbnailUrl?.trim() ?? '';
    if (thumbnailUrl.isNotEmpty) {
      return thumbnailUrl;
    }

    final previewUrl = media.previewUrl?.trim() ?? '';
    if (previewUrl.isNotEmpty) {
      return CloudinaryImageUrl.forChatThumbnail(previewUrl);
    }

    return CloudinaryImageUrl.forChatThumbnail(media.publicUrl);
  }

  @override
  Widget build(BuildContext context) {
    final allImages = mediaItems.every((media) => media.mediaType == 'image');
    if (allImages) {
      final visibleItems = mediaItems.take(4).toList(growable: false);
      final hiddenCount = mediaItems.length - visibleItems.length;
      final borderColor = isMine
          ? primary.withValues(alpha: 0.28)
          : Theme.of(context).appColors.inputBorder;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
        ),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visibleItems.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final media = visibleItems[index];
            final showOverlay =
                index == visibleItems.length - 1 && hiddenCount > 0;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onTapAtIndex(index),
                borderRadius: BorderRadius.circular(14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ChatMediaCachedImage(
                        imageUrl: _resolveImageUrl(media),
                        fit: BoxFit.cover,
                      ),
                      if (showOverlay)
                        Container(
                          color: Colors.black.withValues(alpha: 0.56),
                          alignment: Alignment.center,
                          child: Text(
                            '+$hiddenCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    final visibleItems = mediaItems.take(4).toList(growable: false);
    final hiddenCount = mediaItems.length - visibleItems.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < visibleItems.length; index++) ...[
          _InlineChatDocumentCard(
            media: visibleItems[index],
            isMine: isMine,
            primary: primary,
            subtleText: subtleText,
            onTap: () => onTapAtIndex(index),
          ),
          if (index < visibleItems.length - 1) const SizedBox(height: 6),
        ],
        if (hiddenCount > 0) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '+$hiddenCount autres fichiers',
                style: TextStyle(
                  color: subtleText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _InlineChatMediaImageCard extends StatelessWidget {
  final _ChatMessageMedia media;
  final bool isMine;
  final Color primary;
  final Color cardColor;
  final Color subtleText;
  final VoidCallback? onTap;
  final String imageUrl;

  const _InlineChatMediaImageCard({
    required this.media,
    required this.isMine,
    required this.primary,
    required this.cardColor,
    required this.subtleText,
    required this.imageUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isMine
        ? primary.withValues(alpha: 0.28)
        : Theme.of(context).appColors.inputBorder;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(17),
                  bottom: Radius.circular(16),
                ),
                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ChatMediaCachedImage(
                        imageUrl: imageUrl,
                        width: 280,
                        height: 350,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.54),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.open_in_full_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Plein ecran',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if ((media.fileName ?? '').trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Text(
                    media.fileName!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: subtleText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineChatDocumentCard extends StatelessWidget {
  final _ChatMessageMedia media;
  final bool isMine;
  final Color primary;
  final Color subtleText;
  final VoidCallback? onTap;

  const _InlineChatDocumentCard({
    required this.media,
    required this.isMine,
    required this.primary,
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.description_rounded,
                  color: primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (media.fileName ?? 'Document').trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    if ((media.mimeType ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        media.mimeType!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: subtleText,
                          fontWeight: FontWeight.w600,
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

class _InlineChatPhotoCard extends StatelessWidget {
  final _ChatMessageProduct product;
  final bool isMine;
  final Color primary;
  final Color cardColor;
  final Color subtleText;
  final VoidCallback? onTap;

  const _InlineChatPhotoCard({
    required this.product,
    required this.isMine,
    required this.primary,
    required this.cardColor,
    required this.subtleText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isMine
        ? primary.withValues(alpha: 0.28)
        : Theme.of(context).appColors.inputBorder;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(17),
                  bottom: Radius.circular(16),
                ),
                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppNetworkImage(
                        imageUrl: product.imageUrl,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.54),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.open_in_full_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Plein ecran',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (product.subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Text(
                    product.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: subtleText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
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

class _SwipeReplyWrapper extends StatefulWidget {
  final bool isMine;
  final Color primary;
  final VoidCallback onReply;
  final Widget child;

  const _SwipeReplyWrapper({
    required this.isMine,
    required this.primary,
    required this.onReply,
    required this.child,
  });

  @override
  State<_SwipeReplyWrapper> createState() => _SwipeReplyWrapperState();
}

class _MessageReplyCard extends StatelessWidget {
  final Color primary;
  final String senderLabel;
  final String content;
  final bool isMine;
  final Color subtleText;
  final VoidCallback? onTap;

  const _MessageReplyCard({
    required this.primary,
    required this.senderLabel,
    required this.content,
    required this.isMine,
    required this.subtleText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isMine
        ? Colors.white.withValues(alpha: 0.09)
        : primary.withValues(alpha: 0.08);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 34,
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      senderLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subtleText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
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
  }
}

class _SwipeReplyWrapperState extends State<_SwipeReplyWrapper> {
  static const double _triggerDistance = 56;
  static const double _maxOffset = 72;
  double _dragOffset = 0;
  bool _triggered = false;

  void _handleDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    final nextOffset = (_dragOffset + delta).clamp(-_maxOffset, _maxOffset);

    if (widget.isMine && nextOffset > 0) {
      return;
    }

    if (!widget.isMine && nextOffset < 0) {
      return;
    }

    setState(() => _dragOffset = nextOffset);

    if (!_triggered && _dragOffset.abs() >= _triggerDistance) {
      _triggered = true;
      widget.onReply();
    }
  }

  void _resetDrag() {
    if (!mounted) {
      return;
    }

    setState(() => _dragOffset = 0);
    _triggered = false;
  }

  @override
  Widget build(BuildContext context) {
    final alignment = widget.isMine
        ? Alignment.centerLeft
        : Alignment.centerRight;
    final showIcon = _dragOffset.abs() > 12;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: (_) => _resetDrag(),
      onHorizontalDragCancel: _resetDrag,
      child: Stack(
        alignment: alignment,
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: showIcon ? 1 : 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.reply_rounded,
                  color: widget.primary,
                  size: 20,
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            transform: Matrix4.translationValues(_dragOffset, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class _ReplyComposerCard extends StatelessWidget {
  final Color primary;
  final AppThemeColors appColors;
  final String authorLabel;
  final String message;
  final VoidCallback onClose;

  const _ReplyComposerCard({
    required this.primary,
    required this.appColors,
    required this.authorLabel,
    required this.message,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: appColors.panelBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: appColors.inputBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 42,
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  authorLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: appColors.mutedText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                color: appColors.mutedText,
                size: 20,
              ),
            ),
          ),
        ],
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
