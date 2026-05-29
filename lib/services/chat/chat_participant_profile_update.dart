Map<String, dynamic>? mergeConversationParticipantProfileUpdate(
  Map<String, dynamic>? conversation, {
  required String userId,
  String? displayName,
  String? avatarUrl,
  String? coverImageUrl,
  String? role,
}) {
  if (conversation == null) {
    return null;
  }

  final normalizedUserId = userId.trim();
  if (normalizedUserId.isEmpty) {
    return null;
  }

  final participant = conversation['participant'];
  if (participant is! Map) {
    return null;
  }

  final nextParticipant = Map<String, dynamic>.from(participant);
  final participantId = nextParticipant['id']?.toString().trim() ?? '';
  if (participantId.isEmpty || participantId != normalizedUserId) {
    return null;
  }

  var hasChanged = false;
  final normalizedDisplayName = displayName?.trim() ?? '';
  if (normalizedDisplayName.isNotEmpty) {
    nextParticipant['displayName'] = normalizedDisplayName;
    nextParticipant['name'] = normalizedDisplayName;
    hasChanged = true;
  }

  final normalizedAvatarUrl = avatarUrl?.trim() ?? '';
  if (normalizedAvatarUrl.isNotEmpty) {
    nextParticipant['avatarUrl'] = normalizedAvatarUrl;
    hasChanged = true;
  }

  final normalizedCoverImageUrl = coverImageUrl?.trim() ?? '';
  if (normalizedCoverImageUrl.isNotEmpty) {
    nextParticipant['coverImageUrl'] = normalizedCoverImageUrl;
    hasChanged = true;
  }

  final normalizedRole = role?.trim() ?? '';
  if (normalizedRole.isNotEmpty) {
    nextParticipant['role'] = normalizedRole;
    hasChanged = true;
  }

  if (!hasChanged) {
    return null;
  }

  final nextConversation = Map<String, dynamic>.from(conversation);
  nextConversation['participant'] = nextParticipant;
  return nextConversation;
}
