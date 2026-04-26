import 'dart:async';

import 'package:banay/component/app_page_skeletons.dart';
import 'package:banay/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';

typedef DynamicCategoryTapCallback =
    FutureOr<void> Function(Map<String, dynamic> category);

const Map<String, String> dinamicCategoryIcons = {
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

String resolveDinamicCategoryIcon(Map<String, dynamic> category) {
  final slug = category['slug']?.toString() ?? '';
  return category['icon']?.toString() ?? dinamicCategoryIcons[slug] ?? '🛍️';
}

class DinamicCategoriesHList extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final String title;
  final DynamicCategoryTapCallback? onCategoryTap;
  final bool showTitle;

  const DinamicCategoriesHList({
    super.key,
    required this.categories,
    this.title = 'Catégories Populaires',
    this.onCategoryTap,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
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
                    final category = categories[index];
                    final label =
                        category['name']?.toString() ??
                        category['slug']?.toString() ??
                        '';
                    final icon = resolveDinamicCategoryIcon(category);

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onCategoryTap == null
                            ? null
                            : () => onCategoryTap!(category),
                        borderRadius: BorderRadius.circular(12),
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
                      ),
                    );
                  },
                ),
        ),
        if (showTitle) const SizedBox(height: 40),
      ],
    );
  }
}

