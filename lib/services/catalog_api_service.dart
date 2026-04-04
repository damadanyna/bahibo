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

  Future<Map<String, dynamic>> fetchSellerProfile(
    String sellerProfileId,
  ) async {
    final data = await _client.get('/profiles/sellers/$sellerProfileId');
    return Map<String, dynamic>.from(data as Map);
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
