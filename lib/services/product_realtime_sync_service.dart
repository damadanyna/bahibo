import 'dart:async';

import 'package:banay/services/chat_realtime_service.dart';
import 'package:flutter/foundation.dart';

class ProductRealtimeUpdate {
  const ProductRealtimeUpdate({
    required this.productId,
    required this.actorUserId,
    required this.action,
    required this.product,
    this.comment,
  });

  final String productId;
  final String actorUserId;
  final String action;
  final Map<String, dynamic> product;
  final Map<String, dynamic>? comment;

  factory ProductRealtimeUpdate.fromEvent(Map<String, dynamic> event) {
    final rawProduct = event['product'];
    final rawComment = event['comment'];

    return ProductRealtimeUpdate(
      productId: event['productId']?.toString().trim() ?? '',
      actorUserId: event['actorUserId']?.toString().trim() ?? '',
      action: event['action']?.toString().trim() ?? '',
      product: rawProduct is Map<String, dynamic>
          ? Map<String, dynamic>.from(rawProduct)
          : rawProduct is Map
          ? Map<String, dynamic>.from(rawProduct)
          : const <String, dynamic>{},
      comment: rawComment is Map<String, dynamic>
          ? Map<String, dynamic>.from(rawComment)
          : rawComment is Map
          ? Map<String, dynamic>.from(rawComment)
          : null,
    );
  }
}

class ProductRealtimeSyncService {
  ProductRealtimeSyncService._();

  static final ProductRealtimeSyncService instance =
      ProductRealtimeSyncService._();

  final ValueNotifier<int> changes = ValueNotifier<int>(0);
  final StreamController<ProductRealtimeUpdate> _updatesController =
      StreamController<ProductRealtimeUpdate>.broadcast();
  final Map<String, Map<String, dynamic>> _latestProductsById =
      <String, Map<String, dynamic>>{};

  bool _initialized = false;

  Stream<ProductRealtimeUpdate> get updates => _updatesController.stream;

  Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }

    _initialized = true;
    await ChatRealtimeService.instance.ensureConnected();
    ChatRealtimeService.instance.events.listen(_handleRealtimeEvent);
  }

  Map<String, dynamic> mergeIntoProduct(Map<String, dynamic> product) {
    final productId = product['id']?.toString().trim() ?? '';
    if (productId.isEmpty) {
      return Map<String, dynamic>.from(product);
    }

    final latestProduct = _latestProductsById[productId];
    if (latestProduct == null) {
      return Map<String, dynamic>.from(product);
    }

    final mergedProduct = <String, dynamic>{
      ...Map<String, dynamic>.from(product),
      ...latestProduct,
    };

    final currentSeller = product['seller'];
    final latestSeller = latestProduct['seller'];
    if (currentSeller is Map && latestSeller is Map) {
      mergedProduct['seller'] = <String, dynamic>{
        ...Map<String, dynamic>.from(currentSeller),
        ...Map<String, dynamic>.from(latestSeller),
      };
    }

    return mergedProduct;
  }

  void _handleRealtimeEvent(Map<String, dynamic> event) {
    if (event['type']?.toString() != 'product:updated') {
      return;
    }

    final update = ProductRealtimeUpdate.fromEvent(event);
    if (update.productId.isEmpty || update.product.isEmpty) {
      return;
    }

    _latestProductsById[update.productId] = update.product;
    changes.value += 1;
    _updatesController.add(update);
  }
}
