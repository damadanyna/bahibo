import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'catalog_api_service.dart';

/// Tracks user behavior events (product views, category interest) to feed
/// the backend scoring algorithm. All calls are fire-and-forget: failures
/// are silently ignored so tracking never blocks the UI.
class BanayBehaviorTracker {
  BanayBehaviorTracker._();
  static final BanayBehaviorTracker instance = BanayBehaviorTracker._();

  static const String _prefKey = 'banay_cat_weights';
  static const Duration _viewDedupWindow = Duration(minutes: 2);

  final CatalogApiService _api = CatalogApiService();
  final Map<String, DateTime> _recentlyViewedAt = {};

  /// Call when a product detail page is opened.
  void trackProductViewed({
    required String productId,
    String? categorySlug,
    String? sellerId,
  }) {
    if (productId.isEmpty) return;

    final now = DateTime.now();
    final last = _recentlyViewedAt[productId];
    if (last != null && now.difference(last) < _viewDedupWindow) return;
    _recentlyViewedAt[productId] = now;

    unawaited(_sendEvent({
      'type': 'product.viewed',
      'productId': productId,
      if (categorySlug != null && categorySlug.isNotEmpty)
        'categorySlug': categorySlug,
      if (sellerId != null && sellerId.isNotEmpty) 'sellerId': sellerId,
    }));

    if (categorySlug != null && categorySlug.isNotEmpty) {
      unawaited(_incrementCategoryWeight(categorySlug));
    }
  }

  /// Call when the user selects a category filter.
  void trackCategoryBrowsed(String categorySlug) {
    if (categorySlug.isEmpty) return;
    unawaited(_sendEvent({
      'type': 'category.browsed',
      'categorySlug': categorySlug,
    }));
    unawaited(_incrementCategoryWeight(categorySlug));
  }

  /// Returns the user's top [limit] categories sorted by affinity weight.
  /// Used in Phase 2 to send to fetchProducts as query params.
  Future<List<String>> getTopCategorySlugs({int limit = 3}) async {
    final weights = await _loadWeights();
    final sorted = weights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => e.key).toList();
  }

  Future<void> _incrementCategoryWeight(String categorySlug) async {
    final weights = await _loadWeights();
    weights[categorySlug] = (weights[categorySlug] ?? 0.0) + 1.0;
    await _saveWeights(weights);
  }

  Future<Map<String, double>> _loadWeights() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefKey) ?? [];
    final map = <String, double>{};
    for (final entry in raw) {
      final sep = entry.lastIndexOf(':');
      if (sep <= 0) continue;
      final slug = entry.substring(0, sep);
      final weight = double.tryParse(entry.substring(sep + 1));
      if (weight != null) map[slug] = weight;
    }
    return map;
  }

  Future<void> _saveWeights(Map<String, double> weights) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefKey,
      weights.entries.map((e) => '${e.key}:${e.value}').toList(),
    );
  }

  Future<void> _sendEvent(Map<String, dynamic> event) async {
    try {
      await _api.trackBehaviorEvent(event);
    } catch (_) {
      // Fire and forget — never block the UI for tracking failures.
    }
  }
}
