import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import "../component/ProductCard.dart";

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

class _CategoryPageState extends State<CategoryPage> {
  List<dynamic> products = [];
  int skip = 0;
  final int limit = 10;
  bool isLoading = false;
  bool hasMore = true;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
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
    _scrollController.dispose();
    super.dispose();
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
      backgroundColor: Colors.white,
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
        ],
      ),
      body: products.isEmpty && isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              controller: _scrollController,
              itemCount: products.length + 1,
              itemBuilder: (context, index) {
                if (index == products.length) {
                  if (isLoading) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
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

                return ProductCard(product: product as Map<String, dynamic>);
              },
            ),
    );
  }
}
