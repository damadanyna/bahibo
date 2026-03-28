import 'dart:async';
import 'package:bahibo/component/main_navigation_shell.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'category_page.dart';
import 'package:bahibo/component/app_page_skeletons.dart';
import 'package:bahibo/component/app_page_refresh.dart';
import '../component/ProductCard.dart';

class Productlist extends StatefulWidget {
  final int currentMenuIndex;
  final List<MainNavigationItem> navigationItems;
  final ValueChanged<int>? onMenuSelected;

  const Productlist({
    super.key,
    this.currentMenuIndex = 0,
    this.navigationItems = const [],
    this.onMenuSelected,
  });

  @override
  State<Productlist> createState() => _ProductlistState();
}

class _ProductlistState extends State<Productlist>
    with AppPageRefreshMixin<Productlist> {
  List<dynamic> products = [];
  List<String> categories = [];

  // ← liste mixée calculée UNE SEULE FOIS et mise à jour manuellement
  List<dynamic> mixedItems = [];

  int skip = 0;
  final int limit = 10;
  bool isLoading = false;
  bool hasMore = true;

  final int categoryInterval = 15;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    initializePageRefresh();
    fetchCategories();
    fetchProducts();

    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final pos = _scrollController.position;
    // déclencher quand on approche du bas
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      fetchProducts();
    }
  }

  @override
  void dispose() {
    disposePageRefresh();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
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
      Uri.parse("https://dummyjson.com/products/categories"),
    );
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      setState(() {
        categories = data.map((e) => e['slug'].toString()).toList();
        // reconstruire mixedItems avec les catégories disponibles
        _rebuildMixedItems();
      });
    }
  }

  Future<void> fetchProducts() async {
    if (isLoading || !hasMore) return;
    setState(() => isLoading = true);

    final response = await http.get(
      Uri.parse("https://dummyjson.com/products?limit=$limit&skip=$skip"),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List newProducts = data['products'];

      setState(() {
        skip += limit;
        products.addAll(newProducts);
        hasMore = products.length < (data['total'] as int);
        isLoading = false;
        // ← reconstruire la liste mixée après chaque chargement
        _rebuildMixedItems();
      });

      if (kDebugMode) {
        print('✅ Chargé: ${products.length} produits, hasMore: $hasMore');
      }
    } else {
      setState(() => isLoading = false);
    }
  }

  // ← reconstruire mixedItems proprement
  void _rebuildMixedItems() {
    final List<dynamic> items = [];
    for (int i = 0; i < products.length; i++) {
      // insérer un bloc catégorie toutes les categoryInterval produits
      if (i % categoryInterval == 0) {
        items.add({'type': 'category_block'});
      }
      items.add({'type': 'product', 'data': products[i]});
    }
    mixedItems = items;
  }

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

  Widget buildCategoryBlock() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 20),
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
                  // ← physics pour éviter conflit avec le scroll vertical
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

                        // ← restaurer position après retour
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
                          color: isDark ? theme.cardColor : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.grey.shade700
                                : const Color.fromARGB(255, 223, 223, 223),
                          ),
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
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 5, 16, 7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Abaoly',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      color: Colors.green,
                    ),
                  ),
                  if (widget.onMenuSelected != null &&
                      widget.navigationItems.isNotEmpty)
                    MainNavigationMenuButton(
                      currentIndex: widget.currentMenuIndex,
                      items: widget.navigationItems,
                      onSelected: widget.onMenuSelected!,
                    ),
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
                            padding: const EdgeInsets.only(bottom: 132),
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
                            padding: const EdgeInsets.only(bottom: 132),
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
                  if (isOffline) const AppOfflineBanner(bottomOffset: 108),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
