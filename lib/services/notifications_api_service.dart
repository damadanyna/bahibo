import 'app_api_client.dart';

class NotificationsApiService {
  NotificationsApiService({AppApiClient? client})
    : _client = client ?? AppApiClient();

  final AppApiClient _client;

  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    final data = await _client.get('/notifications');
    return (data as List).whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      return {
        'section': map['isRead'] == true ? 'Aujourd\'hui' : 'Important',
        'type': map['type'],
        'channel': (map['seller'] as Map?)?['name'] ?? 'Bahibo',
        'description': map['body'],
        'content': map['body'],
        'productName': (map['product'] as Map?)?['title'],
        'time': map['createdAt'],
        'avatarUrl': (map['seller'] as Map?)?['avatarUrl'],
        'thumbnailUrl': (map['product'] as Map?)?['imageUrl'],
        'unread': !(map['isRead'] == true),
      };
    }).toList();
  }
}
