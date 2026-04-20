import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'app_api_client.dart';
import 'api_config.dart';
import 'session_storage.dart';

class CatalogApiService {
  CatalogApiService({AppApiClient? client})
    : _client = client ?? AppApiClient();

  final AppApiClient _client;
  final SessionStorage _sessionStorage = SessionStorage();

  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final data = await _client.get('/categories');
    return (data as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> fetchProducts({
    required int limit,
    required int skip,
    String? categorySlug,
  }) async {
    final data = await _client.get(
      '/products',
      queryParameters: {
        'limit': '$limit',
        'skip': '$skip',
        if (categorySlug != null && categorySlug.isNotEmpty)
          'categorySlug': categorySlug,
      },
    );

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> fetchProductById(String productId) async {
    final data = await _client.get('/products/$productId');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> fetchSellerProfile(
    String sellerProfileId,
  ) async {
    final hasValidSession = await _sessionStorage.hasValidSession();
    final data = await _client.get(
      hasValidSession
          ? '/profiles/sellers/$sellerProfileId/viewer'
          : '/profiles/sellers/$sellerProfileId',
      authenticated: hasValidSession,
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> fetchUserProfile(String userId) async {
    final data = await _client.get('/profiles/users/$userId');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> reportUser(
    String userId, {
    String? conversationId,
    String? reason,
    String? details,
    bool blockUser = false,
  }) async {
    final data = await _client.post(
      '/profiles/users/$userId/report',
      authenticated: true,
      body: {
        if (conversationId != null && conversationId.trim().isNotEmpty)
          'conversationId': conversationId.trim(),
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        if (details != null && details.trim().isNotEmpty)
          'details': details.trim(),
        'blockUser': blockUser,
      },
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> fetchUsersPresence(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    final data = await _client.get(
      '/profiles/presence',
      authenticated: true,
      queryParameters: {
        'userIds': userIds
            .map((userId) => userId.trim())
            .where((userId) => userId.isNotEmpty)
            .join(','),
      },
    );

    return (data as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> followSeller(String sellerProfileId) async {
    final data = await _client.post(
      '/profiles/sellers/$sellerProfileId/follow',
      authenticated: true,
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> unfollowSeller(String sellerProfileId) async {
    final data = await _client.post(
      '/profiles/sellers/$sellerProfileId/unfollow',
      authenticated: true,
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> recordSellerView(String sellerProfileId) async {
    final data = await _client.post(
      '/profiles/sellers/$sellerProfileId/view',
      authenticated: true,
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> fetchSellerFollowers(
    String sellerProfileId,
  ) async {
    final data = await _client.get(
      '/profiles/sellers/$sellerProfileId/followers',
      authenticated: true,
    );
    return (data as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchCurrentUserFollowing() async {
    final data = await _client.get(
      '/profiles/me/following',
      authenticated: true,
    );
    return (data as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> startCurrentUserLive({
    required String title,
    required String category,
  }) async {
    final data = await _client.post(
      '/profiles/me/live/start',
      authenticated: true,
      body: {'title': title, 'category': category},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> stopCurrentUserLive() async {
    final data = await _client.post(
      '/profiles/me/live/stop',
      authenticated: true,
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> fetchSellerLiveJoinInfo(
    String sellerProfileId,
  ) async {
    final data = await _client.get(
      '/profiles/sellers/$sellerProfileId/live/join',
      authenticated: true,
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> fetchSellerProfileViews(
    String sellerProfileId,
  ) async {
    final data = await _client.get(
      '/profiles/sellers/$sellerProfileId/views',
      authenticated: true,
    );
    return (data as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchSellerLikeUsers(
    String sellerProfileId,
  ) async {
    final data = await _client.get(
      '/profiles/sellers/$sellerProfileId/likes',
      authenticated: true,
    );
    return (data as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> likeProduct(String productId) async {
    final data = await _client.post(
      '/products/$productId/like',
      authenticated: true,
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> unlikeProduct(String productId) async {
    final data = await _client.post(
      '/products/$productId/unlike',
      authenticated: true,
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<bool> hasLikedProduct(String productId) async {
    final hasSession = await _sessionStorage.hasValidSession();
    if (!hasSession) {
      return false;
    }

    final data = await _client.get(
      '/products/$productId/liked',
      authenticated: true,
    );

    final payload = Map<String, dynamic>.from(data as Map);
    return payload['isLiked'] == true;
  }

  Future<List<Map<String, dynamic>>> fetchProductComments(
    String productId,
  ) async {
    final data = await _client.get('/products/$productId/comments');
    return (data as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> addProductComment({
    required String productId,
    required String content,
    String? parentCommentId,
    List<String> mentionUserIds = const <String>[],
  }) async {
    final data = await _client.post(
      '/products/$productId/comments',
      body: {
        'content': content,
        if (parentCommentId != null && parentCommentId.trim().isNotEmpty)
          'parentCommentId': parentCommentId.trim(),
        if (mentionUserIds.isNotEmpty) 'mentionUserIds': mentionUserIds,
      },
      authenticated: true,
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> shareProduct(String productId) async {
    final data = await _client.post(
      '/products/$productId/share',
      authenticated: true,
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> createProduct({
    required String title,
    required String description,
    required num priceAmount,
    required String categoryName,
    required List<File> imageFiles,
    required List<String> imageOrder,
    String currencyCode = 'MGA',
  }) async {
    final accessToken = await _sessionStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw AppApiException('Session utilisateur introuvable');
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/products');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..fields['title'] = title
      ..fields['description'] = description
      ..fields['priceAmount'] = '$priceAmount'
      ..fields['currencyCode'] = currencyCode
      ..fields['categoryName'] = categoryName
      ..fields['imageOrderJson'] = jsonEncode(imageOrder);

    for (final imageFile in imageFiles) {
      request.files.add(
        await http.MultipartFile.fromPath('images', imageFile.path),
      );
    }

    http.StreamedResponse streamedResponse;

    try {
      streamedResponse = await request.send();
    } catch (_) {
      throw AppApiException('Impossible de joindre le serveur Bahibo');
    }

    final response = await http.Response.fromStream(streamedResponse);
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = (decoded['message'] as String?) ?? 'Erreur serveur';
      throw AppApiException(message, statusCode: response.statusCode);
    }

    return Map<String, dynamic>.from(
      (decoded['data'] as Map?) ?? const <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> updateProduct({
    required String productId,
    required String title,
    required String description,
    required num priceAmount,
    required String categoryName,
    required List<File> imageFiles,
    required List<String> imageOrder,
    bool? isAvailable,
    String currencyCode = 'MGA',
  }) async {
    final accessToken = await _sessionStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw AppApiException('Session utilisateur introuvable');
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/products/$productId');
    final request = http.MultipartRequest('PATCH', uri)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..fields['title'] = title
      ..fields['description'] = description
      ..fields['priceAmount'] = '$priceAmount'
      ..fields['currencyCode'] = currencyCode
      ..fields['categoryName'] = categoryName
      ..fields['imageOrderJson'] = jsonEncode(imageOrder);

    if (isAvailable != null) {
      request.fields['isAvailable'] = '$isAvailable';
    }

    for (final imageFile in imageFiles) {
      request.files.add(
        await http.MultipartFile.fromPath('images', imageFile.path),
      );
    }

    http.StreamedResponse streamedResponse;

    try {
      streamedResponse = await request.send();
    } catch (_) {
      throw AppApiException('Impossible de joindre le serveur Bahibo');
    }

    final response = await http.Response.fromStream(streamedResponse);
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = (decoded['message'] as String?) ?? 'Erreur serveur';
      throw AppApiException(message, statusCode: response.statusCode);
    }

    return Map<String, dynamic>.from(
      (decoded['data'] as Map?) ?? const <String, dynamic>{},
    );
  }
}
