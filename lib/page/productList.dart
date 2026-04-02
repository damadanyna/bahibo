import 'dart:convert';

import 'package:bahibo/component/app_page_refresh.dart';
import 'package:bahibo/component/app_page_skeletons.dart';
import 'package:bahibo/page/notifications_page.dart';
import 'package:bahibo/theme/app_theme_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

  final List<Map<String, dynamic>> _notifications = [
    {
      'section': 'Important',
      'type': 'follow',
      'channel': 'Aicha Mode',
      'description': 'Nouveau fournisseur dans votre reseau.',
      'content':
          'vient de s\'abonner a votre boutique et suit vos nouvelles sorties.',
      'time': 'Il y a 5 min',
      'avatarUrl': 'https://i.pravatar.cc/240?img=32',
      'unread': true,
    },
    {
      'section': 'Important',
      'type': 'catalog_update',
      'channel': 'Maison Kivu',
      'description':
          'Le catalogue fournisseur que vous suivez vient d\'etre mis a jour.',
      'content':
          'a mis en ligne 3 nouveaux produits chez le fournisseur que vous suivez.',
      'time': 'Il y a 24 min',
      'avatarUrl': 'https://i.pravatar.cc/240?img=12',
      'thumbnailUrl':
          'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=480',
      'unread': true,
    },
    {
      'section': 'Aujourd\'hui',
      'type': 'product_added',
      'channel': 'Elanga Store',
      'description':
          'Un nouveau produit vient d\'etre ajoute par ce fournisseur.',
      'content':
          'a ajoute un nouveau produit dans les articles que vous suivez.',
      'productName': 'Sac a main cuir premium',
      'time': 'Il y a 20 min',
      'avatarUrl': 'https://i.pravatar.cc/240?img=52',
      'thumbnailUrl':
          'https://images.unsplash.com/photo-1584917865442-de89df76afd3?w=480',
      'unread': false,
    },
    {
      'section': 'Aujourd\'hui',
      'type': 'product_added',
      'channel': 'Jojo Tech',
      'description': 'Produit ajoute dans votre veille vendeur.',
      'content': 'a ajoute un nouvel article parmi les produits suivis.',
      'productName': 'iPhone pliable Pro X',
      'time': 'Il y a 13 heures',
      'avatarUrl': 'https://i.pravatar.cc/240?img=18',
      'thumbnailUrl':
          'https://images.unsplash.com/photo-1598327105666-5b89351aff97?w=480',
      'unread': false,
    },
    {
      'section': 'Aujourd\'hui',
      'type': 'product_added',
      'channel': 'NalaK',
      'description': 'Nouvel arrivage premium disponible maintenant.',
      'content':
          'a publie un nouveau produit premium venant d\'un fournisseur abonne.',
      'productName': 'Coffret parfum prestige',
      'time': 'Il y a 13 heures',
      'avatarUrl': 'https://i.pravatar.cc/240?img=47',
      'thumbnailUrl':
          'https://images.unsplash.com/photo-1541643600914-78b084683601?w=480',
      'unread': false,
    },
  ];

  final ScrollController _scrollController = ScrollController();

  List<dynamic> products = [];
  List<String> categories = [];
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

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  Future<void> fetchCategories() async {
    final response = await http.get(
      Uri.parse('https://dummyjson.com/products/categories'),
    );

    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      setState(() {
        categories = data.map((e) => e['slug'].toString()).toList();
        _rebuildMixedItems();
      });
    }
  }

  Future<void> fetchProducts() async {
    if (isLoading || !hasMore) return;
    setState(() => isLoading = true);

    final response = await http.get(
      Uri.parse('https://dummyjson.com/products?limit=$limit&skip=$skip'),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List newProducts = data['products'];

      setState(() {
        skip += limit;
        products.addAll(newProducts);
        hasMore = products.length < (data['total'] as int);
        isLoading = false;
        _rebuildMixedItems();
      });

      if (kDebugMode) {
        print('Charge: ${products.length} produits, hasMore: $hasMore');
      }
    } else {
      setState(() => isLoading = false);
    }
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
                    return GestureDetector(
                      onTap: () async {
                        final savedOffset = _scrollController.offset;

                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CategoryPage(
                              categoryName: cat,
                              categoryIcon: categoryIcons[cat] ?? '🛍️',
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
                            Text(
                              categoryIcons[cat] ?? '🛍️',
                              style: const TextStyle(fontSize: 28),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              cat,
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
