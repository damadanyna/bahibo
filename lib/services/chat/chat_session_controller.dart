import 'dart:async';
import 'dart:math' as math;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:banay/services/app_api_client.dart';
import 'package:banay/services/chat/chat_session_state.dart';
import 'package:banay/services/chat/chat_session_target.dart';
import 'package:banay/services/chat_document_upload_service.dart';
import 'package:banay/services/chat_realtime_service.dart';
import 'package:banay/services/chat_photo_upload_service.dart';
import 'package:banay/services/conversations_api_service.dart';
import 'package:banay/services/local_conversation_store.dart';
import 'package:flutter/foundation.dart';

class ChatMutationResult {
  const ChatMutationResult({
    required this.succeeded,
    this.errorMessage,
    this.isBlocked = false,
  });

  const ChatMutationResult.success() : this(succeeded: true);

  final bool succeeded;
  final String? errorMessage;
  final bool isBlocked;
}

typedef ChatMutationProgressCallback =
    void Function(int completedSteps, int totalSteps, String statusText);

class ChatSessionController extends ChangeNotifier {
  ChatSessionController({
    required this.target,
    ConversationsApiService? conversationsApiService,
    LocalConversationStore? localConversationStore,
    ChatRealtimeService? realtimeService,
  }) : _conversationsApiService =
           conversationsApiService ?? ConversationsApiService(),
       _localConversationStore =
           localConversationStore ?? LocalConversationStore.instance,
       _realtimeService = realtimeService ?? ChatRealtimeService.instance,
       _state = ChatSessionState.initial(targetSessionKey: target.sessionKey);

  static const Duration conversationPollInterval = Duration(seconds: 15);
  static const bool conversationPollingEnabled = false;
  static const int conversationPageFetchLimit = 50;
  static const int recentConversationMessageLimit = 50;
  static const Duration _pendingTextRetryBaseDelay = Duration(seconds: 2);
  static const Duration _pendingTextRetryMaxDelay = Duration(seconds: 30);
  static const Duration _stalePendingTextSendingTimeout = Duration(seconds: 20);
  static const String _deletedMessagePlaceholder = 'Message supprime';

  final ChatSessionTarget target;
  final ConversationsApiService _conversationsApiService;
  final LocalConversationStore _localConversationStore;
  final ChatRealtimeService _realtimeService;
  final Connectivity _connectivity = Connectivity();

  ChatSessionState _state;
  StreamSubscription<Map<String, dynamic>>? _realtimeEventsSubscription;
  StreamSubscription<LocalConversationStoreChange>?
  _localConversationChangesSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _conversationPollTimer;
  Timer? _pendingTextDrainRetryTimer;
  Timer? _realtimeDeleteReconcileTimer;
  Timer? _realtimeNewMessageReconcileTimer;
  int _ignoredNextNonPendingLocalStoreChanges = 0;
  int _pendingTextDrainRetryAttempt = 0;
  bool _isDrainingPendingTextMessages = false;
  bool _hasInternetConnection = true;
  bool _disposed = false;

  ChatSessionState get state => _state;

  Future<void> bootstrap() async {
    if (!target.usesLiveConversation) {
      _updateState(
        _state.copyWith(showEntrySkeleton: false, clearLoadError: true),
      );
      return;
    }

    _bindConnectivityMonitoring();
    await _syncConnectivityState();
    _bindLocalConversationUpdates();
    _bindRealtimeUpdates();
    _startConversationPolling();

    await hydrateFromStore(mergeRecentMessages: false);
    await syncPendingTextMessages();
    await drainPendingTextMessages();
    await loadConversation(showEntrySkeleton: _state.messages.isEmpty);
  }

  Future<void> loadConversation({bool showEntrySkeleton = false}) async {
    if (showEntrySkeleton) {
      _updateState(
        _state.copyWith(showEntrySkeleton: true, clearLoadError: true),
      );
    } else {
      _updateState(_state.copyWith(clearLoadError: true));
    }

    try {
      if (_state.messages.isEmpty) {
        final cachedConversation = await _fetchCachedConversationData();
        if (cachedConversation != null) {
          _applyConversationData(cachedConversation, replaceMessages: true);
        }
      }

      final targetDisplayCount = math.max(
        recentConversationMessageLimit,
        _countDisplayMessages(_state.messages),
      );
      final data = await fetchConversationDisplayWindow(
        targetDisplayCount: targetDisplayCount,
      );
      if (_state.messages.isEmpty) {
        _applyConversationData(data, replaceMessages: true);
      } else {
        _applyRecentConversationWindow(data);
      }
      await syncPendingTextMessages();
    } on AppApiException catch (error) {
      await hydrateFromStore(mergeRecentMessages: true);
      _updateState(
        _state.copyWith(
          showEntrySkeleton: false,
          loadError: _state.messages.isEmpty ? error.message : null,
          clearLoadError: _state.messages.isNotEmpty,
        ),
      );
    }
  }

  Future<void> refreshSilently() async {
    if (_state.isRefreshing || !target.usesLiveConversation) {
      return;
    }

    _updateState(_state.copyWith(isRefreshing: true, clearLoadError: true));
    try {
      final targetDisplayCount = math.max(
        recentConversationMessageLimit,
        _countDisplayMessages(_state.messages),
      );
      final data = await fetchConversationDisplayWindow(
        targetDisplayCount: targetDisplayCount,
      );
      if (_state.messages.isEmpty) {
        _applyConversationData(data, replaceMessages: true);
      } else {
        _applyRecentConversationWindow(data);
      }
    } on AppApiException catch (error) {
      _updateState(
        _state.copyWith(isRefreshing: false, loadError: error.message),
      );
      return;
    }

    _updateState(_state.copyWith(isRefreshing: false, clearLoadError: true));
  }

  Future<void> hydrateFromStore({
    bool mergeRecentMessages = false,
    int? limit,
    String? beforeMessageId,
  }) async {
    final data = await _fetchStoredConversationData(
      limit: limit ?? recentConversationMessageLimit,
      beforeMessageId: beforeMessageId,
    );
    if (data == null) {
      return;
    }

    _applyConversationData(data, replaceMessages: !mergeRecentMessages);
  }

  Future<Map<String, dynamic>?> fetchStoredConversationWindow({
    int? limit,
    String? beforeMessageId,
  }) {
    return _fetchStoredConversationData(
      limit: limit,
      beforeMessageId: beforeMessageId,
    );
  }

