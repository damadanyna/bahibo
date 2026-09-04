import 'package:banay/services/conversations_api_service.dart';

/// Shared helpers for any "pick a conversation to send something to" UI
/// (outbound share sheet, inbound OS share target picker).

String? conversationShareId(Map<String, dynamic> conversation) {
  final value = conversation['id'];
  if (value == null) {
    return null;
  }

  final normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}

String? conversationShareParticipantId(Map<String, dynamic> conversation) {
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

String conversationShareName(Map<String, dynamic> conversation) {
  final participant = conversation['participant'];
  if (participant is Map) {
    final value = participant['displayName'];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }

  return 'Conversation';
}

String conversationShareAvatar(Map<String, dynamic> conversation) {
  final participant = conversation['participant'];
  if (participant is Map) {
    final value = participant['avatarUrl'];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }

  return '';
}

DateTime? _conversationShareLastMessageDate(Map<String, dynamic> conversation) {
  final value = conversation['lastMessageAt'];
  if (value is! String || value.trim().isEmpty) {
    return null;
  }

  return DateTime.tryParse(value)?.toLocal();
}

/// One row per person to share with: collapses every conversation record
/// with the same participant into the most recently active one.
List<Map<String, dynamic>> groupConversationsForSharing(
  List<Map<String, dynamic>> conversations,
) {
  final grouped = <String, Map<String, dynamic>>{};

  for (final conversation in conversations) {
    final participantId = conversationShareParticipantId(conversation);
    final conversationId = conversationShareId(conversation);
    final groupKey = participantId ?? conversationId;

    if (groupKey == null) {
      continue;
    }

    final existing = grouped[groupKey];
    if (existing == null) {
      grouped[groupKey] = Map<String, dynamic>.from(conversation);
      continue;
    }

    final existingDate = _conversationShareLastMessageDate(existing);
    final currentDate = _conversationShareLastMessageDate(conversation);
    final useCurrentConversation =
        existingDate == null ||
        (currentDate != null && currentDate.isAfter(existingDate));

    grouped[groupKey] = Map<String, dynamic>.from(
      useCurrentConversation ? conversation : existing,
    );
  }

  final groupedList = grouped.values.toList(growable: false);
  groupedList.sort((first, second) {
    final firstDate = _conversationShareLastMessageDate(first);
    final secondDate = _conversationShareLastMessageDate(second);
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

Future<List<Map<String, dynamic>>> loadConversationsForSharing(
  ConversationsApiService conversationsApiService,
) async {
  final cachedConversations = await conversationsApiService
      .getCachedConversations();
  if (cachedConversations != null && cachedConversations.isNotEmpty) {
    return groupConversationsForSharing(cachedConversations);
  }

  final conversations = await conversationsApiService.fetchConversations();
  return groupConversationsForSharing(conversations);
}
