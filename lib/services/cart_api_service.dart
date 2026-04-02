import 'app_api_client.dart';

class CartApiService {
  CartApiService({AppApiClient? client}) : _client = client ?? AppApiClient();

  final AppApiClient _client;

  Future<Map<String, dynamic>> getCart() async {
    final data = await _client.get('/cart', authenticated: true);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> getTotals() async {
    final data = await _client.get('/cart/totals', authenticated: true);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> addItem({
    required String productId,
    int quantity = 1,
  }) async {
    final data = await _client.post(
      '/cart/items',
      authenticated: true,
      body: {'productId': productId, 'quantity': quantity},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> removeItem(String itemId) async {
    await _client.delete('/cart/items/$itemId', authenticated: true);
  }
}