  Future<Map<String, dynamic>> fetchConversationDisplayWindow({
    int? targetDisplayCount,
    int? targetRawCount,
    String? beforeMessageId,
  }) async {
    final aggregatedRawMessages = <Map<String, dynamic>>[];
    Map<String, dynamic>? baseData;
    String? cursor = beforeMessageId;
    var hasOlderMessages = true;
    String? oldestLoadedMessageId;

    while (hasOlderMessages) {
      final pageData = await _fetchConversationDataPage(
        limit: conversationPageFetchLimit,
        beforeMessageId: cursor,
      );
      baseData ??= Map<String, dynamic>.from(pageData);

      final rawMessages = ((pageData['messages'] as List?) ?? const [])
          .whereType<Map>()
          .map((message) => Map<String, dynamic>.from(message))
          .toList(growable: false);
      if (beforeMessageId == null) {
        aggregatedRawMessages.addAll(rawMessages);
      } else {
        aggregatedRawMessages.insertAll(0, rawMessages);
      }

      final pagination = Map<String, dynamic>.from(
        (pageData['pagination'] as Map?) ?? const <String, dynamic>{},
      );
      hasOlderMessages = pagination['hasOlderMessages'] == true;
      oldestLoadedMessageId = pagination['oldestLoadedMessageId']?.toString();
      cursor = oldestLoadedMessageId;

      if (!hasOlderMessages ||
          rawMessages.isEmpty ||
          oldestLoadedMessageId == null ||
          oldestLoadedMessageId.isEmpty) {
        break;
      }

      if (targetRawCount != null &&
          aggregatedRawMessages.length >= targetRawCount) {
        break;
      }

      if (targetDisplayCount != null &&
          _countDisplayMessages(aggregatedRawMessages) >= targetDisplayCount) {
        break;
      }
    }

    final result = Map<String, dynamic>.from(
      baseData ?? const <String, dynamic>{},
    );
    result['messages'] = aggregatedRawMessages;
    result['pagination'] = <String, dynamic>{
      'limit': conversationPageFetchLimit,
      'hasOlderMessages': hasOlderMessages,
      'oldestLoadedMessageId': oldestLoadedMessageId,
    };
    return result;
  }

  Future<void> syncPendingTextMessages() async {
    final pendingTextMessages = await _localConversationStore
        .getPendingTextMessages(
          conversationId: _state.conversationId,
          productId: target.productId,
          targetUserId: target.userId,
        );

    final reconciledPendingMessages = await _reconcilePendingTextMessages(
      pendingTextMessages,
    );

    _updateState(
      _state.copyWith(pendingTextMessages: reconciledPendingMessages),
    );
  }

  Future<void> drainPendingTextMessages() async {
    if (_isDrainingPendingTextMessages || !target.usesLiveConversation) {
      return;
    }
    if (!_hasInternetConnection) {
      _schedulePendingTextDrainRetry(resetBackoff: true);
      return;
    }

    _isDrainingPendingTextMessages = true;
    try {
      await _recoverStaleSendingPendingTextMessages();
      await syncPendingTextMessages();
      final pendingMessages = List<LocalPendingTextMessage>.from(
        _state.pendingTextMessages,
      );
      if (pendingMessages.isEmpty) {
        _resetPendingTextDrainRetryState();
        return;
      }

      for (final pendingMessage in pendingMessages) {
        if (pendingMessage.status == LocalPendingTextMessageStatus.sending) {
          continue;
        }

        final result = await sendPendingTextMessageById(pendingMessage.id);
        if (result.isBlocked) {
          return;
        }
        if (!result.succeeded) {
          _schedulePendingTextDrainRetry();
          return;
        }
      }

      _resetPendingTextDrainRetryState();
    } finally {
      _isDrainingPendingTextMessages = false;
    }
  }

  Future<LocalPendingTextMessage> enqueuePendingTextMessage({
    required String content,
    Map<String, dynamic>? replyPayload,
    Map<String, dynamic>? productSnapshot,
  }) async {
    final pendingMessage = await _localConversationStore
        .enqueuePendingTextMessage(
          conversationId: _state.conversationId,
          productId: target.productId,
          targetUserId: target.userId,
          content: content,
          replyPayload: replyPayload,
          productSnapshot: productSnapshot,
        );
    await syncPendingTextMessages();
    return pendingMessage;
  }

  Future<String> enqueuePhotoUpload({
    required Uint8List fileBytes,
    required String fileName,
    int? width,
    int? height,
    String? mediaGroupId,
    Map<String, dynamic>? replyPayload,
  }) {
    return ChatPhotoUploadService.instance.enqueuePhotoUpload(
      target: ChatPhotoUploadTarget(
        conversationId: _state.conversationId,
        productId: target.productId,
        targetUserId: target.userId,
      ),
      fileBytes: fileBytes,
      fileName: fileName,
      width: width,
      height: height,
      mediaGroupId: mediaGroupId,
      replyPayload: replyPayload,
    );
  }

  Future<String> enqueueDocumentUpload({
    required Uint8List fileBytes,
    required String fileName,
    required int fileSizeBytes,
    String? mediaGroupId,
    Map<String, dynamic>? replyPayload,
    String? messageContent,
  }) {
    return ChatDocumentUploadService.instance.enqueueDocumentUpload(
      target: ChatDocumentUploadTarget(
        conversationId: _state.conversationId,
        productId: target.productId,
        targetUserId: target.userId,
      ),
      fileBytes: fileBytes,
      fileName: fileName,
      fileSizeBytes: fileSizeBytes,
      mediaGroupId: mediaGroupId,
      replyPayload: replyPayload,
      messageContent: messageContent,
    );
  }

