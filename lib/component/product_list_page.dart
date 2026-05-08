import 'package:flutter/material.dart';

import 'package:banay/component/ProductCard.dart';
import 'package:banay/component/app_back_button.dart';
import 'package:banay/component/app_page_refresh.dart';
import 'package:banay/component/app_page_skeletons.dart';
import 'package:banay/component/ui/dinamic_icon_input.dart';
import 'package:banay/theme/app_theme_extensions.dart';

class ProductListPage extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> products;
  final Widget Function(Map<String, dynamic> product)? detailPageBuilder;

  const ProductListPage({
    super.key,
    required this.title,
    required this.products,
    this.detailPageBuilder,
  });

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage>
    with AppPageRefreshMixin<ProductListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'Tout';
  String _selectedStatus = 'Tous';
  bool _showEntrySkeleton = true;

  List<String> get _categoryFilters {
    final categories =
        widget.products
            .map((product) => (product['category'] ?? '').toString().trim())
            .where((category) => category.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return ['Tout', ...categories];
  }

  String _productStatus(Map<String, dynamic> product) {
    final rawStatus = (product['status'] ?? '').toString().trim();
    final rawCategory = (product['category'] ?? '').toString().trim();

    if (rawStatus.isNotEmpty) {
      return rawStatus;
    }

    final normalizedCategory = rawCategory.toLowerCase();
    if (normalizedCategory == 'disponible' || normalizedCategory == 'rupture') {
      return rawCategory;
    }

    return 'Disponible';
  }

  @override
  void initState() {
    super.initState();
    initializePageRefresh();
    _searchController.addListener(_handleSearchChanged);
    Future.delayed(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() => _showEntrySkeleton = false);
    });
  }

  void _handleSearchChanged() {
    final nextQuery = _searchController.text;
    if (nextQuery == _searchQuery) {
      return;
    }

    setState(() => _searchQuery = nextQuery);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
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
    final categoryFilters = _categoryFilters;
    final filteredProducts = widget.products.where((product) {
      final title = (product['title'] ?? '').toString().toLowerCase();
      final category = (product['category'] ?? '').toString().toLowerCase();
      final status = _productStatus(product).toLowerCase();

      final matchesQuery =
          normalizedQuery.isEmpty ||
          title.contains(normalizedQuery) ||
          category.contains(normalizedQuery);
      final matchesCategory =
          _selectedCategory == 'Tout' ||
          (product['category'] ?? '').toString() == _selectedCategory;
      final matchesStatus =
          _selectedStatus == 'Tous' || status == _selectedStatus.toLowerCase();

      return matchesQuery && matchesCategory && matchesStatus;
    }).toList();
    final hasSourceProducts = widget.products.isNotEmpty;
    final itemCount = filteredProducts.isEmpty
        ? 2
        : filteredProducts.length + 1;

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
                    itemCount: itemCount,
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
                              DynamicIconInput(
                                controller: _searchController,
                                primary: primary,
                                panelColor: backgroundColor,
                                borderColor: primary.withValues(alpha: 0.14),
                                hintText: 'Explorer les produits',
                                leadingIcon: Icon(
                                  Icons.search_rounded,
                                  color: primary,
                                ),
                                trailingIcon: _searchQuery.isNotEmpty
                                    ? Icon(
                                        Icons.close_rounded,
                                        color: mutedColor,
                                      )
                                    : Icon(
                                        Icons.tune_rounded,
                                        color: mutedColor,
                                      ),
                                onTrailingTap: _searchQuery.isNotEmpty
                                    ? () {
                                        _searchController.clear();
                                      }
                                    : null,
                                contentPadding: const EdgeInsets.fromLTRB(
                                  8,
                                  6,
                                  8,
                                  6,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildHorizontalFilterRow(
                                label: 'Categorie',
                                options: categoryFilters,
                                selectedValue: _selectedCategory,
                                onSelected: (value) {
                                  setState(() => _selectedCategory = value);
                                },
                                primary: primary,
                                mutedColor: mutedColor,
                                surfaceColor: backgroundColor,
                              ),
                              const SizedBox(height: 14),
                              _buildHorizontalFilterRow(
                                label: 'Etat',
                                options: const [
                                  'Tous',
                                  'Disponible',
                                  'Rupture',
                                ],
                                selectedValue: _selectedStatus,
                                onSelected: (value) {
                                  setState(() => _selectedStatus = value);
                                },
                                primary: primary,
                                mutedColor: mutedColor,
                                surfaceColor: backgroundColor,
                              ),
                            ],
                          ),
                        );
                      }

                      if (filteredProducts.isEmpty) {
                        return _buildEmptyStateCard(
                          theme: theme,
                          surfaceColor: surfaceColor,
                          mutedColor: mutedColor,
                          icon: hasSourceProducts
                              ? Icons.search_off_rounded
                              : Icons.inventory_2_outlined,
                          title: hasSourceProducts
                              ? 'Aucun produit trouve'
                              : 'Aucun produit disponible',
                          message: hasSourceProducts
                              ? 'Essaie un autre nom ou une autre categorie.'
                              : 'Les produits apparaitront ici des qu\'ils seront ajoutes.',
                        );
                      }

                      final product = filteredProducts[index - 1];
                      return ProductCard(
                        product: product,
                        detailPageBuilder: widget.detailPageBuilder,
                        variant: ProductCardVariant.editorial,
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

  Widget _buildHorizontalFilterRow({
    required String label,
    required List<String> options,
    required String selectedValue,
    required ValueChanged<String> onSelected,
    required Color primary,
    required Color mutedColor,
    required Color surfaceColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: mutedColor,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: options.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final option = options[index];
              final isSelected = option == selectedValue;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onSelected(option),
                  borderRadius: BorderRadius.circular(999),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primary.withValues(alpha: 0.14)
                          : surfaceColor,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isSelected
                            ? primary.withValues(alpha: 0.35)
                            : primary.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        option,
                        style: TextStyle(
                          color: isSelected ? primary : mutedColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyStateCard({
    required ThemeData theme,
    required Color surfaceColor,
    required Color mutedColor,
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(icon, size: 38, color: mutedColor),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: mutedColor),
          ),
        ],
      ),
    );
  }
}
