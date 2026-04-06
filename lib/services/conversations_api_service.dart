import 'app_api_client.dart';

class ConversationsApiService {
  ConversationsApiService({AppApiClient? client})
    : _client = client ?? AppApiClient();

  final AppApiClient _client;

  Future<List<Map<String, dynamic>>> fetchConversations() async {
    final data = await _client.get('/conversations', authenticated: true);
    return (data as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> fetchConversationById(
    String conversationId,
  ) async {
    final data = await _client.get(
      '/conversations/$conversationId',
      authenticated: true,
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> fetchConversationForProduct(
    String productId,
  ) async {
    final data = await _client.get(
      '/conversations/product/$productId',
      authenticated: true,
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> fetchConversationForUser(
    String targetUserId,
  ) async {
    final data = await _client.get(
      '/conversations/user/$targetUserId',
      authenticated: true,
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required String content,
  }) async {
    final data = await _client.post(
      '/conversations/$conversationId/messages',
      body: {'content': content},
      authenticated: true,
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> sendProductMessage({
    required String productId,
    required String content,
  }) async {
    final data = await _client.post(
      '/conversations/product/$productId/messages',
      body: {'content': content},
      authenticated: true,
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> sendUserMessage({
    required String targetUserId,
    required String content,
    Map<String, dynamic>? productSnapshot,
  }) async {
    final data = await _client.post(
      '/conversations/user/$targetUserId/messages',
      body: {
        'content': content,
        if (productSnapshot != null) ...productSnapshot,
      },
      authenticated: true,
    );
    return Map<String, dynamic>.from(data as Map);
  }
}
