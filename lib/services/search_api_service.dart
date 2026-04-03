import 'app_api_client.dart';

class SearchApiService {
  SearchApiService({AppApiClient? client}) : _client = client ?? AppApiClient();

  final AppApiClient _client;

  Future<Map<String, dynamic>> search({
    required String query,
    int limit = 24,
  }) async {
    final data = await _client.get(
      '/search',
      queryParameters: {'q': query, 'limit': '$limit'},
    );

    return Map<String, dynamic>.from(data as Map);
  }
}
