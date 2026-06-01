import 'package:flutter/foundation.dart';
import 'dart:convert';

import 'app_api_client.dart';

class NotificationsApiService {
  NotificationsApiService({AppApiClient? client})
    : _client = client ?? AppApiClient();

  final AppApiClient _client;

  // Global reactive counter — listened to by the navigation shell badge.
  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  static void syncUnreadCount(List<Map<String, dynamic>> notifications) {
    unreadCountNotifier.value = notifications
        .where((n) => n['unread'] == true)
        .length;
  }

  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    final data = await _client.get('/notifications', authenticated: true);
    final notifications = (data as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where(
          (map) =>
              (map['type']?.toString().trim().toLowerCase() ?? '') !=
              'user_feedback',
        )
        .map((map) {
          final seller = Map<String, dynamic>.from(
            (map['seller'] as Map?) ?? const <String, dynamic>{},
          );
          final product = Map<String, dynamic>.from(
            (map['product'] as Map?) ?? const <String, dynamic>{},
          );
          final sellerProfile = Map<String, dynamic>.from(
            (map['sellerProfile'] as Map?) ?? const <String, dynamic>{},
          );
          final actors = ((map['actors'] as List?) ?? const [])
              .whereType<Map>()
              .map((actor) => Map<String, dynamic>.from(actor))
              .toList();

          return {
            'section': map['isRead'] == true ? 'Lues' : 'Non lues',
            'id': map['id'],
            'type': map['type'],
            'title': map['title'],
            'channel': seller['name'] ?? 'BANAY',
            'description': map['body'],
            'content': map['body'],
            'productName': product['title'],
            'time': map['createdAt'],
            'avatarUrl': seller['avatarUrl'],
            'thumbnailUrl': product['imageUrl'],
            'productId': product['id'],
            'sellerProfileId': sellerProfile['id'] ?? seller['id'],
            'likeCount': map['likeCount'] ?? 0,
            'commentCount': map['commentCount'] ?? 0,
            'actors': actors,
            'unread': !(map['isRead'] == true),
          };
        })
        .toList();
    syncUnreadCount(notifications);
    return notifications;
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await _client.post(
      '/notifications/$notificationId/read',
      authenticated: true,
    );
  }

  Future<void> sendFeedback(String message) async {
    await _client.post(
      '/notifications/feedback',
      authenticated: true,
      body: {'message': message},
    );
  }

  Future<void> sendQaLogExport(Map<String, dynamic> payload) async {
    await _client.post(
      '/notifications/feedback',
      authenticated: true,
      body: {'message': 'QA_LOG_EXPORT\n${jsonEncode(payload)}'},
    );
  }
}
