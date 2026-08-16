import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'app_api_client.dart';
import 'api_config.dart';
import 'session_storage.dart';

class ProductUploadProgressInfo {
  const ProductUploadProgressInfo({
    required this.imageCount,
    required this.currentImageIndex,
    required this.currentImageBytesSent,
    required this.currentImageTotalBytes,
    required this.totalImageBytesSent,
    required this.totalImageBytes,
  });

  final int imageCount;
  final int currentImageIndex;
  final int currentImageBytesSent;
  final int currentImageTotalBytes;
  final int totalImageBytesSent;
  final int totalImageBytes;

  double get overallProgress {
    if (totalImageBytes <= 0) {
      return 0;
    }
    return (totalImageBytesSent / totalImageBytes).clamp(0.0, 1.0);
  }

  double get currentImageProgress {
    if (currentImageTotalBytes <= 0) {
      return 0;
    }
    return (currentImageBytesSent / currentImageTotalBytes).clamp(0.0, 1.0);
  }
}

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
    String? userLocationLabel,
    double? userLocationLatitude,
    double? userLocationLongitude,
  }) async {
    final data = await _client.get(
      '/products',
      queryParameters: {
        'limit': '$limit',
        'skip': '$skip',
        if (categorySlug != null && categorySlug.isNotEmpty)
          'categorySlug': categorySlug,
        if (userLocationLabel != null && userLocationLabel.trim().isNotEmpty)
          'userLocationLabel': userLocationLabel.trim(),
        if (userLocationLatitude != null)
          'userLocationLatitude': '$userLocationLatitude',
        if (userLocationLongitude != null)
          'userLocationLongitude': '$userLocationLongitude',
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
    final hasValidSession = await _sessionStorage.hasValidSession();
    final data = await _client.get(
      hasValidSession
          ? '/profiles/users/$userId/viewer'
          : '/profiles/users/$userId',
      authenticated: hasValidSession,
    );
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

  Future<Map<String, dynamic>> blockUser(
    String userId, {
    String? conversationId,
  }) async {
    final data = await _client.post(
      '/profiles/users/$userId/block',
      authenticated: true,
      body: {
        if (conversationId != null && conversationId.trim().isNotEmpty)
          'conversationId': conversationId.trim(),
      },
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> unblockUser(String userId) async {
    final data = await _client.delete(
      '/profiles/users/$userId/block',
      authenticated: true,
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

  Future<List<Map<String, dynamic>>> fetchCurrentUserReports() async {
    final data = await _client.get('/profiles/me/reports', authenticated: true);
    return (data as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchCurrentUserBlockedUsers() async {
    final data = await _client.get(
      '/profiles/me/blocked-users',
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
    String? condition,
    bool? hasWarranty,
    int? warrantyDurationValue,
    String? warrantyDurationUnit,
    void Function(ProductUploadProgressInfo progress)? onUploadProgress,
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

    _applyProductConditionAndWarrantyFields(
      request,
      condition: condition,
      hasWarranty: hasWarranty,
      warrantyDurationValue: warrantyDurationValue,
      warrantyDurationUnit: warrantyDurationUnit,
    );

    request.files.addAll(
      await _buildTrackedMultipartFiles(
        imageFiles,
        onUploadProgress: onUploadProgress,
      ),
    );

    final response = await _sendMultipartRequest(request);
    return _parseMultipartResponse(response);
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
    String? condition,
    bool? hasWarranty,
    int? warrantyDurationValue,
    String? warrantyDurationUnit,
    void Function(ProductUploadProgressInfo progress)? onUploadProgress,
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

    _applyProductConditionAndWarrantyFields(
      request,
      condition: condition,
      hasWarranty: hasWarranty,
      warrantyDurationValue: warrantyDurationValue,
      warrantyDurationUnit: warrantyDurationUnit,
    );

    request.files.addAll(
      await _buildTrackedMultipartFiles(
        imageFiles,
        onUploadProgress: onUploadProgress,
      ),
    );

    final response = await _sendMultipartRequest(request);
    return _parseMultipartResponse(response);
  }

  void _applyProductConditionAndWarrantyFields(
    http.MultipartRequest request, {
    String? condition,
    bool? hasWarranty,
    int? warrantyDurationValue,
    String? warrantyDurationUnit,
  }) {
    if (condition != null && condition.trim().isNotEmpty) {
      request.fields['condition'] = condition.trim();
    }
    if (hasWarranty != null) {
      request.fields['hasWarranty'] = '$hasWarranty';
    }
    if (hasWarranty == true) {
      if (warrantyDurationValue != null) {
        request.fields['warrantyDurationValue'] = '$warrantyDurationValue';
      }
      if (warrantyDurationUnit != null &&
          warrantyDurationUnit.trim().isNotEmpty) {
        request.fields['warrantyDurationUnit'] = warrantyDurationUnit.trim();
      }
    }
  }

  Future<Map<String, dynamic>> deleteProduct(String productId) async {
    final data = await _client.delete(
      '/products/$productId',
      authenticated: true,
    );
    return Map<String, dynamic>.from(data as Map? ?? const <String, dynamic>{});
  }

  Future<http.Response> _sendMultipartRequest(
    http.MultipartRequest request,
  ) async {
    try {
      final streamedResponse = await request.send();
      return await http.Response.fromStream(streamedResponse);
    } catch (_) {
      throw AppApiException('Impossible de joindre le serveur BANAY');
    }
  }

  /// A non-2xx response isn't always our own JSON error body: a reverse
  /// proxy in front of the backend (payload too large, gateway timeout...)
  /// can reject the request first and return its own HTML error page. Treat
  /// that as a clean server error instead of letting jsonDecode's
  /// FormatException escape uncaught.
  Map<String, dynamic> _parseMultipartResponse(http.Response response) {
    Map<String, dynamic> decoded;
    try {
      decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw AppApiException(
        'Reponse invalide du serveur (HTTP ${response.statusCode}). '
        'Reessayez dans quelques instants.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = (decoded['message'] as String?) ?? 'Erreur serveur';
      throw AppApiException(message, statusCode: response.statusCode);
    }

    return Map<String, dynamic>.from(
      (decoded['data'] as Map?) ?? const <String, dynamic>{},
    );
  }

  Future<List<http.MultipartFile>> _buildTrackedMultipartFiles(
    List<File> imageFiles, {
    void Function(ProductUploadProgressInfo progress)? onUploadProgress,
  }) async {
    if (imageFiles.isEmpty) {
      return const <http.MultipartFile>[];
    }

    final totalBytesByImage = await Future.wait<int>(
      imageFiles.map((imageFile) => imageFile.length()),
    );
    final sentBytesByImage = List<int>.filled(imageFiles.length, 0);
    final totalImageBytes = totalBytesByImage.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    var totalImageBytesSent = 0;

    return Future.wait(
      imageFiles.asMap().entries.map((entry) async {
        final imageIndex = entry.key;
        final imageFile = entry.value;
        final imageTotalBytes = totalBytesByImage[imageIndex];
        final fileName = imageFile.uri.pathSegments.isNotEmpty
            ? imageFile.uri.pathSegments.last
            : 'image-${imageIndex + 1}.jpg';

        final stream = imageFile.openRead().transform(
          StreamTransformer<List<int>, List<int>>.fromHandlers(
            handleData: (chunk, sink) {
              sentBytesByImage[imageIndex] += chunk.length;
              totalImageBytesSent += chunk.length;
              onUploadProgress?.call(
                ProductUploadProgressInfo(
                  imageCount: imageFiles.length,
                  currentImageIndex: imageIndex + 1,
                  currentImageBytesSent: sentBytesByImage[imageIndex],
                  currentImageTotalBytes: imageTotalBytes,
                  totalImageBytesSent: totalImageBytesSent,
                  totalImageBytes: totalImageBytes,
                ),
              );
              sink.add(chunk);
            },
          ),
        );

        return http.MultipartFile(
          'images',
          http.ByteStream(stream),
          imageTotalBytes,
          filename: fileName,
        );
      }),
    );
  }

  Future<void> trackBehaviorEvent(Map<String, dynamic> event) async {
    await _client.post(
      '/events/behavior',
      authenticated: true,
      body: event,
    );
  }
}
