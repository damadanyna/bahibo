class ChatSessionTarget {
  const ChatSessionTarget({this.conversationId, this.productId, this.userId});

  final String? conversationId;
  final String? productId;
  final String? userId;

  bool get usesLiveConversation {
    return (conversationId?.trim().isNotEmpty ?? false) ||
        (productId?.trim().isNotEmpty ?? false) ||
        (userId?.trim().isNotEmpty ?? false);
  }

  String get sessionKey {
    final normalizedConversationId = conversationId?.trim() ?? '';
    if (normalizedConversationId.isNotEmpty) {
      return 'conversation:$normalizedConversationId';
    }

    final normalizedProductId = productId?.trim() ?? '';
    if (normalizedProductId.isNotEmpty) {
      return 'product:$normalizedProductId';
    }

    final normalizedUserId = userId?.trim() ?? '';
    if (normalizedUserId.isNotEmpty) {
      return 'user:$normalizedUserId';
    }

    return 'conversation:unknown';
  }

  Set<String> get expectedCacheKeys {
    final keys = <String>{};

    final normalizedConversationId = conversationId?.trim() ?? '';
    if (normalizedConversationId.isNotEmpty) {
      keys.add('id:$normalizedConversationId');
    }

    final normalizedProductId = productId?.trim() ?? '';
    if (normalizedProductId.isNotEmpty) {
      keys.add('product:$normalizedProductId');
    }

    final normalizedUserId = userId?.trim() ?? '';
    if (normalizedUserId.isNotEmpty) {
      keys.add('user:$normalizedUserId');
    }

    return keys;
  }
}
