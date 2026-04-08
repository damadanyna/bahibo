import 'app_api_client.dart';

class NotificationsApiService {
  NotificationsApiService({AppApiClient? client})
    : _client = client ?? AppApiClient();

  final AppApiClient _client;

  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    final data = await _client.get('/notifications', authenticated: true);
    return (data as List).whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
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
        'section': map['isRead'] == true ? 'Aujourd\'hui' : 'Important',
        'id': map['id'],
        'type': map['type'],
        'title': map['title'],
        'channel': seller['name'] ?? 'Bahibo',
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
    }).toList();
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await _client.post(
      '/notifications/$notificationId/read',
      authenticated: true,
    );
  }
}