  Future<ChatMutationResult> sendPendingTextMessageById(
    String pendingMessageId,
  ) async {
    final pendingMessage = await _localConversationStore.getPendingTextMessage(
      pendingMessageId,
    );
    if (pendingMessage == null) {
      return const ChatMutationResult(succeeded: false);
    }

    if (pendingMessage.status == LocalPendingTextMessageStatus.sending) {
      await syncPendingTextMessages();
      return const ChatMutationResult.success();
    }

    if (!_hasInternetConnection) {
      await _localConversationStore.markPendingTextMessageQueued(
        pendingMessageId,
        errorMessage: 'En attente de connexion...',
      );
      await syncPendingTextMessages();
      _schedulePendingTextDrainRetry(resetBackoff: true);
      return const ChatMutationResult(
        succeeded: false,
        errorMessage: 'En attente de connexion...',
      );
    }

    await _localConversationStore.markPendingTextMessageSending(
      pendingMessageId,
    );

    try {
      ignoreNextNonPendingLocalStoreChange();
      final data = (pendingMessage.productId?.isNotEmpty ?? false)
          ? await _conversationsApiService.sendProductMessage(
              productId: pendingMessage.productId!,
              content: pendingMessage.content,
              reply: pendingMessage.replyPayload,
            )
          : pendingMessage.productSnapshot != null &&
                (pendingMessage.targetUserId?.isNotEmpty ?? false)
          ? await _conversationsApiService.sendUserMessage(
              targetUserId: pendingMessage.targetUserId!,
              content: pendingMessage.content,
              reply: pendingMessage.replyPayload,
              productSnapshot: pendingMessage.productSnapshot,
            )
          : (pendingMessage.targetUserId?.isNotEmpty ?? false)
          ? await _conversationsApiService.sendUserMessage(
              targetUserId: pendingMessage.targetUserId!,
              content: pendingMessage.content,
              reply: pendingMessage.replyPayload,
            )
          : (pendingMessage.conversationId?.isNotEmpty ?? false)
          ? await _conversationsApiService.sendMessage(
              conversationId: pendingMessage.conversationId!,
              content: pendingMessage.content,
              reply: pendingMessage.replyPayload,
            )
          : throw AppApiException('Conversation introuvable pour ce message');

      _applyConversationData(data, replaceMessages: _state.messages.isEmpty);
      await _localConversationStore.removePendingTextMessage(pendingMessageId);
      await syncPendingTextMessages();
      _resetPendingTextDrainRetryState();
      return const ChatMutationResult.success();
    } on AppApiException catch (error) {
      if (_ignoredNextNonPendingLocalStoreChanges > 0) {
        _ignoredNextNonPendingLocalStoreChanges -= 1;
      }

      if (_isBlockedError(error)) {
        await _localConversationStore.removePendingTextMessage(
          pendingMessageId,
        );
      } else if (_shouldKeepPendingTextMessage(error)) {
        await _localConversationStore.markPendingTextMessageQueued(
          pendingMessageId,
          errorMessage: error.message,
        );
        _schedulePendingTextDrainRetry();
      } else {
        await _localConversationStore.markPendingTextMessageFailed(
          pendingMessageId,
          errorMessage: error.message,
        );
      }

      await syncPendingTextMessages();
      if (_isBlockedError(error)) {
        _updateState(
          _state.copyWith(conversationBlocked: true, loadError: error.message),
        );
      }

      return ChatMutationResult(
        succeeded: false,
        errorMessage: error.message,
        isBlocked: _isBlockedError(error),
      );
    }
  }

  Future<ChatMutationResult> submitMessageEdit({
    required String conversationId,
    required String messageId,
    required String content,
  }) async {
    try {
      ignoreNextNonPendingLocalStoreChange();
      final data = await _conversationsApiService.editMessage(
        conversationId: conversationId,
        messageId: messageId,
        content: content,
      );
      _applyConversationData(data, replaceMessages: _state.messages.isEmpty);
      return const ChatMutationResult.success();
    } on AppApiException catch (error) {
      if (_ignoredNextNonPendingLocalStoreChanges > 0) {
        _ignoredNextNonPendingLocalStoreChanges -= 1;
      }
      return ChatMutationResult(
        succeeded: false,
        errorMessage: error.message,
        isBlocked: _isBlockedError(error),
      );
    }
  }

  Future<ChatMutationResult> sendMediaMessage({
    required String content,
    required Map<String, dynamic> mediaPayload,
    Map<String, dynamic>? replyPayload,
  }) async {
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty) {
      return const ChatMutationResult(succeeded: false);
    }

