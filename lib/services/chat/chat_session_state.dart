import 'package:banay/services/local_conversation_store.dart';

class ChatSessionState {
  const ChatSessionState({
    required this.targetSessionKey,
    this.conversationId,
    this.conversation,
    this.messages = const <Map<String, dynamic>>[],
    this.pendingTextMessages = const <LocalPendingTextMessage>[],
    this.showEntrySkeleton = true,
    this.isRefreshing = false,
    this.isRealtimeConnected = false,
    this.isParticipantTyping = false,
    this.isLoadingOlderMessages = false,
    this.hasOlderMessages = false,
    this.conversationBlocked = false,
    this.loadError,
  });

  final String targetSessionKey;
  final String? conversationId;
  final Map<String, dynamic>? conversation;
  final List<Map<String, dynamic>> messages;
  final List<LocalPendingTextMessage> pendingTextMessages;
  final bool showEntrySkeleton;
  final bool isRefreshing;
  final bool isRealtimeConnected;
  final bool isParticipantTyping;
  final bool isLoadingOlderMessages;
  final bool hasOlderMessages;
  final bool conversationBlocked;
  final String? loadError;

  factory ChatSessionState.initial({required String targetSessionKey}) {
    return ChatSessionState(targetSessionKey: targetSessionKey);
  }

  ChatSessionState copyWith({
    String? conversationId,
    Map<String, dynamic>? conversation,
    bool clearConversation = false,
    List<Map<String, dynamic>>? messages,
    List<LocalPendingTextMessage>? pendingTextMessages,
    bool? showEntrySkeleton,
    bool? isRefreshing,
    bool? isRealtimeConnected,
    bool? isParticipantTyping,
    bool? isLoadingOlderMessages,
    bool? hasOlderMessages,
    bool? conversationBlocked,
    String? loadError,
    bool clearLoadError = false,
  }) {
    return ChatSessionState(
      targetSessionKey: targetSessionKey,
      conversationId: conversationId ?? this.conversationId,
      conversation: clearConversation
          ? null
          : (conversation ?? this.conversation),
      messages: messages ?? this.messages,
      pendingTextMessages: pendingTextMessages ?? this.pendingTextMessages,
      showEntrySkeleton: showEntrySkeleton ?? this.showEntrySkeleton,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isRealtimeConnected: isRealtimeConnected ?? this.isRealtimeConnected,
      isParticipantTyping: isParticipantTyping ?? this.isParticipantTyping,
      isLoadingOlderMessages:
          isLoadingOlderMessages ?? this.isLoadingOlderMessages,
      hasOlderMessages: hasOlderMessages ?? this.hasOlderMessages,
      conversationBlocked: conversationBlocked ?? this.conversationBlocked,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
    );
  }
}
