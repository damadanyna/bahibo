import 'dart:async';
import 'dart:math' as math;

import 'package:banay/component/app_network_image.dart';
import 'package:banay/component/app_page_refresh.dart';
import 'package:banay/component/app_page_skeletons.dart';
import 'package:banay/component/chat_media_cached_image.dart';
import 'package:banay/component/profile_models.dart';
import 'package:banay/component/seller_profile_page.dart';
import 'package:banay/component/ui/chat_message_input.dart';
import 'package:banay/component/user_profile_page.dart';
import 'package:banay/formatter/price_formatter.dart';
import 'package:banay/page/private_image_viewer.dart';
import 'package:banay/services/app_api_client.dart';
import 'package:banay/services/catalog_api_service.dart';
import 'package:banay/services/chat/chat_session_controller.dart';
import 'package:banay/services/chat/chat_session_state.dart';
import 'package:banay/services/chat/chat_session_target.dart';
import 'package:banay/services/chat/chat_viewport_controller.dart';
import 'package:banay/services/chat_document_upload_service.dart';
import 'package:banay/services/chat_realtime_service.dart';
import 'package:banay/services/chat_photo_upload_service.dart';
import 'package:banay/services/cloudinary_image_url.dart';
import 'package:banay/services/chat_media_cache_service.dart';
import 'package:banay/services/conversations_api_service.dart';
import 'package:banay/services/local_conversation_store.dart';
import 'package:banay/services/presence_service.dart';
import 'package:banay/services/push_notification_service.dart';
import 'package:banay/services/session_storage.dart';
import 'package:banay/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

typedef ChatProductPageBuilder =
    Widget Function(Map<String, dynamic> product, {bool openedFromChat});

enum _ChatHeaderMenuAction { viewProfile, report }

enum _ChatSelectionMenuAction { copy, edit }

const String _photoAttachmentIdPrefix = 'attachment:photo:';
const String _documentAttachmentIdPrefix = 'attachment:document:';

class ChatPage extends StatefulWidget {
  final String? conversationId;
  final String? conversationProductId;
  final String? conversationUserId;
  final VoidCallback? onCloseRequested;
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
    this.onCloseRequested,
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
  static final Map<String, _ChatPageViewState> _viewStateCache =
      <String, _ChatPageViewState>{};
  static const bool _autoSeenEnabled = true;
  static const Duration _typingStopDelay = Duration(milliseconds: 1200);
  static const int _conversationPageFetchLimit = 50;
  static const int _recentConversationMessageLimit = 50;
  static const double _olderMessagesTriggerOffset = 96;
  final ConversationsApiService _conversationsApiService =
      ConversationsApiService();
  final CatalogApiService _catalogApiService = CatalogApiService();
  final SessionStorage _sessionStorage = SessionStorage();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  final List<_ChatMessage> _pendingTextMessages = [];
  final List<_ChatMessage> _pendingMessages = [];
  final Set<String> _pendingTextMessageIdsInFlight = <String>{};
  final Set<String> _deliveredMessageIds = <String>{};
  bool _isMarkingConversationRead = false;
  List<ChatPhotoUploadTask> _photoUploadTasks = const <ChatPhotoUploadTask>[];
  List<ChatDocumentUploadTask> _documentUploadTasks =
      const <ChatDocumentUploadTask>[];
  UiChatAttachment? _pendingDocumentAttachment;
  final Set<String> _appliedCompletedUploadIds = <String>{};
  final Set<String> _selectedDisplayMessageKeys = <String>{};
  final Map<String, GlobalKey> _messageKeys = {};
  final Map<String, String> _confirmedMessageVisualKeyAliases =
      <String, String>{};
  final Map<String, _ConfirmedMessageDisplayOverride>
  _confirmedMessageDisplayOverrides =
      <String, _ConfirmedMessageDisplayOverride>{};
  late final ChatSessionController _chatSessionController;
  late final ChatViewportController _chatViewportController;
  Timer? _messageHighlightTimer;
  Timer? _typingStopTimer;
  bool _showEntrySkeleton = true;
  bool _isSendingTextMessage = false;
  bool _isParticipantTyping = false;
  bool _isTypingEventActive = false;
  bool _initialMessageHandled = false;
  bool _initialProductContextSent = false;
  bool _conversationBlocked = false;
  bool _isLoadingOlderMessages = false;
  bool _restoredConversationView = false;
  bool _hasOlderMessages = false;
  double? _pendingRestoredScrollOffset;
  String? _conversationId;
  String? _loadError;
  Map<String, dynamic>? _conversation;
  _ChatMessage? _replyingToMessage;
  _ChatMessage? _editingMessage;
  String? _highlightedMessageId;
  bool _highlightVisible = false;
  ModalRoute<dynamic>? _route;
  String? _cachedDisplayMessagesSignature;
  List<_ChatDisplayMessage> _cachedDisplayMessages =
      const <_ChatDisplayMessage>[];
  String? _cachedTimelineItemsSignature;
  List<_ChatTimelineItem> _cachedTimelineItems = const <_ChatTimelineItem>[];

