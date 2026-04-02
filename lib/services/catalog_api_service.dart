import 'app_api_client.dart';

class CatalogApiService {
  CatalogApiService({AppApiClient? client})
    : _client = client ?? AppApiClient();

  final AppApiClient _client;

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
}
