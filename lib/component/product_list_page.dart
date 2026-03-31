import 'package:flutter/material.dart';

import 'package:bahibo/component/ProductCard.dart';
import 'package:bahibo/component/app_back_button.dart';
import 'package:bahibo/component/app_page_refresh.dart';
import 'package:bahibo/component/app_page_skeletons.dart';
import 'package:bahibo/component/app_text_input.dart';
import 'package:bahibo/theme/app_theme_extensions.dart';

class ProductListPage extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> products;

  const ProductListPage({
    super.key,
    required this.title,
    required this.products,
  });

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage>
    with AppPageRefreshMixin<ProductListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showEntrySkeleton = true;

  @override
  void initState() {
    super.initState();
    initializePageRefresh();
    Future.delayed(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() => _showEntrySkeleton = false);
    });
  }

  @override
  void dispose() {
    disposePageRefresh();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Future<void> onPageReload() async {
    if (mounted) {
      setState(() => _showEntrySkeleton = true);
    }
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _showEntrySkeleton = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appColors = theme.appColors;
    final primary = theme.colorScheme.primary;
    final backgroundColor = appColors.backgroundBase;
    final surfaceColor = appColors.panelBackground;
    final mutedColor = appColors.mutedText;
    final titleColor =
        theme.textTheme.headlineSmall?.color ?? theme.colorScheme.onSurface;
    final normalizedQuery = _searchQuery.trim().toLowerCase();
    final filteredProducts = widget.products.where((product) {
      if (normalizedQuery.isEmpty) return true;
      final title = (product['title'] ?? '').toString().toLowerCase();
      final category = (product['category'] ?? '').toString().toLowerCase();
      return title.contains(normalizedQuery) ||
          category.contains(normalizedQuery);
    }).toList();

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: refreshPageWithDialog,
            child: _showEntrySkeleton
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [UserListSkeleton()],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: filteredProducts.length + 1,
                    separatorBuilder: (_, index) => index == 0
                        ? const SizedBox(height: 18)
                        : const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Container(
                          margin: const EdgeInsets.only(top: 24),
                          padding: const EdgeInsets.fromLTRB(20, 88, 20, 20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                primary.withValues(alpha: isDark ? 0.30 : 0.18),
                                surfaceColor,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: titleColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${filteredProducts.length} produits disponibles',
                                style: TextStyle(
                                  color: mutedColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              AppInputContainer(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.search,
                                      color: primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: _searchController,
                                        cursorColor: primary,
                                        onChanged: (value) {
                                          setState(() => _searchQuery = value);
                                        },
                                        decoration: appInputDecoration(
                                          context,
                                          hintText: 'Explorer les produits',
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: 6,
                                              ),
                                        ),
                                        style: appInputTextStyle(context),
                                      ),
                                    ),
                                    if (_searchQuery.isNotEmpty)
                                      GestureDetector(
                                        onTap: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                        child: Icon(
                                          Icons.close,
                                          color: mutedColor,
                                        ),
                                      )
                                    else
                                      Icon(Icons.tune, color: mutedColor),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (filteredProducts.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 36,
                                color: mutedColor,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Aucun produit trouve',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Essaie un autre nom ou une autre categorie.',
                                style: TextStyle(color: mutedColor),
                              ),
                            ],
                          ),
                        );
                      }

                      final product = filteredProducts[index - 1];
                      return Container(
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: ProductCard(product: product),
                        ),
                      );
                    },
                  ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 24,
            child: const AppBackButton(),
          ),
          if (isOffline) const AppOfflineBanner(),
        ],
      ),
    );
  }
}
