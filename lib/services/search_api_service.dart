import 'app_api_client.dart';

class SearchApiService {
  SearchApiService({AppApiClient? client}) : _client = client ?? AppApiClient();

  final AppApiClient _client;

  Future<Map<String, dynamic>> autocomplete({
    required String query,
    int limit = 6,
  }) async {
    final data = await _client.get(
      '/search/autocomplete',
      queryParameters: {'q': query, 'limit': '$limit'},
      authenticated: true,
    );

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> search({
    required String query,
    int limit = 24,
  }) async {
    final data = await _client.get(
      '/search',
      queryParameters: {'q': query, 'limit': '$limit'},
      authenticated: true,
    );

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>?> recordSearchHistory({
    required String query,
    required int resultCount,
  }) async {
    final data = await _client.post(
      '/search/history',
      authenticated: true,
      body: {'query': query, 'resultCount': resultCount},
    );

    if (data == null) {
      return null;
    }

    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> fetchNoResultSearchHistory() async {
    final data = await _client.get(
      '/search/history/no-results',
      authenticated: true,
    );

    return (data as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
