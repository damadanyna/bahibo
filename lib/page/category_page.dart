import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import "../component/ProductCard.dart";
import 'package:bahibo/component/app_page_skeletons.dart';
import 'package:bahibo/component/app_page_refresh.dart';
import "../component/theme_menu_button.dart";

class CategoryPage extends StatefulWidget {
  final String categoryName;
  final String categoryIcon;

  const CategoryPage({
    super.key,
    required this.categoryName,
    required this.categoryIcon,
  });

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage>
    with AppPageRefreshMixin<CategoryPage> {
  List<dynamic> products = [];
  int skip = 0;
  final int limit = 10;
  bool isLoading = false;
  bool hasMore = true;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    initializePageRefresh();
    fetchProducts();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        fetchProducts();
      }
    });
  }

  @override
  void dispose() {
    disposePageRefresh();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Future<void> onPageReload() async {
    setState(() {
      products = [];
      skip = 0;
      hasMore = true;
      isLoading = false;
    });

    await fetchProducts();

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  Future<void> fetchProducts() async {
    if (isLoading || !hasMore) return;
    setState(() => isLoading = true);

    final response = await http.get(
      Uri.parse(
        "https://dummyjson.com/products/category/${widget.categoryName}?limit=$limit&skip=$skip",
      ),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List newProducts = data['products'];

      setState(() {
        skip += limit;
        products.addAll(newProducts);
        hasMore = products.length < (data['total'] as int);
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(widget.categoryIcon),
            const SizedBox(width: 8),
            Text(
              widget.categoryName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.search),
          ),
          ThemeMenuButton(),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: refreshPageWithDialog,
            child: products.isEmpty && isLoading
                ? ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: 8,
                    itemBuilder: (_, __) => const ProductCardSkeleton(),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: products.length + 1,
                    itemBuilder: (context, index) {
                      if (index == products.length) {
                        if (isLoading) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              children: List.generate(
                                2,
                                (_) => const ProductCardSkeleton(),
                              ),
                            ),
                          );
                        } else if (!hasMore) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Plus de produits 😊'),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }

                      final product = products[index];

                      return ProductCard(
                        product: product as Map<String, dynamic>,
                      );
                    },
                  ),
          ),
          if (isOffline) const AppOfflineBanner(),
        ],
      ),
    );
  }
}
