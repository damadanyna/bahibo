import 'app_api_client.dart';

class OrdersApiService {
  OrdersApiService({AppApiClient? client}) : _client = client ?? AppApiClient();

  final AppApiClient _client;

  Future<List<Map<String, dynamic>>> fetchOrders() async {
    final data = await _client.get('/orders', authenticated: true);
    return (data as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> createOrderFromCart() async {
    final data = await _client.post('/orders', authenticated: true);
    return Map<String, dynamic>.from(data as Map);
  }
}