  @override
  void initState() {
    super.initState();
    initializePageRefresh();
    _conversationId = widget.conversationId;
    _chatSessionController = ChatSessionController(
      target: ChatSessionTarget(
        conversationId: widget.conversationId,
        productId: widget.conversationProductId,
        userId: widget.conversationUserId,
      ),
    )..addListener(_handleChatSessionControllerChanged);
    _chatViewportController = ChatViewportController(
      scrollController: _scrollController,
    )..addListener(_handleChatViewportControllerChanged);
    if (!_usesLiveConversation) {
      _restoreConversationViewState();
    }
    final initialCachedConversation = _usesLiveConversation
        ? null
        : _restoredConversationView
        ? null
        : _peekCachedConversationData();
    if (initialCachedConversation != null) {
      _applyConversation(initialCachedConversation);
      _showEntrySkeleton = false;
      _chatViewportController.scheduleScrollToBottom();
    }
    _scrollController.addListener(_handleScroll);
    ChatPhotoUploadService.instance.addListener(_handlePhotoUploadsChanged);
    ChatDocumentUploadService.instance.addListener(
      _handleDocumentUploadsChanged,
    );
    _syncPhotoUploadTasks();
    _syncDocumentUploadTasks();

    if (_usesLiveConversation) {
      if (_restoredConversationView) {
        unawaited(
          _chatSessionController.hydrateFromStore(
            mergeRecentMessages: true,
            limit: _recentConversationMessageLimit,
          ),
        );
      }
      unawaited(_chatSessionController.bootstrap());
      _scheduleRestoreScrollOffset();
      return;
    }

    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      setState(() => _showEntrySkeleton = false);
    });
  }

  @override
  void dispose() {
    _cacheConversationViewState();
    final currentConversationId = _conversationId?.trim();
    if (currentConversationId != null && currentConversationId.isNotEmpty) {
      PushNotificationService.setVisibleConversation(null);
    }
    PushNotificationService.routeObserver.unsubscribe(this);
    _messageHighlightTimer?.cancel();
    _typingStopTimer?.cancel();
    _chatSessionController.removeListener(_handleChatSessionControllerChanged);
    _chatViewportController.removeListener(
      _handleChatViewportControllerChanged,
    );
    _chatSessionController.dispose();
    _chatViewportController.dispose();
    ChatPhotoUploadService.instance.removeListener(_handlePhotoUploadsChanged);
    ChatDocumentUploadService.instance.removeListener(
      _handleDocumentUploadsChanged,
    );
    _scrollController.removeListener(_handleScroll);
    _emitTyping(false);
    disposePageRefresh();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Future<void> onPageReload() async {
    if (_usesLiveConversation) {
      await _chatSessionController.loadConversation();
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

  void _handleChatSessionControllerChanged() {
    final nextState = _chatSessionController.state;
    final wasShowingEntrySkeleton = _showEntrySkeleton;
    final wasPinnedToBottom =
        _chatViewportController.shouldKeepViewportPinnedToBottom;
    final previousMessageCount = _messages.length;
    final previousPendingTextCount = _pendingTextMessages.length;
    final previousLastMessageId = previousMessageCount == 0
        ? null
        : _messages.last.id?.trim();
    if (!mounted) {
      _applyChatSessionState(nextState);
      return;
    }

    setState(() {
      _applyChatSessionState(nextState);
    });

    final nextLastMessageId = _messages.isEmpty
        ? null
        : _messages.last.id?.trim();
    final firstResolvedLoad =
        wasShowingEntrySkeleton && !nextState.showEntrySkeleton;
    final appendedOrReplacedAtTail =
        _messages.length != previousMessageCount ||
        _pendingTextMessages.length != previousPendingTextCount ||
        nextLastMessageId != previousLastMessageId;

    if (firstResolvedLoad && !_restoredConversationView) {
      _chatViewportController.scheduleScrollToBottom();
    } else if (wasPinnedToBottom && appendedOrReplacedAtTail) {
      _chatViewportController.scheduleBottomAnchor(
        shouldStayPinnedToBottom: true,
      );
    }

    if (appendedOrReplacedAtTail || firstResolvedLoad) {
      unawaited(_markConversationReadIfVisible());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        unawaited(_markConversationReadIfVisible());
      });
    }

    if (!_initialMessageHandled &&
        !nextState.showEntrySkeleton &&
        ((_conversationId?.trim().isNotEmpty ?? false) ||
            (widget.conversationUserId?.trim().isNotEmpty ?? false) ||
            (widget.conversationProductId?.trim().isNotEmpty ?? false))) {
      _initialMessageHandled = true;
      final initialMessage = widget.initialMessage?.trim() ?? '';
      if (initialMessage.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          unawaited(_sendMessage(initialMessage));
        });
      }
    }
  }

  void _handleChatViewportControllerChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  void _applyChatSessionState(ChatSessionState state) {
    _conversationId = state.conversationId ?? _conversationId;
    if (_route?.isCurrent ?? false) {
      _syncVisibleConversationRegistration();
    }

    final conversation = state.conversation;
    if (conversation != null) {
      final nextConversation = Map<String, dynamic>.from(conversation);
      final pagination = Map<String, dynamic>.from(
        (nextConversation['pagination'] as Map?) ?? const <String, dynamic>{},
      );
      pagination['hasOlderMessages'] = state.hasOlderMessages;
      nextConversation['pagination'] = pagination;
      nextConversation['messages'] = state.messages;
      _conversation = nextConversation;
      _messages
        ..clear()
        ..addAll(_parseConversationMessages(state.messages));
      _syncPhotoUploadTasks();
    }

    _pendingTextMessages
      ..clear()
      ..addAll(
        state.pendingTextMessages
            .map(_pendingTextMessageToChatMessage)
            .toList(growable: false),
      );
    _showEntrySkeleton = state.showEntrySkeleton;
    _isParticipantTyping = state.isParticipantTyping;
    _hasOlderMessages = state.hasOlderMessages;
    _conversationBlocked = state.conversationBlocked;
    _loadError = state.loadError;
  }

  bool _hasUnreadIncomingMessages() {
    return _messages.any(
      (message) => !message.isMine && message.createdAt != null,
    );
  }

  Future<void> _markConversationReadIfVisible() async {
    final conversationId = _conversationId?.trim() ?? '';
    if (!_autoSeenEnabled ||
        !_usesLiveConversation ||
        conversationId.isEmpty ||
        !(_route?.isCurrent ?? false) ||
        _isMarkingConversationRead ||
        !_hasUnreadIncomingMessages()) {
      return;
    }

    _isMarkingConversationRead = true;
    try {
      await _conversationsApiService.markConversationRead(
        conversationId: conversationId,
      );
    } on AppApiException {
      // Keep the current UI state; a later visible refresh can retry.
    } finally {
      _isMarkingConversationRead = false;
    }
  }

  String? _conversationViewStateKey() {
    final conversationId = widget.conversationId?.trim() ?? '';
    if (conversationId.isNotEmpty) {
      return 'id:$conversationId';
    }

    final targetUserId = widget.conversationUserId?.trim() ?? '';
    if (targetUserId.isNotEmpty) {
      return 'user:$targetUserId';
    }

    final productId = widget.conversationProductId?.trim() ?? '';
    if (productId.isNotEmpty) {
      return 'product:$productId';
    }

    final currentConversationId = _conversationId?.trim() ?? '';
    if (currentConversationId.isNotEmpty) {
      return 'id:$currentConversationId';
    }

    return null;
  }

  void _restoreConversationViewState() {
    final viewStateKey = _conversationViewStateKey();
    if (viewStateKey == null) {
      return;
    }

    final cachedState = _viewStateCache[viewStateKey];
    if (cachedState == null) {
      return;
    }

    _restoredConversationView = true;
    _pendingRestoredScrollOffset = cachedState.scrollOffset;
    _applyConversation(
      Map<String, dynamic>.from(cachedState.payload),
      clearPending: false,
    );
    _showEntrySkeleton = false;
    _loadError = null;
  }

  void _cacheConversationViewState() {
    final viewStateKey = _conversationViewStateKey();
    if (viewStateKey == null || _conversation == null) {
      return;
    }

    final payload = Map<String, dynamic>.from(_conversation!)
      ..['id'] = _conversationId ?? _conversation?['id']
      ..['messages'] = _serializeCurrentMessages()
      ..['pagination'] = <String, dynamic>{
        'limit': _messages.length,
        'hasOlderMessages': _hasOlderMessages,
        'oldestLoadedMessageId': _messages.isEmpty ? null : _messages.first.id,
      };

    final scrollOffset = _scrollController.hasClients
        ? _scrollController.offset
        : _pendingRestoredScrollOffset;
    _viewStateCache[viewStateKey] = _ChatPageViewState(
      payload: payload,
      scrollOffset: scrollOffset,
    );

    const maxCachedViews = 12;
    if (_viewStateCache.length > maxCachedViews) {
      _viewStateCache.remove(_viewStateCache.keys.first);
    }
  }

  List<Map<String, dynamic>> _serializeCurrentMessages() {
    return _messages
        .map(
          (message) => <String, dynamic>{
            if (message.id != null) 'id': message.id,
            'content': message.message,
            'kind': switch (message.kind) {
              _ChatMessageKind.image => 'IMAGE',
              _ChatMessageKind.document => 'DOCUMENT',
              _ChatMessageKind.product => 'PRODUCT',
              _ChatMessageKind.text => 'TEXT',
            },
            'createdAt': message.createdAt,
            if (message.editedAt != null) 'editedAt': message.editedAt,
            'readAt': message.deliveryState == _ChatMessageDeliveryState.seen
                ? (message.createdAt ?? DateTime.now().toIso8601String())
                : null,
            'isMine': message.isMine,
            'reply': message.reply == null
                ? null
                : <String, dynamic>{
                    'messageId': message.reply!.messageId,
                    'senderLabel': message.reply!.senderLabel,
                    'content': message.reply!.content,
                  },
            'media': message.media == null
                ? null
                : <String, dynamic>{
                    'mediaType': message.media!.mediaType,
                    'publicUrl': message.media!.publicUrl,
                    'previewUrl': message.media!.previewUrl,
                    'thumbnailUrl': message.media!.thumbnailUrl,
                    'fileName': message.media!.fileName,
                    'mimeType': message.media!.mimeType,
                    'fileSizeBytes': message.media!.fileSizeBytes,
                    'mediaGroupId': message.media!.mediaGroupId,
                    'width': message.media!.width,
                    'height': message.media!.height,
                    'storageProvider': message.media!.storageProvider,
                    'storageKey': message.media!.storageKey,
                  },
            'product': message.product == null
                ? null
                : <String, dynamic>{
                    'id': message.product!.id,
                    'title': message.product!.title,
                    'subtitle': message.product!.subtitle,
                    'priceLabel': message.product!.priceLabel,
                    'imageUrl': message.product!.imageUrl,
                  },
          },
        )
        .toList(growable: false);
  }

  void _scheduleRestoreScrollOffset({int remaining = 4}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetOffset = _pendingRestoredScrollOffset;
      if (!mounted || !_scrollController.hasClients || targetOffset == null) {
        if (remaining > 0) {
          _scheduleRestoreScrollOffset(remaining: remaining - 1);
        }
        return;
      }

      final clampedOffset = targetOffset.clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.jumpTo(clampedOffset);
      if (remaining > 0) {
        _scheduleRestoreScrollOffset(remaining: remaining - 1);
      } else {
        _pendingRestoredScrollOffset = null;
        _restoredConversationView = false;
      }
    });
  }

  void _handlePhotoUploadsChanged() {
    _syncPhotoUploadTasks();
  }

  void _handleDocumentUploadsChanged() {
    _syncDocumentUploadTasks();
  }

  void _applyCompletedUploadConversationSnapshot(
    String uploadId,
    Map<String, dynamic>? completedConversationData,
  ) {
    if (completedConversationData == null ||
        !_appliedCompletedUploadIds.add(uploadId)) {
      return;
    }

    _applyConversation(
      Map<String, dynamic>.from(completedConversationData),
      mergeRecentMessages: true,
    );
  }

  void _syncPhotoUploadTasks() {
    final matchingTasks = ChatPhotoUploadService.instance.tasksForTarget(
      conversationId: _conversationId,
      productId: widget.conversationProductId,
      targetUserId: widget.conversationUserId,
    );

    for (final task in matchingTasks) {
      _applyCompletedUploadConversationSnapshot(
        task.id,
        task.completedConversationData,
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _photoUploadTasks = matchingTasks
          .where((task) => task.isVisibleInChat)
          .toList(growable: false);
    });
  }

  void _syncDocumentUploadTasks() {
    final matchingTasks = ChatDocumentUploadService.instance.tasksForTarget(
      conversationId: _conversationId,
      productId: widget.conversationProductId,
      targetUserId: widget.conversationUserId,
    );

    for (final task in matchingTasks) {
      _applyCompletedUploadConversationSnapshot(
        task.id,
        task.completedConversationData,
      );
    }

    if (!mounted) {
      _documentUploadTasks = matchingTasks
          .where((task) => task.isVisibleInChat)
          .toList(growable: false);
      return;
    }

    setState(() {
      _documentUploadTasks = matchingTasks
          .where((task) => task.isVisibleInChat)
          .toList(growable: false);
    });
  }

  @override
  void didPush() {
    _syncVisibleConversationRegistration();
    unawaited(_markConversationReadIfVisible());
  }

  @override
  void didPopNext() {
    _syncVisibleConversationRegistration();
    unawaited(_markConversationReadIfVisible());
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

  Map<String, dynamic>? _peekCachedConversationData() {
    if (widget.conversationUserId?.isNotEmpty ?? false) {
      return _conversationsApiService.peekCachedConversationForUser(
        widget.conversationUserId!,
      );
    }
    if (_conversationId != null) {
      return _conversationsApiService.peekCachedConversationById(
        _conversationId!,
      );
    }
    if (widget.conversationProductId?.isNotEmpty ?? false) {
      return _conversationsApiService.peekCachedConversationForProduct(
        widget.conversationProductId!,
      );
    }
    return null;
  }

  Future<void> _hydrateConversationFromLocalStore({
    bool mergeRecentMessages = false,
    bool prependOlderMessages = false,
    int? limit,
    String? beforeMessageId,
  }) async {
    final data = await _chatSessionController.fetchStoredConversationWindow(
      limit: limit,
      beforeMessageId: beforeMessageId,
    );
    if (data == null || !mounted) {
      return;
    }

    setState(() {
      _applyConversation(
        data,
        mergeRecentMessages: mergeRecentMessages,
        prependOlderMessages: prependOlderMessages,
        clearPending: false,
      );
      _showEntrySkeleton = false;
      _loadError = null;
    });
  }

  _ChatMessage _pendingTextMessageToChatMessage(
    LocalPendingTextMessage pendingMessage,
  ) {
    final createdAt = pendingMessage.createdAt.toIso8601String();
    final replyPayload = pendingMessage.replyPayload;
    final replyContent =
        replyPayload?['replyToContent']?.toString().trim() ?? '';
    final replySenderName =
        replyPayload?['replyToSenderName']?.toString().trim() ?? '';
    return _ChatMessage(
      id: pendingMessage.id,
      message: pendingMessage.content,
      createdAt: createdAt,
      time: _formatMessageTime(createdAt),
      isMine: true,
      deliveryState: _deliveryStateForPendingTextMessage(pendingMessage),
      reply: replyContent.isEmpty && replySenderName.isEmpty
          ? null
          : _ChatMessageReply(
              messageId: replyPayload?['replyToMessageId']?.toString().trim(),
              senderLabel: replySenderName.isEmpty
                  ? 'Message'
                  : replySenderName,
              content: replyContent,
            ),
    );
  }

  _ChatMessageDeliveryState _deliveryStateForPendingTextMessage(
    LocalPendingTextMessage pendingMessage,
  ) {
    switch (pendingMessage.status) {
      case LocalPendingTextMessageStatus.sending:
      case LocalPendingTextMessageStatus.queued:
      case LocalPendingTextMessageStatus.failed:
        return _ChatMessageDeliveryState.sending;
    }
  }

  Future<bool> _sendPendingTextMessageById(
    String pendingMessageId, {
    bool showFailureSnackBar = true,
  }) async {
    if (!_pendingTextMessageIdsInFlight.add(pendingMessageId)) {
      return true;
    }

    try {
      final shouldStayPinnedToBottom =
          _chatViewportController.shouldKeepViewportPinnedToBottom;
      final result = await _chatSessionController.sendPendingTextMessageById(
        pendingMessageId,
      );
      if (!mounted) {
        return result.succeeded;
      }

      if (!result.succeeded) {
        if (showFailureSnackBar &&
            (result.errorMessage?.trim().isNotEmpty ?? false)) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(result.errorMessage!)));
        }
        return false;
      }

      _chatViewportController.scheduleBottomAnchor(
        shouldStayPinnedToBottom: shouldStayPinnedToBottom,
      );
      return true;
    } finally {
      _pendingTextMessageIdsInFlight.remove(pendingMessageId);
    }
  }

  void _handleScroll() {
    _chatViewportController.handleScroll();

    if (!_scrollController.hasClients) {
      return;
    }

    final offset = _scrollController.offset;

    if (!_usesLiveConversation ||
        _isLoadingOlderMessages ||
        !_hasOlderMessages) {
      return;
    }

    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    if (offset >= maxScrollExtent - _olderMessagesTriggerOffset) {
      unawaited(_loadOlderMessages());
    }
  }

  Future<void> _loadOlderMessages() async {
    final oldestLoadedMessageId = _messages.isEmpty ? null : _messages.first.id;
    if (oldestLoadedMessageId == null || oldestLoadedMessageId.isEmpty) {
      if (mounted) {
        setState(() => _hasOlderMessages = false);
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoadingOlderMessages = true);
    }

    try {
      final data = await _chatSessionController.fetchConversationDisplayWindow(
        targetDisplayCount: _conversationPageFetchLimit,
        beforeMessageId: oldestLoadedMessageId,
      );
      await _hydrateConversationFromLocalStore(
        prependOlderMessages: true,
        limit: _conversationPageFetchLimit,
        beforeMessageId: oldestLoadedMessageId,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _applyConversation(
          data,
          prependOlderMessages: true,
          clearPending: false,
        );
      });
      unawaited(_prefetchBatchFromRaw(data['messages']));
    } on AppApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _isLoadingOlderMessages = false);
      }
    }
  }

  void _applyConversation(
    Map<String, dynamic> data, {
    bool mergeRecentMessages = false,
    bool prependOlderMessages = false,
    bool clearPending = true,
  }) {
    _conversationId = data['id']?.toString() ?? _conversationId;
    if (_route?.isCurrent ?? false) {
      _syncVisibleConversationRegistration();
    }
    _conversation = Map<String, dynamic>.from(data);
    final rawMessages = (data['messages'] as List?) ?? const [];
    final nextMessages = _parseConversationMessages(rawMessages);
    if (mergeRecentMessages || prependOlderMessages) {
      _mergeMessagesInPlace(nextMessages);
    } else {
      _messages
        ..clear()
        ..addAll(nextMessages);
    }
    if (clearPending) {
      _pendingMessages.clear();
    }
    final pagination = data['pagination'];
    if (pagination is Map) {
      final nextHasOlderMessages = pagination['hasOlderMessages'] == true;
      if (prependOlderMessages) {
        _hasOlderMessages = nextHasOlderMessages;
      } else if (mergeRecentMessages) {
        _hasOlderMessages = _hasOlderMessages || nextHasOlderMessages;
      } else {
        _hasOlderMessages = nextHasOlderMessages;
      }
    } else if (!mergeRecentMessages && !prependOlderMessages) {
      _hasOlderMessages = false;
    }
    _syncPhotoUploadTasks();
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

  List<_ChatMessage> _parseConversationMessages(List rawMessages) {
    return rawMessages
        .whereType<Map>()
        .map((message) {
          final messageId = message['id']?.toString();
          final createdAt = message['createdAt'] as String?;
          final deliveredAt = message['deliveredAt']?.toString().trim() ?? '';
          if (deliveredAt.isNotEmpty &&
              (messageId?.trim().isNotEmpty ?? false)) {
            _deliveredMessageIds.add(messageId!.trim());
          }
          return _ChatMessage(
            id: messageId,
            message: (message['content'] as String?) ?? '',
            kind: _ChatMessageKind.fromApi(message['kind']),
            createdAt: createdAt,
            editedAt: message['editedAt'] as String?,
            time: _formatMessageTime(createdAt),
            isMine: message['isMine'] == true,
            deliveryState: _resolveDeliveryState(
              messageId: messageId,
              isMine: message['isMine'] == true,
              readAt: message['readAt'] as String?,
            ),
            reply: _ChatMessageReply.fromApi(message['reply']),
            media: _ChatMessageMedia.fromApi(message['media']),
            product: _ChatMessageProduct.fromApi(message['product']),
          );
        })
        .toList(growable: false);
  }

  void _mergeMessagesInPlace(List<_ChatMessage> incomingMessages) {
    final mergedById = <String, _ChatMessage>{
      for (var index = 0; index < _messages.length; index += 1)
        _chatMessageKey(_messages[index], index): _messages[index],
    };

    for (var index = 0; index < incomingMessages.length; index += 1) {
      final message = incomingMessages[index];
      mergedById[_chatMessageKey(message, index)] = message;
    }

    final merged = mergedById.values.toList(growable: false)
      ..sort(_compareChatMessages);
    _messages
      ..clear()
      ..addAll(merged);
  }

  List<_ChatMessage> _messagesForDisplay() {
    final confirmedMessages = _messages
        .map(_applyConfirmedMessageDisplayOverride)
        .toList(growable: false);
    final unmatchedConfirmedIndexes = <int>{
      for (var index = 0; index < confirmedMessages.length; index += 1) index,
    };
    final visiblePendingTextMessages = <_ChatMessage>[];
    final nextConfirmedVisualKeyAliases = <String, String>{};
    final nextConfirmedDisplayOverrides =
        <String, _ConfirmedMessageDisplayOverride>{};

    for (final pendingMessage in _pendingTextMessages) {
      final matchingConfirmedIndex = _findMatchingConfirmedMessageIndex(
        pendingMessage,
        confirmedMessages,
        unmatchedConfirmedIndexes,
      );
      if (matchingConfirmedIndex != null) {
        unmatchedConfirmedIndexes.remove(matchingConfirmedIndex);
        final confirmedMessage = confirmedMessages[matchingConfirmedIndex];
        final confirmedMessageId = confirmedMessage.id?.trim() ?? '';
        final pendingMessageId = pendingMessage.id?.trim() ?? '';
        if (confirmedMessageId.isNotEmpty && pendingMessageId.isNotEmpty) {
          nextConfirmedVisualKeyAliases[confirmedMessageId] = pendingMessageId;
          final displayOverride = _ConfirmedMessageDisplayOverride(
            createdAt: pendingMessage.createdAt,
            time: pendingMessage.time,
          );
          nextConfirmedDisplayOverrides[confirmedMessageId] = displayOverride;
          confirmedMessages[matchingConfirmedIndex] =
              _applyDisplayOverrideToMessage(confirmedMessage, displayOverride);
        }
        continue;
      }

      visiblePendingTextMessages.add(pendingMessage);
    }

    final activeConfirmedMessageIds = confirmedMessages
        .map((message) => message.id?.trim() ?? '')
        .where((messageId) => messageId.isNotEmpty)
        .toSet();
    _confirmedMessageVisualKeyAliases
      ..removeWhere(
        (confirmedMessageId, visualKey) =>
            !activeConfirmedMessageIds.contains(confirmedMessageId),
      )
      ..addAll(nextConfirmedVisualKeyAliases);
    _confirmedMessageDisplayOverrides
      ..removeWhere(
        (confirmedMessageId, displayOverride) =>
            !activeConfirmedMessageIds.contains(confirmedMessageId),
      )
      ..addAll(nextConfirmedDisplayOverrides);

    return <_ChatMessage>[
      ...confirmedMessages,
      ...visiblePendingTextMessages,
      ..._pendingMessages,
    ]..sort(_compareChatMessages);
  }

  _ChatMessage _applyConfirmedMessageDisplayOverride(_ChatMessage message) {
    final messageId = message.id?.trim() ?? '';
    if (messageId.isEmpty) {
      return message;
    }

    final displayOverride = _confirmedMessageDisplayOverrides[messageId];
    if (displayOverride == null) {
      return message;
    }

    return _applyDisplayOverrideToMessage(message, displayOverride);
  }

  _ChatMessage _applyDisplayOverrideToMessage(
    _ChatMessage message,
    _ConfirmedMessageDisplayOverride displayOverride,
  ) {
    return _ChatMessage(
      id: message.id,
      message: message.message,
      kind: message.kind,
      createdAt: displayOverride.createdAt ?? message.createdAt,
      editedAt: message.editedAt,
      time: displayOverride.time.isNotEmpty
          ? displayOverride.time
          : message.time,
      isMine: message.isMine,
      deliveryState: message.deliveryState,
      reply: message.reply,
      media: message.media,
      product: message.product,
    );
  }

  int? _findMatchingConfirmedMessageIndex(
    _ChatMessage pendingMessage,
    List<_ChatMessage> confirmedMessages,
    Set<int> unmatchedConfirmedIndexes,
  ) {
    final pendingContent = pendingMessage.message.trim();
    if (!pendingMessage.isMine ||
        pendingMessage.kind != _ChatMessageKind.text ||
        pendingContent.isEmpty) {
      return null;
    }

    final pendingCreatedAt = DateTime.tryParse(pendingMessage.createdAt ?? '');
    int? bestIndex;
    Duration? bestDistance;

    for (final index in unmatchedConfirmedIndexes) {
      final confirmedMessage = confirmedMessages[index];
      if (!_messagesMatchForDisplay(pendingMessage, confirmedMessage)) {
        continue;
      }

      final confirmedCreatedAt = DateTime.tryParse(
        confirmedMessage.createdAt ?? '',
      );
      final distance = pendingCreatedAt == null || confirmedCreatedAt == null
          ? Duration.zero
          : confirmedCreatedAt.difference(pendingCreatedAt).abs();
      if (distance > const Duration(seconds: 30)) {
        continue;
      }

      if (bestDistance == null || distance < bestDistance) {
        bestIndex = index;
        bestDistance = distance;
      }
    }

    return bestIndex;
  }

  bool _messagesMatchForDisplay(
    _ChatMessage pendingMessage,
    _ChatMessage confirmedMessage,
  ) {
    if (!confirmedMessage.isMine ||
        confirmedMessage.kind != pendingMessage.kind ||
        confirmedMessage.message.trim() != pendingMessage.message.trim()) {
      return false;
    }

    final pendingReply = pendingMessage.reply;
    final confirmedReply = confirmedMessage.reply;
    if ((pendingReply == null) != (confirmedReply == null)) {
      return false;
    }
    if (pendingReply != null && confirmedReply != null) {
      if (pendingReply.messageId != confirmedReply.messageId ||
          pendingReply.senderLabel != confirmedReply.senderLabel ||
          pendingReply.content != confirmedReply.content) {
        return false;
      }
    }

    return true;
  }

  String _chatMessageKey(_ChatMessage message, int index) {
    final id = message.id?.trim() ?? '';
    if (id.isNotEmpty) {
      return id;
    }

    return [
      index.toString(),
      message.createdAt ?? '',
      message.kind.name,
      message.message,
      message.isMine ? '1' : '0',
    ].join('|');
  }

  int _compareChatMessages(_ChatMessage first, _ChatMessage second) {
    final firstDate =
        DateTime.tryParse(first.createdAt ?? '')?.millisecondsSinceEpoch ?? 0;
    final secondDate =
        DateTime.tryParse(second.createdAt ?? '')?.millisecondsSinceEpoch ?? 0;
    final dateComparison = firstDate.compareTo(secondDate);
    if (dateComparison != 0) {
      return dateComparison;
    }

    return (first.id ?? '').compareTo(second.id ?? '');
  }

  DateTime? _displayMessageDate(_ChatDisplayMessage displayMessage) {
    final createdAt =
        displayMessage.anchorMessage.createdAt ??
        displayMessage.messages.first.createdAt;
    return createdAt == null ? null : DateTime.tryParse(createdAt)?.toLocal();
  }

  bool _isSameCalendarDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  String _formatDateDivider(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final difference = today.difference(target).inDays;
    if (difference == 0) {
      return 'Aujourd\'hui';
    }
    if (difference == 1) {
      return 'Hier';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  String _messageTransferPayload(_ChatDisplayMessage displayMessage) {
    final messageText = displayMessage.messageText.trim();
    if (messageText.isNotEmpty) {
      return messageText;
    }

    if (displayMessage.mediaItems.isNotEmpty) {
      return displayMessage.mediaItems
          .map((media) {
            final fileName = media.fileName?.trim() ?? '';
            final publicUrl = media.publicUrl.trim();
            if (fileName.isNotEmpty && publicUrl.isNotEmpty) {
              return '$fileName\n$publicUrl';
            }
            if (publicUrl.isNotEmpty) {
              return publicUrl;
            }
            return fileName.isNotEmpty ? fileName : 'Media';
          })
          .join('\n\n');
    }

    final product = displayMessage.anchorMessage.product;
    if (product != null) {
      return [
        product.title,
        product.subtitle,
        product.priceLabel,
      ].where((value) => value.trim().isNotEmpty).join('\n');
    }

    return 'Message';
  }

  bool get _isSelectionMode => _selectedDisplayMessageKeys.isNotEmpty;

  String _displayMessageSelectionKey(_ChatDisplayMessage displayMessage) {
    return _displayMessageReplyKey(displayMessage);
  }

  bool _canDeleteDisplayMessage(_ChatDisplayMessage displayMessage) {
    return _canDeleteDisplayMessageForScope(displayMessage, scope: 'FOR_ME');
  }

  bool _canDeleteDisplayMessageForScope(
    _ChatDisplayMessage displayMessage, {
    required String scope,
  }) {
    final normalizedScope = scope.trim().toUpperCase();
    return displayMessage.messages.any(
      (message) =>
          (message.id?.startsWith('pending-') ?? false) ||
          ((message.id?.trim().isNotEmpty ?? false) &&
              !(message.id!.startsWith('pending-')) &&
              (normalizedScope == 'FOR_ME' || message.isMine)),
    );
  }

  void _showUndeletableMessageHint() {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Le message peut etre supprime pour vous. Pour tout le monde, seuls vos messages sont autorises.',
        ),
      ),
    );
  }

  bool _canEditDisplayMessage(_ChatDisplayMessage displayMessage) {
    if (displayMessage.messages.length != 1) return false;
    final msg = displayMessage.anchorMessage;
    return msg.isMine &&
        msg.kind == _ChatMessageKind.text &&
        (msg.id?.trim().isNotEmpty ?? false);
  }

  bool _canCopyDisplayMessage(_ChatDisplayMessage displayMessage) {
    return _messageTransferPayload(displayMessage).trim().isNotEmpty;
  }

  bool _usesSelectionToolbarStatus(_ChatDisplayMessage displayMessage) {
    final state = displayMessage.anchorMessage.deliveryState;
    return state == _ChatMessageDeliveryState.sent ||
        state == _ChatMessageDeliveryState.delivered ||
        state == _ChatMessageDeliveryState.seen;
  }

  bool _canEditSelectedDisplayMessage(_ChatDisplayMessage displayMessage) {
    final state = displayMessage.anchorMessage.deliveryState;
    return _canEditDisplayMessage(displayMessage) &&
        (state == _ChatMessageDeliveryState.sent ||
            state == _ChatMessageDeliveryState.delivered);
  }

  List<_ChatSelectionMenuAction> _selectionMenuActionsFor(
    List<_ChatDisplayMessage> selectedDisplayMessages,
  ) {
    if (selectedDisplayMessages.length != 1) {
      return const <_ChatSelectionMenuAction>[];
    }

    final displayMessage = selectedDisplayMessages.single;
    if (!_usesSelectionToolbarStatus(displayMessage)) {
      return const <_ChatSelectionMenuAction>[];
    }

    return <_ChatSelectionMenuAction>[
      if (_canCopyDisplayMessage(displayMessage)) _ChatSelectionMenuAction.copy,
      if (_canEditSelectedDisplayMessage(displayMessage))
        _ChatSelectionMenuAction.edit,
    ];
  }

  Future<void> _copyDisplayMessage(_ChatDisplayMessage displayMessage) async {
    final payload = _messageTransferPayload(displayMessage).trim();
    if (payload.isEmpty) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Message copie.')));
  }

  void _handleSelectionMenuAction(
    _ChatSelectionMenuAction action,
    List<_ChatDisplayMessage> selectedDisplayMessages,
  ) {
    if (selectedDisplayMessages.length != 1) {
      return;
    }

    final displayMessage = selectedDisplayMessages.single;
    switch (action) {
      case _ChatSelectionMenuAction.copy:
        unawaited(_copyDisplayMessage(displayMessage));
        break;
      case _ChatSelectionMenuAction.edit:
        _startEditingMessage(displayMessage.anchorMessage);
        _clearSelectedMessages();
        break;
    }
  }

  String? _forwardConversationId(Map<String, dynamic> conversation) {
    final value = conversation['id'];
    if (value == null) {
      return null;
    }

    final normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  String? _forwardParticipantId(Map<String, dynamic> conversation) {
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

  String _forwardConversationName(Map<String, dynamic> conversation) {
    final participant = conversation['participant'];
    if (participant is Map) {
      final value = participant['displayName'];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return 'Conversation';
  }

  String _forwardConversationAvatar(Map<String, dynamic> conversation) {
    final participant = conversation['participant'];
    if (participant is Map) {
      final value = participant['avatarUrl'];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=600';
  }

  DateTime? _forwardConversationLastMessageDate(
    Map<String, dynamic> conversation,
  ) {
    final value = conversation['lastMessageAt'];
    if (value is! String || value.trim().isEmpty) {
      return null;
    }

    return DateTime.tryParse(value)?.toLocal();
  }

  List<Map<String, dynamic>> _groupForwardConversations(
    List<Map<String, dynamic>> conversations,
  ) {
    final grouped = <String, Map<String, dynamic>>{};

    for (final conversation in conversations) {
      final participantId = _forwardParticipantId(conversation);
      final conversationId = _forwardConversationId(conversation);
      final groupKey = participantId ?? conversationId;

      if (groupKey == null) {
        continue;
      }

      final existing = grouped[groupKey];
      if (existing == null) {
        grouped[groupKey] = Map<String, dynamic>.from(conversation);
        continue;
      }

      final existingDate = _forwardConversationLastMessageDate(existing);
      final currentDate = _forwardConversationLastMessageDate(conversation);
      final useCurrentConversation =
          existingDate == null ||
          (currentDate != null && currentDate.isAfter(existingDate));

      grouped[groupKey] = Map<String, dynamic>.from(
        useCurrentConversation ? conversation : existing,
      );
    }

    final groupedList = grouped.values.toList(growable: false);
    groupedList.sort((first, second) {
      final firstDate = _forwardConversationLastMessageDate(first);
      final secondDate = _forwardConversationLastMessageDate(second);
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

  Future<List<Map<String, dynamic>>> _loadForwardConversations() async {
    final cachedConversations = await _conversationsApiService
        .getCachedConversations();
    if (cachedConversations != null && cachedConversations.isNotEmpty) {
      return _groupForwardConversations(cachedConversations);
    }

    final conversations = await _conversationsApiService.fetchConversations();
    return _groupForwardConversations(conversations);
  }

  Future<void> _forwardMessageToConversation(
    Map<String, dynamic> conversation,
    String payload,
  ) async {
    final conversationId = _forwardConversationId(conversation);
    if (conversationId != null) {
      await _conversationsApiService.sendMessage(
        conversationId: conversationId,
        content: payload,
      );
      return;
    }

    final participantId = _forwardParticipantId(conversation);
    if (participantId != null) {
      await _conversationsApiService.sendUserMessage(
        targetUserId: participantId,
        content: payload,
      );
      return;
    }

    throw AppApiException('Conversation introuvable pour ce partage.');
  }

  Future<void> _showForwardMessagePicker(
    _ChatDisplayMessage displayMessage,
  ) async {
    final payload = _messageTransferPayload(displayMessage).trim();
    if (payload.isEmpty) {
      return;
    }

    String conversationSelectionKey(Map<String, dynamic> conversation) {
      final conversationId = _forwardConversationId(conversation);
      if (conversationId != null && conversationId.isNotEmpty) {
        return 'id:$conversationId';
      }

      final participantId = _forwardParticipantId(conversation);
      if (participantId != null && participantId.isNotEmpty) {
        return 'user:$participantId';
      }

      return conversation.hashCode.toString();
    }

    final conversationsFuture = _loadForwardConversations();
    final selectedConversations =
        await showModalBottomSheet<List<Map<String, dynamic>>>(
          context: context,
          useRootNavigator: true,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) {
            final theme = Theme.of(ctx);
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
                              'Partager avec',
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
                                final currentConversationId = _conversationId
                                    ?.trim();
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
                                    imageUrl: _forwardConversationAvatar(
                                      conversation,
                                    ),
                                    userId: _forwardParticipantId(conversation),
                                  ),
                                  title: Text(
                                    _forwardConversationName(conversation),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    _forwardConversationId(conversation) ==
                                            currentConversationId
                                        ? 'Discussion actuelle'
                                        : 'Cochez pour partager ce message',
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
                                      Navigator.of(ctx).pop(selected);
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

    if (selectedConversations == null ||
        selectedConversations.isEmpty ||
        !mounted) {
      return;
    }

    try {
      for (final conversation in selectedConversations) {
        await _forwardMessageToConversation(conversation, payload);
      }
    } on AppApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() => _selectedDisplayMessageKeys.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          selectedConversations.length == 1
              ? 'Message partage avec ${_forwardConversationName(selectedConversations.first)}.'
              : 'Message partage avec ${selectedConversations.length} discussions.',
        ),
      ),
    );
  }

  void _startEditingMessage(_ChatMessage message) {
    setState(() {
      _editingMessage = message;
      _messageController.text = message.message;
    });
  }

  void _cancelEditingMessage() {
    setState(() {
      _editingMessage = null;
      _messageController.clear();
    });
  }

  Future<String?> _askDeleteScope({required bool allowDeleteForEveryone}) {
    return showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le message'),
        content: const Text(
          'Choisissez une option de suppression. Seuls vos messages peuvent etre supprimes pour tout le monde.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('FOR_ME'),
            child: const Text('Pour moi'),
          ),
          if (allowDeleteForEveryone)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('FOR_EVERYONE'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error,
              ),
              child: const Text('Pour tout le monde'),
            ),
        ],
      ),
    );
  }

  Future<void> _submitMessageEdit(String content) async {
    final message = _editingMessage;
    if (message == null) return;
    final conversationId = _conversationId?.trim() ?? '';
    final messageId = message.id?.trim() ?? '';
    if (content.isEmpty || conversationId.isEmpty || messageId.isEmpty) return;

    final result = await _chatSessionController.submitMessageEdit(
      conversationId: conversationId,
      messageId: messageId,
      content: content,
    );
    if (!mounted) return;
    if (!result.succeeded) {
      if (result.errorMessage?.trim().isNotEmpty ?? false) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.errorMessage!)));
      }
      return;
    }

    setState(() {
      _editingMessage = null;
      _messageController.clear();
    });
  }

  void _enterSelectionMode(_ChatDisplayMessage displayMessage) {
    if (_isSystemDisplayMessage(displayMessage)) {
      return;
    }

    final selectionKey = _displayMessageSelectionKey(displayMessage);
    if (_selectedDisplayMessageKeys.contains(selectionKey)) {
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _selectedDisplayMessageKeys.add(selectionKey);
    });
    if (!_canDeleteDisplayMessage(displayMessage)) {
      _showUndeletableMessageHint();
    }
  }

  void _toggleDisplayMessageSelection(_ChatDisplayMessage displayMessage) {
    if (_isSystemDisplayMessage(displayMessage)) {
      return;
    }

    final selectionKey = _displayMessageSelectionKey(displayMessage);
    setState(() {
      if (!_selectedDisplayMessageKeys.add(selectionKey)) {
        _selectedDisplayMessageKeys.remove(selectionKey);
      }
    });
  }

  void _clearSelectedMessages() {
    if (_selectedDisplayMessageKeys.isEmpty) {
      return;
    }

    setState(() => _selectedDisplayMessageKeys.clear());
  }

  List<_ChatDisplayMessage> _selectedDisplayMessages(
    List<_ChatDisplayMessage> displayMessages,
  ) {
    if (_selectedDisplayMessageKeys.isEmpty) {
      return const <_ChatDisplayMessage>[];
    }

    return displayMessages
        .where(
          (displayMessage) => _selectedDisplayMessageKeys.contains(
            _displayMessageSelectionKey(displayMessage),
          ),
        )
        .toList(growable: false);
  }

  bool _isSystemDisplayMessage(_ChatDisplayMessage displayMessage) {
    final normalizedMessage = displayMessage.anchorMessage.message
        .trim()
        .toLowerCase();
    return normalizedMessage == 'message supprime';
  }

  _DeleteMessageBatch _buildDeleteMessageBatch(
    Iterable<_ChatDisplayMessage> displayMessages,
    String scope,
  ) {
    final pendingIds = <String>{};
    final persistedIds = <String>{};
    final allowAnyPersistedMessage = scope.trim().toUpperCase() == 'FOR_ME';

    void addGroupedPersistedMessages(String groupId) {
      final normalizedGroupId = groupId.trim();
      if (normalizedGroupId.isEmpty) {
        return;
      }

      persistedIds.addAll(
        _messages
            .where(
              (message) =>
                  (message.id?.trim().isNotEmpty ?? false) &&
                  !(message.id!.startsWith('pending-')) &&
                  (allowAnyPersistedMessage || message.isMine) &&
                  (message.media?.mediaGroupId?.trim() ?? '') ==
                      normalizedGroupId,
            )
            .map((message) => message.id!.trim()),
      );
    }

    for (final displayMessage in displayMessages) {
      final groupId = displayMessage.groupId?.trim() ?? '';
      pendingIds.addAll(
        displayMessage.messages
            .where((message) => (message.id?.startsWith('pending-') ?? false))
            .map((message) => message.id!),
      );
      persistedIds.addAll(
        displayMessage.messages
            .where(
              (message) =>
                  (message.id?.trim().isNotEmpty ?? false) &&
                  !(message.id!.startsWith('pending-')) &&
                  (allowAnyPersistedMessage || message.isMine),
            )
            .map((message) => message.id!.trim()),
      );
      addGroupedPersistedMessages(groupId);
    }

    return _DeleteMessageBatch(
      pendingIds: pendingIds.toList(growable: false),
      persistedIds: persistedIds.toList(growable: false),
    );
  }

  void _setDeleteProgress(
    ValueNotifier<_DeleteMessagesProgress> progressNotifier, {
    required int completedSteps,
    required int totalSteps,
    required String statusText,
  }) {
    progressNotifier.value = _DeleteMessagesProgress(
      completedSteps: completedSteps,
      totalSteps: totalSteps,
      statusText: statusText,
    );
  }

  Future<void> _deleteDisplayMessages(
    _DeleteMessageBatch batch,
    ValueNotifier<_DeleteMessagesProgress>? progressNotifier, {
    String scope = 'FOR_EVERYONE',
  }) async {
    final result = await _chatSessionController.deleteMessages(
      pendingIds: batch.pendingIds,
      persistedIds: batch.persistedIds,
      scope: scope,
      onProgress: (completedSteps, totalSteps, statusText) {
        final notifier = progressNotifier;
        if (notifier == null) {
          return;
        }

        _setDeleteProgress(
          notifier,
          completedSteps: completedSteps,
          totalSteps: totalSteps,
          statusText: statusText,
        );
      },
    );
    if (!result.succeeded) {
      throw AppApiException(
        result.errorMessage ?? 'Suppression impossible.',
        statusCode: result.isBlocked ? 403 : null,
      );
    }

    if (!mounted) {
      return;
    }
  }

  Future<void> _shareSelectedMessages(
    List<_ChatDisplayMessage> selectedDisplayMessages,
  ) async {
    if (selectedDisplayMessages.length != 1) {
      return;
    }

    await _showForwardMessagePicker(selectedDisplayMessages.single);
  }

  Future<void> _deleteSelectedMessages(
    List<_ChatDisplayMessage> selectedDisplayMessages,
  ) async {
    final deletableForMeMessages = selectedDisplayMessages
        .where(_canDeleteDisplayMessage)
        .toList(growable: false);
    if (deletableForMeMessages.isEmpty) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Suppression impossible pour cette selection.'),
        ),
      );
      return;
    }

    final scope = await _askDeleteScope(
      allowDeleteForEveryone: selectedDisplayMessages.every(
        (displayMessage) => _canDeleteDisplayMessageForScope(
          displayMessage,
          scope: 'FOR_EVERYONE',
        ),
      ),
    );
    if (scope == null || !mounted) return;

    final deletableMessages = selectedDisplayMessages
        .where(
          (displayMessage) =>
              _canDeleteDisplayMessageForScope(displayMessage, scope: scope),
        )
        .toList(growable: false);
    if (deletableMessages.isEmpty) {
      final errorText = scope == 'FOR_EVERYONE'
          ? 'Suppression impossible: pour tout le monde, seuls les messages que vous avez envoyes sont autorises.'
          : 'Suppression impossible pour cette selection.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorText)));
      return;
    }

    final skippedCount =
        selectedDisplayMessages.length - deletableMessages.length;
    final deleteBatch = _buildDeleteMessageBatch(deletableMessages, scope);
    final totalSteps = math.max(1, deleteBatch.totalOperations);
    final progressNotifier = ValueNotifier<_DeleteMessagesProgress>(
      _DeleteMessagesProgress(
        completedSteps: 0,
        totalSteps: totalSteps,
        statusText: deletableMessages.length == 1
            ? 'Suppression du message...'
            : 'Suppression de ${deletableMessages.length} messages...',
      ),
    );
    final rootNavigator = Navigator.of(context, rootNavigator: true);

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (dialogContext) {
          return _DeleteMessagesProgressDialog(
            progressListenable: progressNotifier,
            primary: Theme.of(dialogContext).colorScheme.primary,
          );
        },
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 20));

    try {
      await _deleteDisplayMessages(deleteBatch, progressNotifier, scope: scope);
    } on AppApiException catch (error) {
      if (rootNavigator.mounted && rootNavigator.canPop()) {
        rootNavigator.pop();
      }
      progressNotifier.dispose();
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    } catch (error) {
      if (rootNavigator.mounted && rootNavigator.canPop()) {
        rootNavigator.pop();
      }
      progressNotifier.dispose();
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Suppression impossible: $error')));
      return;
    }

    if (rootNavigator.mounted && rootNavigator.canPop()) {
      rootNavigator.pop();
    }
    progressNotifier.dispose();
    if (!mounted) {
      return;
    }

    setState(() => _selectedDisplayMessageKeys.clear());
    if (skippedCount > 0) {
      final skippedText = scope == 'FOR_EVERYONE'
          ? '$skippedCount message(s) ont ete ignores. Pour tout le monde, seuls vos propres messages peuvent etre supprimes.'
          : '$skippedCount message(s) ont ete ignores.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(skippedText)));
    }
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

  Future<void> _prefetchBatchFromRaw(dynamic rawMessages) async {
    if (rawMessages is! List) return;
    int count = 0;
    for (final raw in rawMessages) {
      if (count >= 5) break;
      if (raw is! Map) continue;
      final media = raw['media'];
      if (media is! Map) continue;
      if ((media['mediaType'] as String?) != 'image') continue;
      final url = _thumbnailUrlFromRaw(media);
      if (url.isEmpty) continue;
      await ChatMediaCacheService.instance.prefetch(url);
      count++;
    }
  }

  String _thumbnailUrlFromRaw(Map<dynamic, dynamic> media) {
    final thumbUrl = media['thumbnailUrl']?.toString().trim() ?? '';
    if (thumbUrl.isNotEmpty) return thumbUrl;
    final previewUrl = media['previewUrl']?.toString().trim() ?? '';
    if (previewUrl.isNotEmpty) {
      return CloudinaryImageUrl.forChatThumbnail(previewUrl);
    }
    final publicUrl = media['publicUrl']?.toString().trim() ?? '';
    return publicUrl.isNotEmpty
        ? CloudinaryImageUrl.forChatThumbnail(publicUrl)
        : '';
  }

  bool _isBlockedError(AppApiException error) {
    final message = error.message.toLowerCase();
    return error.statusCode == 403 && message.contains('bloqu');
  }

  _ChatMessageDeliveryState? _resolveDeliveryState({
    required String? messageId,
    required bool isMine,
    required String? readAt,
  }) {
    if (!isMine) {
      return null;
    }

    final normalizedMessageId = messageId?.trim() ?? '';
    final normalizedReadAt = readAt?.trim() ?? '';
    if (normalizedReadAt.isNotEmpty) {
      if (normalizedMessageId.isNotEmpty) {
        _deliveredMessageIds.remove(normalizedMessageId);
      }
      return _ChatMessageDeliveryState.seen;
    }

    if (normalizedMessageId.isNotEmpty &&
        _deliveredMessageIds.contains(normalizedMessageId)) {
      return _ChatMessageDeliveryState.delivered;
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
    if (_editingMessage != null) {
      await _submitMessageEdit(content);
      return;
    }
    final pendingDocumentAttachment = _pendingDocumentAttachment;
    if ((content.isEmpty && pendingDocumentAttachment == null) ||
        !_usesLiveConversation ||
        _isSendingTextMessage ||
        _conversationBlocked) {
      return;
    }

    if (mounted) {
      _isSendingTextMessage = true;
    } else {
      _isSendingTextMessage = true;
    }

    if (pendingDocumentAttachment != null) {
      final previousReplyingToMessage = _replyingToMessage;
      final replyPayload = await _replyPayload(previousReplyingToMessage);
      final pendingReply = previousReplyingToMessage == null
          ? null
          : _ChatMessageReply(
              messageId: previousReplyingToMessage.id,
              senderLabel: _replyAuthorLabel(previousReplyingToMessage),
              content: previousReplyingToMessage.message,
            );

      _typingStopTimer?.cancel();
      _emitTyping(false);
      if (mounted) {
        setState(() {
          if (identical(
            _pendingDocumentAttachment,
            pendingDocumentAttachment,
          )) {
            _pendingDocumentAttachment = null;
          }
          _replyingToMessage = null;
        });
        if (content.isNotEmpty) {
          _messageController.clear();
        }
      }

      _isSendingTextMessage = false;

      unawaited(
        _sendDocumentAttachment(
          pendingDocumentAttachment,
          messageContent: content,
          replyPayload: replyPayload,
          pendingReply: pendingReply,
        ),
      );
      return;
    }

    final previousReplyingToMessage = _replyingToMessage;
    final shouldStayPinnedToBottom =
        _chatViewportController.shouldKeepViewportPinnedToBottom;

    final shouldAttachInitialProductContext =
        widget.embedProductContextInInitialMessage &&
        !_initialProductContextSent &&
        _productTitleValue.isNotEmpty;

    final replyPayload = await _replyPayload(previousReplyingToMessage);
    final pendingMessage = await _chatSessionController
        .enqueuePendingTextMessage(
          content: content,
          replyPayload: replyPayload,
          productSnapshot:
              shouldAttachInitialProductContext &&
                  (widget.conversationUserId?.isNotEmpty ?? false)
              ? {
                  'productId': widget.conversationProductId,
                  'productTitle': _productTitleValue,
                  'productSubtitle': _productSubtitleValue,
                  'productPriceLabel': _productPriceLabelValue,
                  'productImageUrl': _productImageUrlValue,
                }
              : null,
        );

    _typingStopTimer?.cancel();
    _emitTyping(false);
    setState(() {
      _replyingToMessage = null;
    });
    _messageController.clear();
    _chatViewportController.scheduleBottomAnchor(
      shouldStayPinnedToBottom: shouldStayPinnedToBottom,
    );
    _initialProductContextSent = true;
    _showEntrySkeleton = false;
    _isSendingTextMessage = false;
    unawaited(
      _sendPendingTextMessageInBackground(
        pendingMessage.id,
        shouldStayPinnedToBottom: shouldStayPinnedToBottom,
        previousReplyingToMessage: previousReplyingToMessage,
      ),
    );
  }

  Future<void> _sendPendingTextMessageInBackground(
    String pendingMessageId, {
    required bool shouldStayPinnedToBottom,
    required _ChatMessage? previousReplyingToMessage,
  }) async {
    try {
      final sent = await _sendPendingTextMessageById(pendingMessageId);
      if (!sent || !mounted) {
        return;
      }

      _chatViewportController.scheduleBottomAnchor(
        shouldStayPinnedToBottom: shouldStayPinnedToBottom,
      );
    } on AppApiException catch (error) {
      if (!mounted) {
        return;
      }

      if (_isBlockedError(error)) {
        setState(() {
          _conversationBlocked = true;
          _loadError = error.message;
        });
      } else {
        setState(() {
          _replyingToMessage = previousReplyingToMessage;
        });
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
    final messageId = message.id?.trim() ?? '';
    if (messageId.isNotEmpty) {
      final aliasedVisualKey = _confirmedMessageVisualKeyAliases[messageId];
      if (aliasedVisualKey?.isNotEmpty ?? false) {
        return aliasedVisualKey!;
      }
      return messageId;
    }

    return '${message.time}-${message.isMine ? 'mine' : 'their'}-${message.message.hashCode}';
  }

  String _displayMessageReplyKey(_ChatDisplayMessage displayMessage) {
    if (displayMessage.groupId != null && displayMessage.groupId!.isNotEmpty) {
      return displayMessage.groupId!;
    }

    return _messageReplyKey(displayMessage.anchorMessage);
  }

  GlobalKey? _displayMessageTargetKey(
    _ChatDisplayMessage displayMessage,
    Map<String, GlobalKey> nextMessageKeys,
  ) {
    GlobalKey? key;

    for (final message in displayMessage.messages) {
      final messageId = message.id?.trim() ?? '';
      if (messageId.isEmpty) {
        continue;
      }

      key = _messageKeys[messageId];
      if (key != null) {
        break;
      }
    }

    if (key == null) {
      final hasStableMessageId = displayMessage.messages.any(
        (message) => (message.id?.trim().isNotEmpty ?? false),
      );
      if (!hasStableMessageId) {
        return null;
      }

      key = GlobalKey();
    }

    for (final message in displayMessage.messages) {
      final messageId = message.id?.trim() ?? '';
      if (messageId.isNotEmpty) {
        nextMessageKeys[messageId] = key;
      }
    }

    return key;
  }

  GlobalKey? _currentDisplayMessageTargetKey(
    _ChatDisplayMessage displayMessage,
  ) {
    for (final message in displayMessage.messages) {
      final messageId = message.id?.trim() ?? '';
      if (messageId.isEmpty) {
        continue;
      }

      final key = _messageKeys[messageId];
      if (key != null) {
        return key;
      }
    }

    return null;
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

  List<_ChatDisplayMessage> _displayMessagesForTimeline(
    List<_ChatMessage> messages,
  ) {
    final signature = _chatMessagesSignature(messages);
    if (_cachedDisplayMessagesSignature == signature) {
      return _cachedDisplayMessages;
    }

    final displayMessages = _buildDisplayMessages(messages);
    _cachedDisplayMessagesSignature = signature;
    _cachedDisplayMessages = displayMessages;
    _cachedTimelineItemsSignature = null;
    return displayMessages;
  }

  List<_ChatTimelineItem> _buildTimelineItems(
    List<_ChatDisplayMessage> displayMessages,
  ) {
    final timelineItems = <_ChatTimelineItem>[];

    if (_isLoadingOlderMessages) {
      timelineItems.add(const _ChatTimelineItem.loadingOlder());
    }

    if (_loadError != null) {
      timelineItems.add(
        _ChatTimelineItem.info(text: _loadError!, isError: true),
      );
    } else if (displayMessages.isEmpty) {
      timelineItems.add(
        const _ChatTimelineItem.info(
          text: 'Aucun message pour le moment.',
          isError: false,
        ),
      );
    } else {
      for (var index = 0; index < displayMessages.length; index += 1) {
        final displayMessage = displayMessages[index];
        final currentDate = _displayMessageDate(displayMessage);
        final previousDate = index == 0
            ? null
            : _displayMessageDate(displayMessages[index - 1]);
        final shouldShowDateDivider =
            currentDate != null &&
            (previousDate == null ||
                !_isSameCalendarDay(currentDate, previousDate));

        if (shouldShowDateDivider) {
          timelineItems.add(_ChatTimelineItem.dateDivider(date: currentDate));
        }

        timelineItems.add(
          _ChatTimelineItem.message(
            displayMessage: displayMessage,
            displayIndex: index,
            messageKeySuffix: _displayMessageReplyKey(displayMessage),
          ),
        );
      }
    }

    if (_photoUploadTasks.isNotEmpty) {
      timelineItems.add(const _ChatTimelineItem.photoUploads());
    }
    if (_documentUploadTasks.isNotEmpty) {
      timelineItems.add(const _ChatTimelineItem.documentUploads());
    }
    if (_isParticipantTyping) {
      timelineItems.add(const _ChatTimelineItem.typingIndicator());
    }

    return timelineItems;
  }

  List<_ChatTimelineItem> _timelineItemsForDisplayMessages(
    List<_ChatDisplayMessage> displayMessages,
  ) {
    final signature = _timelineItemsSignature(displayMessages);
    if (_cachedTimelineItemsSignature == signature) {
      return _cachedTimelineItems;
    }

    final timelineItems = _buildTimelineItems(displayMessages);
    _cachedTimelineItemsSignature = signature;
    _cachedTimelineItems = timelineItems;
    return timelineItems;
  }

  String _chatMessagesSignature(List<_ChatMessage> messages) {
    return messages
        .map(
          (message) => [
            message.id ?? '',
            message.createdAt ?? '',
            message.editedAt ?? '',
            message.kind.name,
            message.message,
            message.isMine ? '1' : '0',
            message.deliveryState?.name ?? '',
            message.reply?.messageId ?? '',
            message.reply?.senderLabel ?? '',
            message.reply?.content ?? '',
            message.media?.mediaGroupId ?? '',
            message.media?.publicUrl ?? '',
            message.media?.thumbnailUrl ?? '',
            message.product?.id ?? '',
          ].join('|'),
        )
        .join('||');
  }

  String _timelineItemsSignature(List<_ChatDisplayMessage> displayMessages) {
    return [
      _chatDisplayMessagesSignature(displayMessages),
      _isLoadingOlderMessages ? 'loading:1' : 'loading:0',
      'error:${_loadError ?? ''}',
      _photoUploadTasks.isNotEmpty ? 'photoUploads:1' : 'photoUploads:0',
      _documentUploadTasks.isNotEmpty
          ? 'documentUploads:1'
          : 'documentUploads:0',
      _isParticipantTyping ? 'typing:1' : 'typing:0',
    ].join('@@');
  }

  String _chatDisplayMessagesSignature(
    List<_ChatDisplayMessage> displayMessages,
  ) {
    return displayMessages
        .map(
          (displayMessage) => displayMessage.messages
              .map((message) => message.id ?? message.createdAt ?? '')
              .join(','),
        )
        .join('||');
  }

  Widget _buildTimelineItem(
    _ChatTimelineItem item, {
    required ThemeData theme,
    required Color primary,
    required Color subtleText,
    required Color incomingBubbleColor,
    required Color outgoingBubbleColor,
    required Color dateDividerCardColor,
    required String avatarUrl,
    required bool isSelectionMode,
  }) {
    switch (item.type) {
      case _ChatTimelineItemType.loadingOlder:
        return Column(
          children: [
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(primary),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Chargement des messages...',
                  style: TextStyle(
                    fontSize: 12,
                    color: subtleText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        );
      case _ChatTimelineItemType.info:
        return _ChatInfoCard(
          text: item.infoText!,
          color: item.isError ? theme.colorScheme.error : subtleText,
          cardColor: incomingBubbleColor,
        );
      case _ChatTimelineItemType.dateDivider:
        return Column(
          children: [
            _ChatDateDivider(
              label: _formatDateDivider(item.date!),
              cardColor: dateDividerCardColor,
              subtleText: subtleText,
            ),
            const SizedBox(height: 16),
          ],
        );
      case _ChatTimelineItemType.message:
        final displayMessage = item.displayMessage!;
        final chat = displayMessage.anchorMessage;
        final visualKey = _displayMessageReplyKey(displayMessage);
        final isSelected = _selectedDisplayMessageKeys.contains(
          _displayMessageSelectionKey(displayMessage),
        );

        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          color: isSelected ? const Color(0x40D32F2F) : Colors.transparent,
          child: KeyedSubtree(
            key: _currentDisplayMessageTargetKey(displayMessage),
            child: _SwipeReplyWrapper(
              isMine: chat.isMine,
              primary: primary,
              swipeEnabled: !isSelectionMode,
              onTap: isSelectionMode
                  ? () => _toggleDisplayMessageSelection(displayMessage)
                  : null,
              onReply: () => _setReplyingToMessage(chat),
              onHoldAction: isSelectionMode
                  ? null
                  : () => _enterSelectionMode(displayMessage),
              child: _ChatBubble(
                message: displayMessage.messageText,
                kind: chat.kind,
                time: chat.time,
                isMine: chat.isMine,
                isEdited: chat.editedAt != null,
                deliveryState: chat.deliveryState,
                reply: chat.reply,
                isHighlighted:
                    _highlightedMessageId == visualKey && _highlightVisible,
                onReplyTap: isSelectionMode || chat.reply?.messageId == null
                    ? null
                    : () => _focusRepliedMessage(chat.reply!.messageId),
                mediaItems: displayMessage.mediaItems,
                onMediaTapAtIndex:
                    isSelectionMode || displayMessage.mediaItems.isEmpty
                    ? null
                    : (mediaIndex) => _openChatMediaGroup(
                        displayMessage.mediaItems,
                        initialIndex: mediaIndex,
                      ),
                product: chat.product,
                onProductTap:
                    isSelectionMode ||
                        displayMessage.mediaItems.isNotEmpty ||
                        !widget.showInlineProductSnapshots ||
                        chat.product == null
                    ? null
                    : _isAttachmentSnapshot(chat.product!)
                    ? () => _openAttachmentSnapshot(chat.product!)
                    : () => _openMessageProductCard(chat.product!),
                avatarUrl: avatarUrl,
                participantUserId: _participantUserId,
                participantIsOnline: _participantIsOnlineValue,
                primary: primary,
                incomingBubbleColor: incomingBubbleColor,
                outgoingBubbleColor: outgoingBubbleColor,
                subtleText: subtleText,
              ),
            ),
          ),
        );
      case _ChatTimelineItemType.photoUploads:
        return Column(
          children: [
            const SizedBox(height: 8),
            _AttachmentUploadProgressGrid(
              tasks: _photoUploadTasks,
              primary: primary,
              cardColor: incomingBubbleColor,
              subtleText: subtleText,
            ),
            const SizedBox(height: 8),
          ],
        );
      case _ChatTimelineItemType.documentUploads:
        return Column(
          children: [
            const SizedBox(height: 8),
            _DocumentUploadProgressList(
              tasks: _documentUploadTasks,
              primary: primary,
              cardColor: incomingBubbleColor,
              subtleText: subtleText,
            ),
            const SizedBox(height: 8),
          ],
        );
      case _ChatTimelineItemType.typing:
        return Column(
          children: [
            const SizedBox(height: 6),
            _TypingIndicatorBubble(
              cardColor: incomingBubbleColor,
              subtleText: subtleText,
            ),
          ],
        );
    }
  }

  int? _findTimelineItemIndexByKey(
    Key key,
    List<_ChatTimelineItem> timelineItems,
  ) {
    for (var index = 0; index < timelineItems.length; index += 1) {
      if (timelineItems[index].key == key) {
        return index;
      }
    }

    return null;
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
        _queueDocumentAttachment(attachment);
        return;
    }
  }

  void _queueDocumentAttachment(UiChatAttachment attachment) {
    if (!mounted) {
      return;
    }

    setState(() {
      _pendingDocumentAttachment = attachment;
    });
  }

  void _clearPendingDocumentAttachment() {
    if (!mounted || _pendingDocumentAttachment == null) {
      return;
    }

    setState(() {
      _pendingDocumentAttachment = null;
    });
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

    final previousReplyingToMessage = _replyingToMessage;
    final replyPayload = await _replyPayload(previousReplyingToMessage);

    if (mounted) {
      setState(() {
        _replyingToMessage = null;
      });
    }

    await _chatSessionController.enqueuePhotoUpload(
      fileBytes: bytes,
      fileName: attachment.label,
      width: attachment.width,
      height: attachment.height,
      mediaGroupId: attachment.mediaGroupId,
      replyPayload: replyPayload,
    );

    _syncPhotoUploadTasks();
    _chatViewportController.scheduleBottomAnchor(
      shouldStayPinnedToBottom: true,
    );
  }

  Future<void> _sendDocumentAttachment(
    UiChatAttachment attachment, {
    String? messageContent,
    Map<String, dynamic>? replyPayload,
    _ChatMessageReply? pendingReply,
  }) async {
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

    final trimmedMessageContent = messageContent?.trim() ?? '';
    _chatViewportController.scheduleBottomAnchor(
      shouldStayPinnedToBottom: true,
    );

    try {
      await _chatSessionController.enqueueDocumentUpload(
        fileBytes: bytes,
        fileName: attachment.label,
        fileSizeBytes: attachment.sizeBytes ?? bytes.length,
        mediaGroupId: attachment.mediaGroupId,
        replyPayload: replyPayload,
        messageContent: trimmedMessageContent,
      );
      _syncDocumentUploadTasks();
    } on AppApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload impossible: $error')));
    }
  }

  String _fileExtensionLabel(String fileName) {
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot < 0 || lastDot == fileName.length - 1) {
      return 'Fichier';
    }

    return fileName.substring(lastDot + 1).toUpperCase();
  }

  String _formatAttachmentSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      final kiloBytes = bytes / 1024;
      return '${kiloBytes.toStringAsFixed(kiloBytes >= 100 ? 0 : 1)} KB';
    }

    final megaBytes = bytes / (1024 * 1024);
    return '${megaBytes.toStringAsFixed(megaBytes >= 10 ? 0 : 1)} MB';
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
          builder: (_) => PrivateImageViewerPage(
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
          builder: (_) => PrivateImageViewerPage(
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
        builder: (_) => PrivateImageViewerPage(
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
    final displayMessages = _displayMessagesForTimeline(_messagesForDisplay());
    final selectedDisplayMessages = _selectedDisplayMessages(displayMessages);
    final selectedCount = selectedDisplayMessages.length;
    final isSelectionMode = _isSelectionMode;
    final nextMessageKeys = <String, GlobalKey>{};

    for (final displayMessage in displayMessages) {
      _displayMessageTargetKey(displayMessage, nextMessageKeys);
    }

    _messageKeys
      ..clear()
      ..addAll(nextMessageKeys);

    final singleSelectedDisplayMessage = selectedCount == 1
        ? selectedDisplayMessages.single
        : null;
    final selectionMenuActions = _selectionMenuActionsFor(
      selectedDisplayMessages,
    );
    final canShareSelection =
        singleSelectedDisplayMessage != null &&
        _canCopyDisplayMessage(singleSelectedDisplayMessage);
    final timelineItems = _timelineItemsForDisplayMessages(
      displayMessages,
    ).reversed.toList(growable: false);

    return WillPopScope(
      onWillPop: () async {
        if (isSelectionMode) {
          _clearSelectedMessages();
          return false;
        }
        return true;
      },
      child: Scaffold(
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
                          onBackPressed: () {
                            final onCloseRequested = widget.onCloseRequested;
                            if (isSelectionMode) {
                              _clearSelectedMessages();
                              return;
                            }

                            if (onCloseRequested != null) {
                              onCloseRequested();
                              return;
                            }

                            Navigator.of(context).pop();
                          },
                          onViewProfile: _openParticipantProfile,
                          onReport: _showReportParticipantDialog,
                          selectionMode: isSelectionMode,
                          selectionCount: selectedCount,
                          onClearSelection: _clearSelectedMessages,
                          onShareSelection: canShareSelection
                              ? () => _shareSelectedMessages(
                                  selectedDisplayMessages,
                                )
                              : null,
                          onDeleteSelection: selectedCount > 0
                              ? () => _deleteSelectedMessages(
                                  selectedDisplayMessages,
                                )
                              : null,
                          selectionMenuActions: selectionMenuActions,
                          onSelectionMenuAction: selectionMenuActions.isEmpty
                              ? null
                              : (action) => _handleSelectionMenuAction(
                                  action,
                                  selectedDisplayMessages,
                                ),
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
                            child: ListView.custom(
                              controller: _scrollController,
                              reverse: true,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                10,
                                12,
                                10,
                                18,
                              ),
                              childrenDelegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final item = timelineItems[index];
                                  return KeyedSubtree(
                                    key: item.key,
                                    child: _buildTimelineItem(
                                      item,
                                      theme: theme,
                                      primary: primary,
                                      subtleText: subtleText,
                                      incomingBubbleColor: incomingBubbleColor,
                                      outgoingBubbleColor: outgoingBubbleColor,
                                      dateDividerCardColor:
                                          appColors.panelBackground,
                                      avatarUrl: avatarUrl,
                                      isSelectionMode: isSelectionMode,
                                    ),
                                  );
                                },
                                childCount: timelineItems.length,
                                findChildIndexCallback: (key) =>
                                    _findTimelineItemIndexByKey(
                                      key,
                                      timelineItems,
                                    ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_editingMessage != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      8,
                                      8,
                                      8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.edit_outlined,
                                          size: 16,
                                          color: primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Modifier le message',
                                                style: TextStyle(
                                                  color: primary,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              Text(
                                                _editingMessage!.message,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: subtleText,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: _cancelEditingMessage,
                                          icon: const Icon(
                                            Icons.close,
                                            size: 18,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          color: subtleText,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
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
                              if (_pendingDocumentAttachment != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _PendingDocumentComposerCard(
                                    primary: primary,
                                    appColors: appColors,
                                    fileTypeLabel: _fileExtensionLabel(
                                      _pendingDocumentAttachment!.label,
                                    ),
                                    fileName: _pendingDocumentAttachment!.label,
                                    fileSizeLabel: _formatAttachmentSize(
                                      _pendingDocumentAttachment!.sizeBytes ??
                                          _pendingDocumentAttachment!
                                              .bytes
                                              ?.length ??
                                          0,
                                    ),
                                    onClose: _clearPendingDocumentAttachment,
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
                                UiChatMessageInput(
                                  controller: _messageController,
                                  onAttachmentSelected: _handleAttachment,
                                  onTextChanged: _handleComposerChanged,
                                  onSend: _sendMessage,
                                  primary: primary,
                                  panelColor: panelColor,
                                  borderColor: appColors.inputBorder,
                                  canSendWithoutText:
                                      _pendingDocumentAttachment != null,
                                  allowMultipleDocumentSelection: false,
                                  hintText: 'Message',
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_chatViewportController.showScrollToLatestButton)
                      Positioned(
                        right: 18,
                        bottom: 92,
                        child: SafeArea(
                          minimum: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _chatViewportController.animateToBottom,
                              borderRadius: BorderRadius.circular(22),
                              child: Ink(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: primary.withValues(alpha: 0.28),
                                      blurRadius: 14,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (isOffline) const AppOfflineBanner(bottomOffset: 78),
                  ],
                ),
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
  final VoidCallback onBackPressed;
  final VoidCallback onViewProfile;
  final VoidCallback onReport;
  final bool selectionMode;
  final int selectionCount;
  final VoidCallback? onClearSelection;
  final VoidCallback? onShareSelection;
  final VoidCallback? onDeleteSelection;
  final List<_ChatSelectionMenuAction> selectionMenuActions;
  final ValueChanged<_ChatSelectionMenuAction>? onSelectionMenuAction;

  const _ChatHeader({
    required this.primary,
    required this.headerColor,
    required this.subtleText,
    required this.sellerName,
    required this.statusText,
    required this.avatarUrl,
    this.userId,
    this.isOnline = false,
    required this.onBackPressed,
    required this.onViewProfile,
    required this.onReport,
    this.selectionMode = false,
    this.selectionCount = 0,
    this.onClearSelection,
    this.onShareSelection,
    this.onDeleteSelection,
    this.selectionMenuActions = const <_ChatSelectionMenuAction>[],
    this.onSelectionMenuAction,
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

        if (widget.selectionMode) {
          return Container(
            height: 72,
            color: widget.headerColor,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onClearSelection ?? widget.onBackPressed,
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  splashRadius: 20,
                ),
                Expanded(
                  child: Text(
                    widget.selectionCount == 1
                        ? '1 message selectionne'
                        : '${widget.selectionCount} messages selectionnes',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (widget.onShareSelection != null)
                  IconButton(
                    onPressed: widget.onShareSelection,
                    tooltip: 'Partager',
                    splashRadius: 20,
                    icon: const Icon(Icons.share_outlined, color: Colors.white),
                  ),
                if (widget.onDeleteSelection != null)
                  IconButton(
                    onPressed: widget.onDeleteSelection,
                    tooltip: 'Supprimer',
                    splashRadius: 20,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.white,
                    ),
                  ),
                if (widget.selectionMenuActions.isNotEmpty &&
                    widget.onSelectionMenuAction != null)
                  PopupMenuButton<_ChatSelectionMenuAction>(
                    tooltip: 'Plus d\'options',
                    color: widget.headerColor,
                    onSelected: widget.onSelectionMenuAction,
                    itemBuilder: (context) => widget.selectionMenuActions
                        .map(
                          (action) => PopupMenuItem<_ChatSelectionMenuAction>(
                            value: action,
                            child: Text(
                              switch (action) {
                                _ChatSelectionMenuAction.copy => 'Copier',
                                _ChatSelectionMenuAction.edit => 'Modifier',
                              },
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                  ),
              ],
            ),
          );
        }

        return Container(
          height: 72,
          color: widget.headerColor,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onBackPressed,
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
  final String? createdAt;
  final String? editedAt;
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
    this.createdAt,
    this.editedAt,
    required this.time,
    required this.isMine,
    this.deliveryState,
    this.reply,
    this.media,
    this.product,
  });
}

class _ConfirmedMessageDisplayOverride {
  final String? createdAt;
  final String time;

  const _ConfirmedMessageDisplayOverride({
    required this.createdAt,
    required this.time,
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
    bool isPlaceholderText(String value) {
      final normalized = value.trim();
      return normalized == 'Photo envoyee' ||
          normalized == 'Document envoye' ||
          normalized == '...' ||
          normalized == '…';
    }

    bool hasVisibleStructuredContent(_ChatMessage message) {
      return message.media != null || message.product != null;
    }

    if (messages.length == 1) {
      final singleMessage = anchorMessage.message.trim();
      return isPlaceholderText(singleMessage) &&
              hasVisibleStructuredContent(anchorMessage)
          ? ''
          : anchorMessage.message;
    }

    final normalizedMessages = messages
        .map((message) => message.message.trim())
        .where((message) => message.isNotEmpty)
        .toSet();
    if (normalizedMessages.length != 1) {
      return '';
    }

    final message = normalizedMessages.first;
    if (isPlaceholderText(message) && mediaItems.isNotEmpty) {
      return '';
    }

    return message;
  }
}

enum _ChatTimelineItemType {
  loadingOlder,
  info,
  dateDivider,
  message,
  photoUploads,
  documentUploads,
  typing,
}

class _ChatTimelineItem {
  final _ChatTimelineItemType type;
  final _ChatDisplayMessage? displayMessage;
  final int? displayIndex;
  final String? messageKeySuffix;
  final String? infoText;
  final bool isError;
  final DateTime? date;

  const _ChatTimelineItem._({
    required this.type,
    this.displayMessage,
    this.displayIndex,
    this.messageKeySuffix,
    this.infoText,
    this.isError = false,
    this.date,
  });

  const _ChatTimelineItem.loadingOlder()
    : this._(type: _ChatTimelineItemType.loadingOlder);

  const _ChatTimelineItem.info({required String text, required bool isError})
    : this._(
        type: _ChatTimelineItemType.info,
        infoText: text,
        isError: isError,
      );

  const _ChatTimelineItem.dateDivider({required DateTime date})
    : this._(type: _ChatTimelineItemType.dateDivider, date: date);

  const _ChatTimelineItem.message({
    required _ChatDisplayMessage displayMessage,
    required int displayIndex,
    required String messageKeySuffix,
  }) : this._(
         type: _ChatTimelineItemType.message,
         displayMessage: displayMessage,
         displayIndex: displayIndex,
         messageKeySuffix: messageKeySuffix,
       );

  const _ChatTimelineItem.photoUploads()
    : this._(type: _ChatTimelineItemType.photoUploads);

  const _ChatTimelineItem.documentUploads()
    : this._(type: _ChatTimelineItemType.documentUploads);

  const _ChatTimelineItem.typingIndicator()
    : this._(type: _ChatTimelineItemType.typing);

  Key get key {
    switch (type) {
      case _ChatTimelineItemType.loadingOlder:
        return const ValueKey('timeline-loading-older');
      case _ChatTimelineItemType.info:
        return ValueKey('timeline-info:${isError ? 'error' : 'empty'}');
      case _ChatTimelineItemType.dateDivider:
        final normalizedDate = date!;
        return ValueKey(
          'timeline-date:${normalizedDate.year}-${normalizedDate.month}-${normalizedDate.day}',
        );
      case _ChatTimelineItemType.message:
        final anchorMessage = displayMessage!.anchorMessage;
        final suffix = messageKeySuffix?.trim().isNotEmpty == true
            ? messageKeySuffix!.trim()
            : '${anchorMessage.createdAt ?? ''}#${displayIndex ?? 0}';
        return ValueKey('timeline-message:$suffix');
      case _ChatTimelineItemType.photoUploads:
        return const ValueKey('timeline-photo-uploads');
      case _ChatTimelineItemType.documentUploads:
        return const ValueKey('timeline-document-uploads');
      case _ChatTimelineItemType.typing:
        return const ValueKey('timeline-typing');
    }
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

enum _ChatMessageDeliveryState { sending, sent, delivered, seen }

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

class _ChatPageViewState {
  const _ChatPageViewState({required this.payload, this.scrollOffset});

  final Map<String, dynamic> payload;
  final double? scrollOffset;
}

class _DeleteMessageBatch {
  final List<String> pendingIds;
  final List<String> persistedIds;

  const _DeleteMessageBatch({
    required this.pendingIds,
    required this.persistedIds,
  });

  int get totalOperations => pendingIds.length + persistedIds.length;
}

class _DeleteMessagesProgress {
  final int completedSteps;
  final int totalSteps;
  final String statusText;

  const _DeleteMessagesProgress({
    required this.completedSteps,
    required this.totalSteps,
    required this.statusText,
  });

  double get progress {
    if (totalSteps <= 0) {
      return 0;
    }

    return (completedSteps / totalSteps).clamp(0, 1).toDouble();
  }

  int get percent => (progress * 100).round().clamp(0, 100);
}

class _ChatBubble extends StatelessWidget {
  final String message;
  final _ChatMessageKind kind;
  final String time;
  final bool isMine;
  final bool isEdited;
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
  final bool participantIsOnline;
  final Color primary;
  final Color incomingBubbleColor;
  final Color outgoingBubbleColor;
  final Color subtleText;

  const _ChatBubble({
    required this.message,
    this.kind = _ChatMessageKind.text,
    required this.time,
    required this.isMine,
    this.isEdited = false,
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
    this.participantIsOnline = false,
    required this.primary,
    required this.incomingBubbleColor,
    required this.outgoingBubbleColor,
    required this.subtleText,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedMessage = message.trim();
    final isDeletedPlaceholder =
        normalizedMessage.toLowerCase() == 'message supprime';
    final hasCaptionText = normalizedMessage.isNotEmpty;
    final deletedAccent = isMine
        ? const Color(0xFF2E8B57)
        : subtleText.withValues(alpha: 0.92);
    final bubbleColor = isDeletedPlaceholder
        ? deletedAccent.withValues(alpha: 0.09)
        : isMine
        ? outgoingBubbleColor
        : incomingBubbleColor;
    final textColor = isDeletedPlaceholder
        ? deletedAccent
        : Colors.white.withValues(alpha: 0.96);
    final metaColor = isDeletedPlaceholder
        ? deletedAccent.withValues(alpha: 0.88)
        : isMine
        ? primary.withValues(alpha: 0.74)
        : subtleText.withValues(alpha: 0.92);
    final normalizedParticipantUserId = participantUserId?.trim() ?? '';
    if (isMine && normalizedParticipantUserId.isNotEmpty) {
      PresenceService.instance.watchUser(normalizedParticipantUserId);
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isMine ? 290 : 276),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: BoxDecoration(
            color: bubbleColor,
            border: Border.all(
              color: isHighlighted
                  ? primary.withValues(alpha: 0.9)
                  : isDeletedPlaceholder
                  ? deletedAccent.withValues(alpha: 0.45)
                  : Colors.transparent,
              width: isHighlighted || isDeletedPlaceholder ? 1.4 : 0,
            ),
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
              if (mediaItems.isNotEmpty) ...[
                mediaItems.length == 1
                    ? _InlineChatMediaCard(
                        media: mediaItems.first,
                        isMine: isMine,
                        emphasizeBorder: hasCaptionText,
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
                        onTap: onMediaTapAtIndex == null
                            ? null
                            : () => onMediaTapAtIndex!(0),
                      )
                    : _InlineChatMediaGroupCard(
                        mediaItems: mediaItems,
                        isMine: isMine,
                        emphasizeBorder: hasCaptionText,
                        primary: primary,
                        cardColor: incomingBubbleColor,
                        subtleText: metaColor,
                        onTapAtIndex: onMediaTapAtIndex,
                      ),
                if (message.trim().isNotEmpty) const SizedBox(height: 10),
              ],
              if (product != null) ...[
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
              if (isDeletedPlaceholder)
                Row(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.remove_circle_outline,
                      size: 18,
                      color: deletedAccent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        normalizedMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      time,
                      style: TextStyle(
                        color: deletedAccent.withValues(alpha: 0.88),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                )
              else if (message.trim().isNotEmpty)
                Text(
                  message,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              if (!isDeletedPlaceholder) ...[
                if (message.trim().isNotEmpty) const SizedBox(height: 6),
                ValueListenableBuilder<int>(
                  valueListenable: PresenceService.instance.changes,
                  builder: (context, value, child) {
                    final delivery = _ChatDeliveryPresentation.fromState(
                      deliveryState,
                      primary,
                      metaColor,
                    );

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isEdited) ...[
                          Text(
                            'modifié',
                            style: TextStyle(
                              color: const Color.fromARGB(113, 192, 192, 192),
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
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
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentUploadProgressGrid extends StatelessWidget {
  final List<ChatPhotoUploadTask> tasks;
  final Color primary;
  final Color cardColor;
  final Color subtleText;

  const _AttachmentUploadProgressGrid({
    required this.tasks,
    required this.primary,
    required this.cardColor,
    required this.subtleText,
  });

  @override
  Widget build(BuildContext context) {
    final columnCount = tasks.length == 1 ? 1 : 2;

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final itemWidth =
            (constraints.maxWidth - ((columnCount - 1) * spacing)) /
            columnCount;
        final compact = columnCount == 1;
        final mainAxisExtent = compact ? 106.0 : itemWidth + 94;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tasks.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            mainAxisExtent: mainAxisExtent,
          ),
          itemBuilder: (context, index) {
            return _AttachmentUploadProgressCard(
              task: tasks[index],
              primary: primary,
              cardColor: cardColor,
              subtleText: subtleText,
              compact: compact,
            );
          },
        );
      },
    );
  }
}

class _DocumentUploadProgressList extends StatelessWidget {
  final List<ChatDocumentUploadTask> tasks;
  final Color primary;
  final Color cardColor;
  final Color subtleText;

  const _DocumentUploadProgressList({
    required this.tasks,
    required this.primary,
    required this.cardColor,
    required this.subtleText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < tasks.length; index++) ...[
          _DocumentUploadProgressCard(
            task: tasks[index],
            primary: primary,
            cardColor: cardColor,
            subtleText: subtleText,
          ),
          if (index < tasks.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _DeleteMessagesProgressDialog extends StatelessWidget {
  final ValueNotifier<_DeleteMessagesProgress> progressListenable;
  final Color primary;

  const _DeleteMessagesProgressDialog({
    required this.progressListenable,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: ValueListenableBuilder<_DeleteMessagesProgress>(
        valueListenable: progressListenable,
        builder: (context, progress, child) {
          return Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            decoration: BoxDecoration(
              color: appColors.panelBackground,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: appColors.inputBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox(
                    width: 132,
                    height: 132,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(color: Colors.black.withValues(alpha: 0.16)),
                        _WaterFillProgressLayer(
                          progress: progress.progress,
                          primary: theme.colorScheme.error,
                          visualState: _WaterFillVisualState.uploading,
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.white,
                                size: 34,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${progress.percent}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Suppression en cours',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  progress.statusText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: appColors.mutedText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: progress.progress,
                    color: theme.colorScheme.error,
                    backgroundColor: theme.colorScheme.error.withValues(
                      alpha: 0.16,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DocumentUploadProgressCard extends StatelessWidget {
  final ChatDocumentUploadTask task;
  final Color primary;
  final Color cardColor;
  final Color subtleText;

  const _DocumentUploadProgressCard({
    required this.task,
    required this.primary,
    required this.cardColor,
    required this.subtleText,
  });

  String _formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      final kiloBytes = bytes / 1024;
      return '${kiloBytes.toStringAsFixed(kiloBytes >= 100 ? 0 : 1)} KB';
    }

    final megaBytes = bytes / (1024 * 1024);
    return '${megaBytes.toStringAsFixed(megaBytes >= 10 ? 0 : 1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = task.hasFailed ? Colors.redAccent : primary;
    final visualState = task.hasFailed
        ? _WaterFillVisualState.failed
        : _WaterFillVisualState.uploading;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 68,
              height: 68,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: Colors.black.withValues(alpha: 0.18)),
                  _WaterFillProgressLayer(
                    progress: task.progress.clamp(0, 1),
                    primary: accentColor,
                    visualState: visualState,
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.description_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${task.percent}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatSize(task.fileSizeBytes),
                  style: TextStyle(
                    color: subtleText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  task.statusText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: task.hasFailed ? Colors.redAccent : subtleText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    value: task.progress.clamp(0, 1),
                    color: accentColor,
                    backgroundColor: accentColor.withValues(alpha: 0.16),
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

class _AttachmentUploadProgressCard extends StatelessWidget {
  final ChatPhotoUploadTask task;
  final Color primary;
  final Color cardColor;
  final Color subtleText;
  final bool compact;

  const _AttachmentUploadProgressCard({
    required this.task,
    required this.primary,
    required this.cardColor,
    required this.subtleText,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedPercent = task.progressPercent.clamp(1, 100);
    final normalizedProgress = normalizedPercent / 100;
    final isWaitingForConnection =
        task.state == ChatPhotoUploadState.waitingForConnection;
    final isFailed = task.state == ChatPhotoUploadState.failed;
    final accentColor = isFailed
        ? Colors.redAccent
        : (isWaitingForConnection ? const Color(0xFF4FC3F7) : primary);
    final waterFillVisualState = isFailed
        ? _WaterFillVisualState.failed
        : isWaitingForConnection
        ? _WaterFillVisualState.waiting
        : _WaterFillVisualState.uploading;
    final statusText = isFailed
        ? 'Echec de l\'envoi'
        : isWaitingForConnection
        ? 'Reprise automatique'
        : 'Remplissage en cours';

    Widget buildPreview({
      required double borderRadius,
      required double iconSize,
    }) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(task.previewBytes, fit: BoxFit.cover),
            Container(color: Colors.black.withValues(alpha: 0.18)),
            _WaterFillProgressLayer(
              progress: normalizedProgress,
              primary: accentColor,
              visualState: waterFillVisualState,
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isFailed
                        ? Icons.error_outline_rounded
                        : isWaitingForConnection
                        ? Icons.wifi_off_rounded
                        : Icons.cloud_upload_outlined,
                    color: Colors.white,
                    size: iconSize,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$normalizedPercent%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (compact) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isFailed
                ? Colors.redAccent.withValues(alpha: 0.38)
                : primary.withValues(alpha: 0.24),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 86,
              height: 86,
              child: buildPreview(borderRadius: 16, iconSize: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    task.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.96),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    task.statusLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: subtleText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        isFailed
                            ? Icons.error_rounded
                            : isWaitingForConnection
                            ? Icons.autorenew_rounded
                            : Icons.water_drop_rounded,
                        size: 14,
                        color: accentColor,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          statusText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accentColor.withValues(alpha: 0.95),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFailed
              ? Colors.redAccent.withValues(alpha: 0.38)
              : primary.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: buildPreview(borderRadius: 16, iconSize: 24),
          ),
          const SizedBox(height: 8),
          Text(
            task.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.96),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            task.statusLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: subtleText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                isFailed
                    ? Icons.error_rounded
                    : isWaitingForConnection
                    ? Icons.autorenew_rounded
                    : Icons.water_drop_rounded,
                size: 14,
                color: accentColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accentColor.withValues(alpha: 0.95),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _WaterFillVisualState { uploading, waiting, failed }

class _WaterFillProgressLayer extends StatefulWidget {
  final double progress;
  final Color primary;
  final _WaterFillVisualState visualState;

  const _WaterFillProgressLayer({
    required this.progress,
    required this.primary,
    required this.visualState,
  });

  @override
  State<_WaterFillProgressLayer> createState() =>
      _WaterFillProgressLayerState();
}

class _WaterFillProgressLayerState extends State<_WaterFillProgressLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _flowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _flowAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flowAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: _WaterFillPainter(
            progress: widget.progress.clamp(0, 1),
            phase: _controller.value,
            easedPhase: _flowAnimation.value,
            primary: widget.primary,
            visualState: widget.visualState,
          ),
        );
      },
    );
  }
}

class _WaterFillPainter extends CustomPainter {
  final double progress;
  final double phase;
  final double easedPhase;
  final Color primary;
  final _WaterFillVisualState visualState;

  const _WaterFillPainter({
    required this.progress,
    required this.phase,
    required this.easedPhase,
    required this.primary,
    required this.visualState,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    final fillTop = size.height * (1 - clampedProgress);
    final liquidRect = Rect.fromLTWH(0, fillTop, size.width, size.height);
    final isUploading = visualState == _WaterFillVisualState.uploading;
    final isWaiting = visualState == _WaterFillVisualState.waiting;
    final topAlpha = isUploading ? 0.52 : (isWaiting ? 0.3 : 0.38);
    final midAlpha = isUploading ? 0.86 : (isWaiting ? 0.56 : 0.7);
    final bottomAlpha = isUploading ? 1.0 : (isWaiting ? 0.8 : 0.94);
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primary.withValues(alpha: topAlpha),
          primary.withValues(alpha: midAlpha),
          primary.withValues(alpha: bottomAlpha),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Offset.zero & size);

    canvas.drawRect(liquidRect, bodyPaint);

    final depthShadeRect = Rect.fromLTWH(
      0,
      fillTop + (size.height * 0.08),
      size.width,
      size.height * 0.92,
    );
    canvas.drawRect(
      depthShadeRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.05),
            Colors.black.withValues(alpha: 0.1),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(depthShadeRect),
    );

    final pulseOffset =
        math.sin(easedPhase * 2 * math.pi) *
        (size.height * (isUploading ? 0.018 : 0.012));
    final frontWaveBase = fillTop + pulseOffset;
    final backWaveBase = fillTop - (size.height * 0.018) + (pulseOffset * 0.65);
    final primaryWaveAmplitude = math.max(
      2.0,
      size.height * (isUploading ? 0.072 : 0.055),
    );
    final secondaryWaveAmplitude = math.max(
      1.5,
      size.height * (isUploading ? 0.04 : 0.03),
    );
    final primaryFrequency =
        (2 * math.pi * (isUploading ? 1.36 : 1.15)) / math.max(1, size.width);
    final secondaryFrequency =
        (2 * math.pi * (isUploading ? 2.18 : 1.9)) / math.max(1, size.width);
    final primaryShift = phase * (isUploading ? 2.7 : 2.0) * math.pi;
    final secondaryShift = -(phase * (isUploading ? 3.75 : 2.8) * math.pi);

    final backWavePath = Path()..moveTo(0, backWaveBase);
    for (double x = 0; x <= size.width; x += 1) {
      final y =
          backWaveBase +
          math.sin((x * primaryFrequency) + primaryShift) *
              primaryWaveAmplitude;
      backWavePath.lineTo(x, y);
    }
    backWavePath
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final backWavePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: isUploading ? 0.1 : 0.05),
          primary.withValues(alpha: isUploading ? 0.24 : 0.16),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(backWavePath, backWavePaint);

    final frontWavePath = Path()..moveTo(0, frontWaveBase);
    for (double x = 0; x <= size.width; x += 1) {
      final y =
          frontWaveBase +
          math.sin((x * secondaryFrequency) + secondaryShift) *
              secondaryWaveAmplitude;
      frontWavePath.lineTo(x, y);
    }
    frontWavePath
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final frontWavePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: isUploading ? 0.24 : 0.16),
          Colors.white.withValues(alpha: isUploading ? 0.06 : 0.03),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(frontWavePath, frontWavePaint);

    final shimmerWidth = size.width * (isUploading ? 0.34 : 0.28);
    final shimmerLeft =
        ((phase * (isUploading ? 1.95 : 1.2)) % 1.0) *
            (size.width + shimmerWidth) -
        shimmerWidth;
    final shimmerRect = Rect.fromLTWH(
      shimmerLeft,
      fillTop,
      shimmerWidth,
      size.height - fillTop,
    );
    canvas.save();
    canvas.clipRect(liquidRect);
    canvas.drawRect(
      shimmerRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: isUploading ? 0.12 : 0.07),
            Colors.white.withValues(alpha: isUploading ? 0.24 : 0.16),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.28, 0.58, 1.0],
        ).createShader(shimmerRect),
    );
    canvas.restore();

    final surfaceHighlight = Path()..moveTo(0, frontWaveBase);
    for (double x = 0; x <= size.width; x += 1) {
      final y =
          frontWaveBase +
          math.sin((x * secondaryFrequency) + secondaryShift) *
              secondaryWaveAmplitude;
      surfaceHighlight.lineTo(x, y);
    }

    canvas.drawPath(
      surfaceHighlight,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isUploading ? 1.55 : 1.25
        ..color = Colors.white.withValues(alpha: isUploading ? 0.38 : 0.26),
    );

    final foamPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isUploading ? 2.5 : 2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: isUploading ? 0.28 : 0.18);
    for (int index = 0; index < (isUploading ? 7 : 5); index++) {
      final x =
          ((index * 0.17) + (phase * (isUploading ? 0.62 : 0.35))) %
          1.0 *
          size.width;
      final arcWidth = size.width * (0.05 + (index * 0.006));
      final arcRect = Rect.fromCenter(
        center: Offset(x, frontWaveBase + (index.isEven ? -1.5 : 1.5)),
        width: arcWidth,
        height: size.height * 0.024,
      );
      canvas.drawArc(arcRect, math.pi * 1.04, math.pi * 0.88, false, foamPaint);
    }

    final bubblePaint = Paint()..style = PaintingStyle.fill;
    final bubbleData =
        <(double xFactor, double yFactor, double radiusFactor, double speed)>{
          (0.18, 0.22, 0.02, 0.85),
          (0.34, 0.58, 0.016, 1.1),
          (0.56, 0.36, 0.024, 0.74),
          (0.73, 0.68, 0.015, 1.25),
          (0.86, 0.44, 0.018, 0.93),
          if (isUploading) (0.1, 0.51, 0.013, 1.44),
          if (isUploading) (0.63, 0.18, 0.014, 1.62),
        };
    canvas.save();
    canvas.clipRect(liquidRect);
    for (final bubble in bubbleData) {
      final travel = ((phase * bubble.$4) + bubble.$2) % 1.0;
      final bubbleY = size.height - (travel * (size.height - fillTop));
      if (bubbleY < fillTop + 6) {
        continue;
      }
      final horizontalDrift =
          math.sin((phase * 2 * math.pi) + (bubble.$1 * 9)) *
          (size.width * 0.012);
      final center = Offset(
        (bubble.$1 * size.width) + horizontalDrift,
        bubbleY,
      );
      final radius = math.max(1.6, size.width * bubble.$3);
      bubblePaint.color = Colors.white.withValues(
        alpha: isUploading ? 0.2 : 0.14,
      );
      canvas.drawCircle(center, radius, bubblePaint);
      canvas.drawCircle(
        center.translate(-radius * 0.25, -radius * 0.25),
        radius * 0.38,
        Paint()
          ..color = Colors.white.withValues(alpha: isUploading ? 0.28 : 0.2),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = Colors.white.withValues(alpha: isUploading ? 0.32 : 0.22),
      );
    }
    canvas.restore();

    final glowRect = Rect.fromLTWH(
      0,
      fillTop - (size.height * 0.08),
      size.width,
      size.height * 0.22,
    );
    canvas.drawRect(
      glowRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: isUploading ? 0.2 : 0.12),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(glowRect),
    );

    if (isUploading) {
      final sparkPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white.withValues(alpha: 0.24);
      for (int index = 0; index < 4; index++) {
        final x = ((phase * (0.92 + (index * 0.21))) + (index * 0.24)) % 1.0;
        final y = fillTop + (size.height - fillTop) * (0.12 + (index * 0.11));
        canvas.drawCircle(
          Offset(x * size.width, y),
          1.2 + (index * 0.18),
          sparkPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WaterFillPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.phase != phase ||
        oldDelegate.easedPhase != easedPhase ||
        oldDelegate.primary != primary ||
        oldDelegate.visualState != visualState;
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
          label: 'Envoi',
          icon: Icons.schedule_rounded,
          color: fallbackColor,
        );
      case _ChatMessageDeliveryState.sent:
        return _ChatDeliveryPresentation(
          label: 'Envoye',
          icon: Icons.done_rounded,
          color: fallbackColor,
        );
      case _ChatMessageDeliveryState.delivered:
        return _ChatDeliveryPresentation(
          label: 'Distribue',
          icon: Icons.done_all_rounded,
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

    final surfaceColor = isMine
        ? primary.withValues(alpha: 0.08)
        : cardColor.withValues(alpha: 0.92);
    final borderColor = isMine
        ? primary.withValues(alpha: 0.22)
        : Colors.white.withValues(alpha: 0.08);
    final titleColor = Colors.white.withValues(alpha: 0.96);
    final priceColor = isMine ? primary : const Color(0xFFF8D66D);

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
  final bool emphasizeBorder;
  final Color primary;
  final Color cardColor;
  final Color subtleText;
  final VoidCallback? onTap;
  final String? imageUrl;

  const _InlineChatMediaCard({
    required this.media,
    required this.isMine,
    required this.emphasizeBorder,
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
        emphasizeBorder: emphasizeBorder,
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
      emphasizeBorder: emphasizeBorder,
      primary: primary,
      subtleText: subtleText,
      onTap: onTap,
    );
  }
}

class _InlineChatMediaGroupCard extends StatelessWidget {
  final List<_ChatMessageMedia> mediaItems;
  final bool isMine;
  final bool emphasizeBorder;
  final Color primary;
  final Color cardColor;
  final Color subtleText;
  final ValueChanged<int>? onTapAtIndex;

  const _InlineChatMediaGroupCard({
    required this.mediaItems,
    required this.isMine,
    required this.emphasizeBorder,
    required this.primary,
    required this.cardColor,
    required this.subtleText,
    this.onTapAtIndex,
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
          ? (emphasizeBorder
                ? primary.withValues(alpha: 0.28)
                : Colors.transparent)
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
                onTap: onTapAtIndex == null ? null : () => onTapAtIndex!(index),
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
            emphasizeBorder: emphasizeBorder,
            primary: primary,
            subtleText: subtleText,
            onTap: onTapAtIndex == null ? null : () => onTapAtIndex!(index),
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
  final bool emphasizeBorder;
  final Color primary;
  final Color cardColor;
  final Color subtleText;
  final VoidCallback? onTap;
  final String imageUrl;

  const _InlineChatMediaImageCard({
    required this.media,
    required this.isMine,
    required this.emphasizeBorder,
    required this.primary,
    required this.cardColor,
    required this.subtleText,
    required this.imageUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isMine
        ? (emphasizeBorder
              ? primary.withValues(alpha: 0.28)
              : Colors.transparent)
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
  final bool emphasizeBorder;
  final Color primary;
  final Color subtleText;
  final VoidCallback? onTap;

  const _InlineChatDocumentCard({
    required this.media,
    required this.isMine,
    required this.emphasizeBorder,
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
        ? (emphasizeBorder
              ? primary.withValues(alpha: 0.26)
              : Colors.transparent)
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
  final VoidCallback? onHoldAction;
  final VoidCallback? onTap;
  final bool swipeEnabled;
  final Widget child;

  const _SwipeReplyWrapper({
    required this.isMine,
    required this.primary,
    required this.onReply,
    this.onHoldAction,
    this.onTap,
    this.swipeEnabled = true,
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
    if (!widget.swipeEnabled) {
      return;
    }

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
      onTap: widget.onTap,
      onLongPress: widget.onHoldAction,
      onHorizontalDragUpdate: widget.swipeEnabled ? _handleDragUpdate : null,
      onHorizontalDragEnd: widget.swipeEnabled ? (_) => _resetDrag() : null,
      onHorizontalDragCancel: widget.swipeEnabled ? _resetDrag : null,
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

class _ChatDateDivider extends StatelessWidget {
  final String label;
  final Color cardColor;
  final Color subtleText;

  const _ChatDateDivider({
    required this.label,
    required this.cardColor,
    required this.subtleText,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: subtleText,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
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

class _PendingDocumentComposerCard extends StatelessWidget {
  final Color primary;
  final AppThemeColors appColors;
  final String fileTypeLabel;
  final String fileName;
  final String fileSizeLabel;
  final VoidCallback onClose;

  const _PendingDocumentComposerCard({
    required this.primary,
    required this.appColors,
    required this.fileTypeLabel,
    required this.fileName,
    required this.fileSizeLabel,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.description_rounded, color: primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
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
                        fileTypeLabel,
                        style: TextStyle(
                          color: primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileSizeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: appColors.mutedText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
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
