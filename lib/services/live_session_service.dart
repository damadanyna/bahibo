import 'package:flutter/foundation.dart';

class LiveSessionData {
  const LiveSessionData({
    required this.sellerProfileId,
    required this.title,
    required this.category,
    required this.sellerName,
    required this.sellerAvatarUrl,
    required this.startedAt,
  });

  final String sellerProfileId;
  final String title;
  final String category;
  final String sellerName;
  final String sellerAvatarUrl;
  final DateTime startedAt;

  Map<String, dynamic> toMap() {
    return {
      'sellerProfileId': sellerProfileId,
      'liveTitle': title,
      'liveCategory': category,
      'liveSellerName': sellerName,
      'liveSellerAvatarUrl': sellerAvatarUrl,
      'liveStartedAt': startedAt.toIso8601String(),
      'isLive': true,
    };
  }
}

class LiveSessionService {
  LiveSessionService._();

  static final LiveSessionService instance = LiveSessionService._();

  final ValueNotifier<int> changes = ValueNotifier<int>(0);
  final Map<String, LiveSessionData> _activeSessions = {};

  LiveSessionData? sessionForSeller(String sellerProfileId) {
    final normalizedId = sellerProfileId.trim();
    if (normalizedId.isEmpty) {
      return null;
    }

    return _activeSessions[normalizedId];
  }

  bool isSellerLive(String sellerProfileId) {
    return sessionForSeller(sellerProfileId) != null;
  }

  void startSession(LiveSessionData session) {
    _activeSessions[session.sellerProfileId.trim()] = session;
    changes.value++;
  }

  void endSession(String sellerProfileId) {
    final normalizedId = sellerProfileId.trim();
    if (normalizedId.isEmpty) {
      return;
    }

    if (_activeSessions.remove(normalizedId) != null) {
      changes.value++;
    }
  }
}
