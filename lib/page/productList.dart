import 'package:bahibo/component/app_page_refresh.dart';
import 'package:bahibo/component/app_page_skeletons.dart';
import 'package:bahibo/page/notifications_page.dart';
import 'package:bahibo/services/catalog_api_service.dart';
import 'package:bahibo/services/notifications_api_service.dart';
import 'package:bahibo/theme/app_theme_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../component/ProductCard.dart';
import 'category_page.dart';

class Productlist extends StatefulWidget {
  const Productlist({super.key});

  @override
  State<Productlist> createState() => _ProductlistState();
}

class _ProductlistState extends State<Productlist>
    with AppPageRefreshMixin<Productlist> {
  static const double _bottomContentPadding = 84;
  static const double _offlineBannerBottomOffset = 64;

  final CatalogApiService _catalogApiService = CatalogApiService();
  final NotificationsApiService _notificationsApiService =
      NotificationsApiService();
  final List<Map<String, dynamic>> _notifications = [];

  final ScrollController _scrollController = ScrollController();

  List<dynamic> products = [];
  List<Map<String, dynamic>> categories = [];
  List<dynamic> mixedItems = [];

  int skip = 0;
  final int limit = 10;
  bool isLoading = false;
  bool hasMore = true;
  final int categoryInterval = 15;

  int get _unreadNotificationCount =>
      _notifications.where((item) => item['unread'] == true).length;

  final Map<String, String> categoryIcons = {
    'smartphones': '📱',
    'laptops': '💻',
    'fragrances': '🌸',
    'skincare': '🧴',
    'groceries': '🛒',
    'home-decoration': '🏠',
    'furniture': '🛋️',
    'tops': '👕',
    'womens-dresses': '👗',
    'womens-shoes': '👠',
    'mens-shirts': '👔',
    'mens-shoes': '👟',
    'mens-watches': '⌚',
    'womens-watches': '⌚',
    'womens-bags': '👜',
    'womens-jewellery': '💍',
    'sunglasses': '🕶️',
    'automotive': '🚗',
    'motorcycle': '🏍️',
    'lighting': '💡',
    'vehicle': '🚙',
    'beauty': '💄',
    'sports-accessories': '⚽',
    'tablets': '📲',
  };

  @override
  void initState() {
    super.initState();
    initializePageRefresh();
    fetchCategories();
    fetchProducts();
    fetchNotifications();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    disposePageRefresh();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      fetchProducts();
    }
  }

  @override
  Future<void> onPageReload() async {
    setState(() {
      products = [];
      categories = [];
      mixedItems = [];
      skip = 0;
      hasMore = true;
      isLoading = false;
    });

    await fetchCategories();
    await fetchProducts();
    await fetchNotifications();

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  Future<void> fetchCategories() async {
    try {
      final data = await _catalogApiService.fetchCategories();
      if (!mounted) return;
      setState(() {
        categories = data;
        _rebuildMixedItems();
      });
    } catch (_) {}
  }

  Future<void> fetchProducts() async {
    if (isLoading || !hasMore) return;
    setState(() => isLoading = true);

    try {
      final data = await _catalogApiService.fetchProducts(
        limit: limit,
        skip: skip,
      );
      final List<dynamic> newProducts = List<dynamic>.from(
        data['products'] as List? ?? const [],
      );

      if (!mounted) return;

      setState(() {
        skip += limit;
        products.addAll(newProducts);
        hasMore =
            products.length < ((data['total'] as int?) ?? products.length);
        isLoading = false;
        _rebuildMixedItems();
      });

      if (kDebugMode) {
        print('Charge: ${products.length} produits, hasMore: $hasMore');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchNotifications() async {
    try {
      final data = await _notificationsApiService.fetchNotifications();
      if (!mounted) return;
      setState(() {
        _notifications
          ..clear()
          ..addAll(data);
      });
    } catch (_) {}
  }

  void _rebuildMixedItems() {
    final List<dynamic> items = [];
    for (int i = 0; i < products.length; i++) {
      if (i % categoryInterval == 0) {
        items.add({'type': 'category_block'});
      }
      items.add({'type': 'product', 'data': products[i]});
    }
    mixedItems = items;
  }

  void _openNotificationsPage() {
    if (_unreadNotificationCount > 0) {
      setState(() {
        for (final notification in _notifications) {
          notification['unread'] = false;
        }
      });
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationsPage(
          notifications: List<Map<String, dynamic>>.from(_notifications),
        ),
      ),
    );
  }

  Widget _buildNotificationButton(ThemeData theme) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: _openNotificationsPage,
          tooltip: 'Ouvrir les notifications',
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(12),
          ),
          icon: Icon(
            _unreadNotificationCount > 0
                ? Icons.notifications_active_rounded
                : Icons.notifications_none_rounded,
            color: Colors.white,
          ),
        ),
        if (_unreadNotificationCount > 0)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: theme.scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
              child: Text(
                _unreadNotificationCount > 9
                    ? '9+'
                    : '$_unreadNotificationCount',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget buildCategoryBlock() {
    final theme = Theme.of(context);
    final appColors = theme.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Catégories Populaires',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 200,
          child: categories.isEmpty
              ? const CategoryBlockSkeleton()
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  physics: const ClampingScrollPhysics(),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final slug = cat['slug']?.toString() ?? '';
                    final label = cat['name']?.toString() ?? slug;
                    final icon =
                        cat['icon']?.toString() ?? categoryIcons[slug] ?? '🛍️';
                    return GestureDetector(
                      onTap: () async {
                        final savedOffset = _scrollController.offset;

                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CategoryPage(
                              categoryName: slug,
                              categoryLabel: label,
                              categoryIcon: icon,
                            ),
                          ),
                        );

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_scrollController.hasClients) {
                            _scrollController.jumpTo(savedOffset);
                          }
                        });
                      },
                      child: Container(
                        width: 150,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: appColors.borderColor),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(icon, style: const TextStyle(fontSize: 28)),
                            const SizedBox(height: 4),
                            Text(
                              label,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget buildProductCardLoadig() {
    return const ProductCardSkeleton();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;

    return Scaffold(
      backgroundColor: appColors.authBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 5, 16, 7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Abaoly',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Row(children: [_buildNotificationButton(theme)]),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: refreshPageWithDialog,
                    child: products.isEmpty && isLoading
                        ? ListView(
                            padding: const EdgeInsets.only(
                              bottom: _bottomContentPadding,
                            ),
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const CategoryBlockSkeleton(),
                              ...List.generate(
                                8,
                                (_) => buildProductCardLoadig(),
                              ),
                            ],
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.only(
                              bottom: _bottomContentPadding,
                            ),
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: mixedItems.length + 1,
                            itemBuilder: (context, index) {
                              if (index == mixedItems.length) {
                                if (isLoading) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Column(
                                      children: List.generate(
                                        2,
                                        (_) => buildProductCardLoadig(),
                                      ),
                                    ),
                                  );
                                }
                                if (!hasMore) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text('Plus de produits 😊'),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              }

                              final item = mixedItems[index];

                              if (item['type'] == 'category_block') {
                                return buildCategoryBlock();
                              }

                              return ProductCard(
                                product: item['data'] as Map<String, dynamic>,
                              );
                            },
                          ),
                  ),
                  if (isOffline)
                    const AppOfflineBanner(
                      bottomOffset: _offlineBannerBottomOffset,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