    try {
      ignoreNextNonPendingLocalStoreChange();
      final data = (target.productId?.isNotEmpty ?? false)
          ? await _conversationsApiService.sendProductMediaMessage(
              productId: target.productId!,
              mediaPayload: {'content': trimmedContent, ...mediaPayload},
              reply: replyPayload,
            )
          : (target.userId?.isNotEmpty ?? false)
          ? await _conversationsApiService.sendUserMediaMessage(
              targetUserId: target.userId!,
              mediaPayload: {'content': trimmedContent, ...mediaPayload},
              reply: replyPayload,
            )
          : (_state.conversationId?.isNotEmpty ?? false)
          ? await _conversationsApiService.sendMediaMessage(
              conversationId: _state.conversationId!,
              mediaPayload: {'content': trimmedContent, ...mediaPayload},
              reply: replyPayload,
            )
          : throw AppApiException('Conversation introuvable pour ce media');

      _applyConversationData(data, replaceMessages: _state.messages.isEmpty);
      return const ChatMutationResult.success();
    } on AppApiException catch (error) {
      if (_ignoredNextNonPendingLocalStoreChanges > 0) {
        _ignoredNextNonPendingLocalStoreChanges -= 1;
      }
      if (_isBlockedError(error)) {
        _updateState(
          _state.copyWith(conversationBlocked: true, loadError: error.message),
        );
      }
      return ChatMutationResult(
        succeeded: false,
        errorMessage: error.message,
        isBlocked: _isBlockedError(error),
      );
    }
  }

  Future<ChatMutationResult> deleteMessages({
    required List<String> pendingIds,
    required List<String> persistedIds,
    String scope = 'FOR_EVERYONE',
    ChatMutationProgressCallback? onProgress,
  }) async {
    final totalSteps = pendingIds.length + persistedIds.length;
    var completedSteps = 0;

    void reportProgress(String statusText) {
      onProgress?.call(
        completedSteps,
        totalSteps == 0 ? 1 : totalSteps,
        statusText,
      );
    }

    reportProgress(
      totalSteps <= 1
          ? 'Preparation de la suppression...'
          : 'Preparation de la suppression des messages...',
    );

    for (final pendingId in pendingIds) {
      await _localConversationStore.removePendingTextMessage(pendingId);
      completedSteps += 1;
      reportProgress(
        'Suppression locale $completedSteps/${totalSteps == 0 ? 1 : totalSteps}',
      );
    }

    await syncPendingTextMessages();

    final conversationId = _state.conversationId?.trim() ?? '';
    if (persistedIds.isEmpty || conversationId.isEmpty) {
      return const ChatMutationResult.success();
    }

    try {
      for (final messageId in persistedIds) {
        reportProgress(
          'Suppression distante ${completedSteps + 1}/${totalSteps == 0 ? 1 : totalSteps}',
        );
        try {
          ignoreNextNonPendingLocalStoreChange();
          await _conversationsApiService.deleteMessage(
            conversationId: conversationId,
            messageId: messageId,
            scope: scope,
          );
        } on AppApiException catch (error) {
          if (_ignoredNextNonPendingLocalStoreChanges > 0) {
            _ignoredNextNonPendingLocalStoreChanges -= 1;
          }

          final message = error.message.trim().toLowerCase();
          final isMissingMessage =
              error.statusCode == 404 ||
              message.contains('message not found') ||
              message.contains('message introuvable');
          if (!isMissingMessage) {
            return ChatMutationResult(
              succeeded: false,
              errorMessage: error.message,
              isBlocked: _isBlockedError(error),
            );
          }
        }

        if (scope.trim().toUpperCase() == 'FOR_EVERYONE') {
          final nextMessages = _markMessageIdsDeletedForEveryone(
            _state.messages,
            <String>{messageId},
          );
          _replaceMessagesInState(nextMessages);

          Map<String, dynamic>? updatedMessage;
          for (final message in nextMessages) {
            final currentMessageId = message['id']?.toString().trim() ?? '';
            if (currentMessageId == messageId) {
              updatedMessage = message;
              break;
            }
          }

          if (updatedMessage != null) {
            ignoreNextNonPendingLocalStoreChange();
            await _localConversationStore.upsertMessage(
              conversationId: conversationId,
              message: updatedMessage,
              fallbackProductId: target.productId,
              fallbackUserId: target.userId,
            );
          }
        } else {
          ignoreNextNonPendingLocalStoreChange();
          await _localConversationStore.deleteMessage(
            conversationId: conversationId,
            messageId: messageId,
          );
          _removeMessageIdsFromState(<String>{messageId});
        }
        completedSteps += 1;
        reportProgress(
          'Suppression distante $completedSteps/${totalSteps == 0 ? 1 : totalSteps}',
        );
      }

      reportProgress('Reequilibrage des messages recents...');
      final recentData = await fetchConversationDisplayWindow(
        targetRawCount: math.max(
          conversationPageFetchLimit,
          _state.messages.length,
        ),
      );
      _applyConversationData(recentData, replaceMessages: true);

      return const ChatMutationResult.success();
    } on AppApiException catch (error) {
      return ChatMutationResult(
        succeeded: false,
        errorMessage: error.message,
        isBlocked: _isBlockedError(error),
      );
    }
  }

  void ignoreNextNonPendingLocalStoreChange() {
    _ignoredNextNonPendingLocalStoreChanges += 1;
  }

  @override
  void dispose() {
    _disposed = true;
    _realtimeEventsSubscription?.cancel();
    _localConversationChangesSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _conversationPollTimer?.cancel();
    _pendingTextDrainRetryTimer?.cancel();
    _realtimeDeleteReconcileTimer?.cancel();
    _realtimeNewMessageReconcileTimer?.cancel();
    super.dispose();
  }

  void _bindConnectivityMonitoring() {
    _connectivitySubscription ??= _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChanged,
    );
  }

  Future<void> _syncConnectivityState() async {
    final results = await _connectivity.checkConnectivity();
    _handleConnectivityChanged(results);
  }

  void _handleConnectivityChanged(List<ConnectivityResult> results) {
    final hasConnection = results.any(
      (result) => result != ConnectivityResult.none,
    );
    if (_hasInternetConnection == hasConnection) {
      return;
    }

    _hasInternetConnection = hasConnection;
    if (!hasConnection) {
      _pendingTextDrainRetryTimer?.cancel();
      return;
    }

    _schedulePendingTextDrainRetry(resetBackoff: true);
  }

  void _bindLocalConversationUpdates() {
    _localConversationChangesSubscription?.cancel();
    _localConversationChangesSubscription = _localConversationStore.changes
        .listen((change) {
          if (!_matchesLocalConversationChange(change)) {
            return;
          }

          if (change.includesPendingTextMessages) {
            unawaited(syncPendingTextMessages());
            return;
          }

          if (_ignoredNextNonPendingLocalStoreChanges > 0) {
            _ignoredNextNonPendingLocalStoreChanges -= 1;
            return;
          }

          unawaited(
            hydrateFromStore(
              mergeRecentMessages: true,
              limit: recentConversationMessageLimit,
            ),
          );
        });
  }

  void _bindRealtimeUpdates() {
    _realtimeService.ensureConnected();
    _realtimeEventsSubscription?.cancel();
    _realtimeEventsSubscription = _realtimeService.events.listen((event) async {
      final eventType = event['type']?.toString();
      if (eventType == ChatRealtimeService.connectedEventType) {
        _setRealtimeConnectionState(true);
        return;
      }
      if (eventType == ChatRealtimeService.disconnectedEventType) {
        _setRealtimeConnectionState(false);
        return;
      }

      final eventConversationId = event['conversationId']?.toString();
      final currentConversationId = _state.conversationId?.trim();
      if (eventConversationId != null &&
          currentConversationId != null &&
          eventConversationId != currentConversationId) {
        return;
      }

      if (_applyNonMessageRealtimeState(event)) {
        return;
      }

      if (await _applyIncrementalRealtimeConversationEvent(event)) {
        return;
      }

      unawaited(refreshSilently());
    });
  }

  bool _applyNonMessageRealtimeState(Map<String, dynamic> event) {
    if (event['type'] == 'typing:update') {
      _updateState(
        _state.copyWith(isParticipantTyping: event['isTyping'] == true),
      );
      return true;
    }

    if (event['type'] == 'profile:public-updated') {
      final conversationData = _state.conversation;
      final profileData = event['profile'];
      if (conversationData == null || profileData is! Map) {
        return true;
      }

      final nextConversation = Map<String, dynamic>.from(conversationData);
      final participantData = nextConversation['participant'];
      if (participantData is! Map) {
        return true;
      }

      final nextParticipant = Map<String, dynamic>.from(participantData);
      final profile = Map<String, dynamic>.from(profileData);
      final displayName = profile['displayName']?.toString().trim() ?? '';
      final avatarUrl = profile['avatarUrl']?.toString().trim() ?? '';
      if (displayName.isNotEmpty) {
        nextParticipant['displayName'] = displayName;
        nextParticipant['name'] = displayName;
      }
      if (avatarUrl.isNotEmpty) {
        nextParticipant['avatarUrl'] = avatarUrl;
      }
      nextConversation['participant'] = nextParticipant;
      _updateState(_state.copyWith(conversation: nextConversation));
      return true;
    }

    return false;
  }

  Future<bool> _applyIncrementalRealtimeConversationEvent(
    Map<String, dynamic> event,
  ) async {
    switch (event['type']?.toString()) {
      case 'message:new':
        final rawMessage = event['message'];
        if (rawMessage is! Map) {
          return false;
        }

        final normalizedMessage = _normalizeRealtimeMessage(
          Map<String, dynamic>.from(rawMessage),
          event,
        );

        final nextMessages = _mergeRawMessages(
          _state.messages,
          <Map<String, dynamic>>[normalizedMessage],
        );
        _updateState(
          _state.copyWith(
            messages: nextMessages,
            showEntrySkeleton: false,
            clearLoadError: true,
          ),
        );

        final conversationId = _state.conversationId?.trim() ?? '';
        if (conversationId.isEmpty) {
          return true;
        }

        ignoreNextNonPendingLocalStoreChange();
        await _localConversationStore.upsertMessage(
          conversationId: conversationId,
          message: normalizedMessage,
          fallbackProductId: target.productId,
          fallbackUserId: target.userId,
        );
        _scheduleRealtimeNewMessageReconciliation();
        return true;
      case 'conversation:read':
        final readAt = event['readAt']?.toString().trim() ?? '';
        _updateState(
          _state.copyWith(
            messages: _markAllMineSeen(_state.messages, readAt: readAt),
          ),
        );
        final conversationId = _state.conversationId?.trim() ?? '';
        if (conversationId.isNotEmpty && readAt.isNotEmpty) {
          ignoreNextNonPendingLocalStoreChange();
          await _localConversationStore.markOutgoingMessagesRead(
            conversationId: conversationId,
            readAt: readAt,
          );
        }
        return true;
      case 'message:deleted':
        final messageId = event['messageId']?.toString().trim() ?? '';
        if (messageId.isEmpty) {
          return false;
        }

        final mediaGroupId = event['mediaGroupId']?.toString().trim() ?? '';
        final messageIdsToMarkDeleted = mediaGroupId.isNotEmpty
            ? _messageIdsForMediaGroup(_state.messages, mediaGroupId)
            : <String>{messageId};
        if (kDebugMode) {
          debugPrint(
            '[ChatRealtime] message:deleted conversation=${event['conversationId']} '
            'messageId=$messageId mediaGroupId=${mediaGroupId.isEmpty ? '-' : mediaGroupId} '
            'removedCount=${messageIdsToMarkDeleted.length}',
          );
        }

        final nextMessages = _markMessageIdsDeletedForEveryone(
          _state.messages,
          messageIdsToMarkDeleted,
        );
        _replaceMessagesInState(nextMessages);
        final conversationId = _state.conversationId?.trim() ?? '';
        if (conversationId.isEmpty) {
          return true;
        }

        for (final deletedMessage in nextMessages) {
          final currentMessageId =
              deletedMessage['id']?.toString().trim() ?? '';
          if (currentMessageId.isEmpty ||
              !messageIdsToMarkDeleted.contains(currentMessageId)) {
            continue;
          }

          ignoreNextNonPendingLocalStoreChange();
          await _localConversationStore.upsertMessage(
            conversationId: conversationId,
            message: deletedMessage,
            fallbackProductId: target.productId,
            fallbackUserId: target.userId,
          );
        }
        _scheduleRealtimeDeleteReconciliation();
        return true;
      case 'conversation:delivered':
        final messageId = event['messageId']?.toString().trim() ?? '';
        if (messageId.isEmpty) {
          return false;
        }

        final deliveredAt = event['deliveredAt']?.toString().trim() ?? '';
        final effectiveDeliveredAt = deliveredAt.isNotEmpty
            ? deliveredAt
            : DateTime.now().toIso8601String();

        _updateState(
          _state.copyWith(
            messages: _markMessageDelivered(
              _state.messages,
              messageId,
              deliveredAt: effectiveDeliveredAt,
            ),
          ),
        );

        final conversationId = _state.conversationId?.trim() ?? '';
        if (conversationId.isNotEmpty) {
          ignoreNextNonPendingLocalStoreChange();
          await _localConversationStore.markMessageDelivered(
            conversationId: conversationId,
            messageId: messageId,
            deliveredAt: effectiveDeliveredAt,
          );
        }
        return true;
      default:
        return false;
    }
  }

  void _setRealtimeConnectionState(bool isConnected) {
    if (_state.isRealtimeConnected == isConnected) {
      return;
    }

    _updateState(_state.copyWith(isRealtimeConnected: isConnected));
    if (isConnected) {
      _stopConversationPolling();
      unawaited(_resumeAfterRealtimeReconnect());
      return;
    }

    _startConversationPolling();
  }

  Future<void> _resumeAfterRealtimeReconnect() async {
    await hydrateFromStore(mergeRecentMessages: true);
    await syncPendingTextMessages();
    await drainPendingTextMessages();
    _updateState(
      _state.copyWith(showEntrySkeleton: false, clearLoadError: true),
    );
  }

  void _schedulePendingTextDrainRetry({bool resetBackoff = false}) {
    if (!target.usesLiveConversation) {
      return;
    }

    if (resetBackoff) {
      _pendingTextDrainRetryAttempt = 0;
    }

    _pendingTextDrainRetryTimer?.cancel();
    final delay = _pendingTextDrainRetryAttempt == 0
        ? _pendingTextRetryBaseDelay
        : Duration(
            seconds:
                (_pendingTextRetryBaseDelay.inSeconds <<
                        _pendingTextDrainRetryAttempt)
                    .clamp(
                      _pendingTextRetryBaseDelay.inSeconds,
                      _pendingTextRetryMaxDelay.inSeconds,
                    ),
          );
    _pendingTextDrainRetryAttempt = (_pendingTextDrainRetryAttempt + 1).clamp(
      0,
      4,
    );

    _pendingTextDrainRetryTimer = Timer(delay, () {
      _pendingTextDrainRetryTimer = null;
      if (_disposed || !_hasInternetConnection) {
        return;
      }

      unawaited(drainPendingTextMessages());
    });
  }

  void _resetPendingTextDrainRetryState() {
    _pendingTextDrainRetryTimer?.cancel();
    _pendingTextDrainRetryTimer = null;
    _pendingTextDrainRetryAttempt = 0;
  }

  Future<void> _recoverStaleSendingPendingTextMessages() async {
    final pendingMessages = await _localConversationStore
        .getPendingTextMessages(
          conversationId: _state.conversationId,
          productId: target.productId,
          targetUserId: target.userId,
        );
    if (pendingMessages.isEmpty) {
      return;
    }

    final now = DateTime.now();
    var didRecoverAny = false;
    for (final pendingMessage in pendingMessages) {
      if (pendingMessage.status != LocalPendingTextMessageStatus.sending) {
        continue;
      }

      final age = now.difference(pendingMessage.updatedAt);
      if (age < _stalePendingTextSendingTimeout) {
        continue;
      }

      await _localConversationStore.markPendingTextMessageQueued(
        pendingMessage.id,
        errorMessage: 'Reprise apres interruption...',
      );
      didRecoverAny = true;
    }

    if (didRecoverAny) {
      await syncPendingTextMessages();
    }
  }

  Future<List<LocalPendingTextMessage>> _reconcilePendingTextMessages(
    List<LocalPendingTextMessage> pendingMessages,
  ) async {
    if (pendingMessages.isEmpty || _state.messages.isEmpty) {
      return pendingMessages;
    }

    final unmatchedConfirmedIndexes = <int>{
      for (var index = 0; index < _state.messages.length; index += 1) index,
    };
    final reconciledPendingMessages = <LocalPendingTextMessage>[];

    for (final pendingMessage in pendingMessages) {
      final matchingConfirmedIndex = _findMatchingConfirmedRawMessageIndex(
        pendingMessage,
        _state.messages,
        unmatchedConfirmedIndexes,
      );
      if (matchingConfirmedIndex != null) {
        unmatchedConfirmedIndexes.remove(matchingConfirmedIndex);
        await _localConversationStore.removePendingTextMessage(
          pendingMessage.id,
        );
        continue;
      }

      reconciledPendingMessages.add(pendingMessage);
    }

    return reconciledPendingMessages;
  }

  int? _findMatchingConfirmedRawMessageIndex(
    LocalPendingTextMessage pendingMessage,
    List<Map<String, dynamic>> confirmedMessages,
    Set<int> unmatchedConfirmedIndexes,
  ) {
    final pendingContent = pendingMessage.content.trim();
    if (pendingContent.isEmpty) {
      return null;
    }

    int? bestIndex;
    Duration? bestDistance;
    for (final index in unmatchedConfirmedIndexes) {
      final confirmedMessage = confirmedMessages[index];
      if (!_rawMessageMatchesPendingText(pendingMessage, confirmedMessage)) {
        continue;
      }

      final confirmedCreatedAt = DateTime.tryParse(
        confirmedMessage['createdAt']?.toString().trim() ?? '',
      );
      final distance = confirmedCreatedAt == null
          ? Duration.zero
          : confirmedCreatedAt.difference(pendingMessage.createdAt).abs();
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

  bool _rawMessageMatchesPendingText(
    LocalPendingTextMessage pendingMessage,
    Map<String, dynamic> confirmedMessage,
  ) {
    if (confirmedMessage['isMine'] != true) {
      return false;
    }

    final confirmedKind = confirmedMessage['kind']?.toString().trim() ?? 'TEXT';
    if (confirmedKind.toUpperCase() != 'TEXT') {
      return false;
    }

    final confirmedContent =
        confirmedMessage['content']?.toString().trim() ?? '';
    if (confirmedContent != pendingMessage.content.trim()) {
      return false;
    }

    final pendingReply = pendingMessage.replyPayload;
    final confirmedReplyData = confirmedMessage['reply'];
    if ((pendingReply == null) != (confirmedReplyData is Map)) {
      return false;
    }

    if (pendingReply == null) {
      return true;
    }

    final confirmedReply = Map<String, dynamic>.from(confirmedReplyData as Map);
    return (pendingReply['replyToMessageId']?.toString().trim() ?? '') ==
            (confirmedReply['messageId']?.toString().trim() ?? '') &&
        (pendingReply['replyToSenderName']?.toString().trim() ?? '') ==
            (confirmedReply['senderName']?.toString().trim() ?? '') &&
        (pendingReply['replyToContent']?.toString().trim() ?? '') ==
            (confirmedReply['content']?.toString().trim() ?? '');
  }

  void _startConversationPolling() {
    if (!conversationPollingEnabled) {
      _stopConversationPolling();
      return;
    }

    _conversationPollTimer?.cancel();
    _conversationPollTimer = Timer.periodic(
      conversationPollInterval,
      (_) => unawaited(refreshSilently()),
    );
  }

  void _stopConversationPolling() {
    _conversationPollTimer?.cancel();
    _conversationPollTimer = null;
  }

  void _scheduleRealtimeDeleteReconciliation() {
    _realtimeDeleteReconcileTimer?.cancel();
    _realtimeDeleteReconcileTimer = Timer(
      const Duration(milliseconds: 180),
      () {
        _realtimeDeleteReconcileTimer = null;
        if (_disposed) {
          return;
        }

        unawaited(_reconcileRecentConversationWindow());
      },
    );
  }

  void _scheduleRealtimeNewMessageReconciliation() {
    _realtimeNewMessageReconcileTimer?.cancel();
    _realtimeNewMessageReconcileTimer = Timer(
      const Duration(milliseconds: 120),
      () {
        _realtimeNewMessageReconcileTimer = null;
        if (_disposed) {
          return;
        }

        unawaited(_reconcileRecentConversationWindow());
      },
    );
  }

  Future<void> _reconcileRecentConversationWindow() async {
    if (_disposed || !target.usesLiveConversation) {
      return;
    }

    try {
      final data = await fetchConversationDisplayWindow(
        targetRawCount: math.max(
          conversationPageFetchLimit,
          _state.messages.length,
        ),
      );
      _applyConversationData(data, replaceMessages: true);
    } on AppApiException {
      // Keep the current UI state; polling or a later refresh can retry.
    }
  }

  bool _matchesLocalConversationChange(LocalConversationStoreChange change) {
    final currentConversationId = _state.conversationId?.trim() ?? '';
    if (currentConversationId.isNotEmpty &&
        change.conversationId == currentConversationId) {
      return true;
    }

    return change.cacheKeys.any(target.expectedCacheKeys.contains);
  }

  Map<String, dynamic> _normalizeRealtimeMessage(
    Map<String, dynamic> message,
    Map<String, dynamic> event,
  ) {
    if (message.containsKey('isMine')) {
      return message;
    }

    final actorUserId = event['actorUserId']?.toString().trim() ?? '';
    if (actorUserId.isEmpty) {
      return message;
    }

    final conversation = _state.conversation;
    final participant = conversation?['participant'];
    final participantUserId = participant is Map
        ? participant['id']?.toString().trim() ?? ''
        : (target.userId?.trim() ?? '');
    if (participantUserId.isEmpty) {
      return message;
    }

    message['isMine'] = actorUserId != participantUserId;
    return message;
  }

  Future<Map<String, dynamic>?> _fetchCachedConversationData() {
    final normalizedConversationId = target.conversationId?.trim() ?? '';
    if (normalizedConversationId.isNotEmpty) {
      return _conversationsApiService.getCachedConversationById(
        normalizedConversationId,
      );
    }

    final normalizedProductId = target.productId?.trim() ?? '';
    if (normalizedProductId.isNotEmpty) {
      return _conversationsApiService.getCachedConversationForProduct(
        normalizedProductId,
      );
    }

    final normalizedUserId = target.userId?.trim() ?? '';
    if (normalizedUserId.isNotEmpty) {
      return _conversationsApiService.getCachedConversationForUser(
        normalizedUserId,
      );
    }

    return Future.value(null);
  }

  Future<Map<String, dynamic>?> _fetchStoredConversationData({
    int? limit,
    String? beforeMessageId,
  }) {
    final normalizedConversationId =
        _state.conversationId?.trim() ?? target.conversationId?.trim() ?? '';
    if (normalizedConversationId.isNotEmpty) {
      return _conversationsApiService.getStoredConversationById(
        normalizedConversationId,
        limit: limit,
        beforeMessageId: beforeMessageId,
      );
    }

    final normalizedProductId = target.productId?.trim() ?? '';
    if (normalizedProductId.isNotEmpty) {
      return _conversationsApiService.getStoredConversationForProduct(
        normalizedProductId,
        limit: limit,
        beforeMessageId: beforeMessageId,
      );
    }

    final normalizedUserId = target.userId?.trim() ?? '';
    if (normalizedUserId.isNotEmpty) {
      return _conversationsApiService.getStoredConversationForUser(
        normalizedUserId,
        limit: limit,
        beforeMessageId: beforeMessageId,
      );
    }

    return Future.value(null);
  }

  Future<Map<String, dynamic>> _fetchConversationDataPage({
    required int limit,
    String? beforeMessageId,
  }) {
    final normalizedConversationId =
        _state.conversationId?.trim() ?? target.conversationId?.trim() ?? '';
    if (normalizedConversationId.isNotEmpty) {
      return _conversationsApiService.fetchConversationById(
        normalizedConversationId,
        limit: limit,
        beforeMessageId: beforeMessageId,
      );
    }

    final normalizedProductId = target.productId?.trim() ?? '';
    if (normalizedProductId.isNotEmpty) {
      return _conversationsApiService.fetchConversationForProduct(
        normalizedProductId,
        limit: limit,
        beforeMessageId: beforeMessageId,
      );
    }

    final normalizedUserId = target.userId?.trim() ?? '';
    if (normalizedUserId.isNotEmpty) {
      return _conversationsApiService.fetchConversationForUser(
        normalizedUserId,
        limit: limit,
        beforeMessageId: beforeMessageId,
      );
    }

    throw AppApiException('Conversation introuvable');
  }

  void _applyConversationData(
    Map<String, dynamic> data, {
    required bool replaceMessages,
  }) {
    final nextConversation = Map<String, dynamic>.from(data);
    final nextConversationId = nextConversation['id']?.toString();
    final rawMessages =
        (nextConversation['messages'] as List?)
            ?.whereType<Map>()
            .map((message) => Map<String, dynamic>.from(message))
            .toList(growable: false) ??
        const <Map<String, dynamic>>[];
    final pagination = Map<String, dynamic>.from(
      (nextConversation['pagination'] as Map?) ?? const <String, dynamic>{},
    );

    _updateState(
      _state.copyWith(
        conversationId: nextConversationId,
        conversation: nextConversation,
        messages: replaceMessages
            ? rawMessages
            : _mergeRawMessages(_state.messages, rawMessages),
        hasOlderMessages: pagination['hasOlderMessages'] == true,
        conversationBlocked: nextConversation['isBlocked'] == true,
        showEntrySkeleton: false,
        clearLoadError: true,
      ),
    );
  }

  void _applyRecentConversationWindow(Map<String, dynamic> data) {
    final nextConversation = Map<String, dynamic>.from(data);
    final nextConversationId = nextConversation['id']?.toString();
    final rawMessages =
        (nextConversation['messages'] as List?)
            ?.whereType<Map>()
            .map((message) => Map<String, dynamic>.from(message))
            .toList(growable: false) ??
        const <Map<String, dynamic>>[];
    final pagination = Map<String, dynamic>.from(
      (nextConversation['pagination'] as Map?) ?? const <String, dynamic>{},
    );

    final nextMessages = _mergeRecentRawMessages(_state.messages, rawMessages);

    _updateState(
      _state.copyWith(
        conversationId: nextConversationId,
        conversation: nextConversation,
        messages: nextMessages,
        hasOlderMessages: pagination['hasOlderMessages'] == true,
        conversationBlocked: nextConversation['isBlocked'] == true,
        showEntrySkeleton: false,
        clearLoadError: true,
      ),
    );
  }

  List<Map<String, dynamic>> _mergeRawMessages(
    List<Map<String, dynamic>> current,
    List<Map<String, dynamic>> incoming,
  ) {
    final nextById = <String, Map<String, dynamic>>{};
    for (final message in current) {
      final messageId = message['id']?.toString().trim() ?? '';
      if (messageId.isEmpty) {
        continue;
      }
      nextById[messageId] = Map<String, dynamic>.from(message);
    }

    for (final message in incoming) {
      final messageId = message['id']?.toString().trim() ?? '';
      if (messageId.isEmpty) {
        continue;
      }
      nextById[messageId] = Map<String, dynamic>.from(message);
    }

    final merged = nextById.values.toList(growable: false);
    merged.sort(_compareRawMessageOrder);
    return merged;
  }

  List<Map<String, dynamic>> _mergeRecentRawMessages(
    List<Map<String, dynamic>> current,
    List<Map<String, dynamic>> incoming,
  ) {
    if (incoming.isEmpty) {
      return current
          .map((message) => Map<String, dynamic>.from(message))
          .toList(growable: false);
    }

    final incomingSorted =
        incoming
            .map((message) => Map<String, dynamic>.from(message))
            .toList(growable: true)
          ..sort(_compareRawMessageOrder);
    final oldestIncoming = incomingSorted.first;

    final retainedOlderMessages = current
        .where(
          (message) => _compareRawMessageOrder(message, oldestIncoming) < 0,
        )
        .map((message) => Map<String, dynamic>.from(message))
        .toList(growable: false);

    final merged = <Map<String, dynamic>>[
      ...retainedOlderMessages,
      ...incomingSorted,
    ];
    merged.sort(_compareRawMessageOrder);
    return merged;
  }

  int _countDisplayMessages(List<Map<String, dynamic>> messages) {
    if (messages.isEmpty) {
      return 0;
    }

    var count = 0;
    var index = 0;
    while (index < messages.length) {
      count += 1;
      final currentGroupId = messages[index]['media'] is Map
          ? (messages[index]['media']['mediaGroupId']?.toString().trim() ?? '')
          : '';
      if (currentGroupId.isEmpty) {
        index += 1;
        continue;
      }

      index += 1;
      while (index < messages.length) {
        final nextMedia = messages[index]['media'];
        final nextGroupId = nextMedia is Map
            ? (nextMedia['mediaGroupId']?.toString().trim() ?? '')
            : '';
        if (nextGroupId != currentGroupId) {
          break;
        }
        index += 1;
      }
    }

    return count;
  }

  int _compareRawMessageOrder(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    final leftCreatedAt = left['createdAt']?.toString() ?? '';
    final rightCreatedAt = right['createdAt']?.toString() ?? '';
    final leftDate = DateTime.tryParse(leftCreatedAt);
    final rightDate = DateTime.tryParse(rightCreatedAt);
    if (leftDate == null && rightDate == null) {
      return _compareRawMessageId(left, right);
    }
    if (leftDate == null) {
      return -1;
    }
    if (rightDate == null) {
      return 1;
    }

    final dateComparison = leftDate.compareTo(rightDate);
    if (dateComparison != 0) {
      return dateComparison;
    }

    return _compareRawMessageId(left, right);
  }

  int _compareRawMessageId(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    return (left['id']?.toString() ?? '').compareTo(
      right['id']?.toString() ?? '',
    );
  }

  List<Map<String, dynamic>> _markAllMineSeen(
    List<Map<String, dynamic>> source, {
    required String? readAt,
  }) {
    final normalizedReadAt = readAt?.trim() ?? '';
    final effectiveReadAt = normalizedReadAt.isNotEmpty
        ? normalizedReadAt
        : DateTime.now().toIso8601String();

    return source
        .map((message) {
          final nextMessage = Map<String, dynamic>.from(message);
          if (nextMessage['isMine'] == true) {
            nextMessage['readAt'] ??= effectiveReadAt;
          }
          return nextMessage;
        })
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _markMessageDelivered(
    List<Map<String, dynamic>> source,
    String messageId, {
    required String deliveredAt,
  }) {
    final effectiveDeliveredAt = deliveredAt.trim().isNotEmpty
        ? deliveredAt.trim()
        : DateTime.now().toIso8601String();

    return source
        .map((message) {
          final currentMessageId = message['id']?.toString().trim() ?? '';
          if (currentMessageId != messageId) {
            return message;
          }

          final nextMessage = Map<String, dynamic>.from(message);
          nextMessage['deliveredAt'] ??= effectiveDeliveredAt;
          return nextMessage;
        })
        .toList(growable: false);
  }

  void _removeMessageIdsFromState(Set<String> messageIds) {
    if (messageIds.isEmpty) {
      return;
    }

    final nextMessages = _state.messages
        .where((message) {
          final messageId = message['id']?.toString().trim() ?? '';
          return messageId.isEmpty || !messageIds.contains(messageId);
        })
        .map((message) => Map<String, dynamic>.from(message))
        .toList(growable: false);

    final currentConversation = _state.conversation;
    final nextConversation = currentConversation == null
        ? null
        : (Map<String, dynamic>.from(currentConversation)
            ..['messages'] = nextMessages);

    _updateState(
      _state.copyWith(
        conversation: nextConversation,
        messages: nextMessages,
        showEntrySkeleton: false,
        clearLoadError: true,
      ),
    );
  }

  void _replaceMessagesInState(List<Map<String, dynamic>> nextMessages) {
    final currentConversation = _state.conversation;
    final nextConversation = currentConversation == null
        ? null
        : (Map<String, dynamic>.from(currentConversation)
            ..['messages'] = nextMessages);

    _updateState(
      _state.copyWith(
        conversation: nextConversation,
        messages: nextMessages,
        showEntrySkeleton: false,
        clearLoadError: true,
      ),
    );
  }

  List<Map<String, dynamic>> _markMessageIdsDeletedForEveryone(
    List<Map<String, dynamic>> source,
    Set<String> messageIds,
  ) {
    return source
        .map((message) {
          final messageId = message['id']?.toString().trim() ?? '';
          if (messageId.isEmpty || !messageIds.contains(messageId)) {
            return Map<String, dynamic>.from(message);
          }

          final nextMessage = Map<String, dynamic>.from(message);
          nextMessage['content'] = _deletedMessagePlaceholder;
          nextMessage['kind'] = 'TEXT';
          nextMessage['reply'] = null;
          nextMessage['media'] = null;
          nextMessage['product'] = null;
          return nextMessage;
        })
        .toList(growable: false);
  }

  Set<String> _messageIdsForMediaGroup(
    List<Map<String, dynamic>> source,
    String mediaGroupId,
  ) {
    final normalizedMediaGroupId = mediaGroupId.trim();
    if (normalizedMediaGroupId.isEmpty) {
      return const <String>{};
    }

    return source
        .where((message) {
          final media = message['media'];
          if (media is! Map) {
            return false;
          }

          final currentGroupId = media['mediaGroupId']?.toString().trim() ?? '';
          return currentGroupId == normalizedMediaGroupId;
        })
        .map((message) => message['id']?.toString().trim() ?? '')
        .where((messageId) => messageId.isNotEmpty)
        .toSet();
  }

  void _updateState(ChatSessionState nextState) {
    if (_disposed) {
      return;
    }

    if (_chatSessionStatesEqual(_state, nextState)) {
      return;
    }

    _state = nextState;
    notifyListeners();
  }

  bool _chatSessionStatesEqual(ChatSessionState left, ChatSessionState right) {
    return left.targetSessionKey == right.targetSessionKey &&
        left.conversationId == right.conversationId &&
        left.showEntrySkeleton == right.showEntrySkeleton &&
        left.isRefreshing == right.isRefreshing &&
        left.isRealtimeConnected == right.isRealtimeConnected &&
        left.isParticipantTyping == right.isParticipantTyping &&
        left.isLoadingOlderMessages == right.isLoadingOlderMessages &&
        left.hasOlderMessages == right.hasOlderMessages &&
        left.conversationBlocked == right.conversationBlocked &&
        left.loadError == right.loadError &&
        _deepEquals(left.conversation, right.conversation) &&
        _listDeepEquals(left.messages, right.messages) &&
        _pendingTextMessagesEqual(
          left.pendingTextMessages,
          right.pendingTextMessages,
        );
  }

  bool _pendingTextMessagesEqual(
    List<LocalPendingTextMessage> left,
    List<LocalPendingTextMessage> right,
  ) {
    if (identical(left, right)) {
      return true;
    }
    if (left.length != right.length) {
      return false;
    }

    for (var index = 0; index < left.length; index += 1) {
      final leftItem = left[index];
      final rightItem = right[index];
      if (leftItem.id != rightItem.id ||
          leftItem.conversationId != rightItem.conversationId ||
          leftItem.productId != rightItem.productId ||
          leftItem.targetUserId != rightItem.targetUserId ||
          leftItem.content != rightItem.content ||
          leftItem.status != rightItem.status ||
          leftItem.createdAt != rightItem.createdAt ||
          leftItem.updatedAt != rightItem.updatedAt ||
          leftItem.errorMessage != rightItem.errorMessage ||
          !_deepEquals(leftItem.replyPayload, rightItem.replyPayload) ||
          !_deepEquals(leftItem.productSnapshot, rightItem.productSnapshot)) {
        return false;
      }
    }

    return true;
  }

  bool _listDeepEquals(List<dynamic> left, List<dynamic> right) {
    if (identical(left, right)) {
      return true;
    }
    if (left.length != right.length) {
      return false;
    }

    for (var index = 0; index < left.length; index += 1) {
      if (!_deepEquals(left[index], right[index])) {
        return false;
      }
    }

    return true;
  }

  bool _deepEquals(dynamic left, dynamic right) {
    if (identical(left, right)) {
      return true;
    }
    if (left == null || right == null) {
      return left == right;
    }
    if (left is Map && right is Map) {
      if (left.length != right.length) {
        return false;
      }

      for (final key in left.keys) {
        if (!right.containsKey(key) || !_deepEquals(left[key], right[key])) {
          return false;
        }
      }

      return true;
    }
    if (left is List && right is List) {
      return _listDeepEquals(left, right);
    }

    return left == right;
  }

  bool _shouldKeepPendingTextMessage(AppApiException error) {
    final statusCode = error.statusCode;
    return statusCode == null ||
        statusCode >= 500 ||
        statusCode == 408 ||
        statusCode == 429;
  }

  bool _isBlockedError(AppApiException error) {
    if (error.statusCode != 403) {
      return false;
    }

    final message = error.message.trim().toLowerCase();
    return message.contains('bloqu') ||
        message.contains('blocked') ||
        message.contains('forbidden');
  }
}
