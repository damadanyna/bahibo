import 'package:bahibo/page/category_page.dart';
import 'package:flutter/material.dart';

import 'package:bahibo/theme/app_theme_extensions.dart';

class NavigationCategoryEntry {
  final String icon;
  final String label;
  final String slug;

  const NavigationCategoryEntry({
    required this.icon,
    required this.label,
    required this.slug,
  });
}

const bahiboNavigationCategories = <NavigationCategoryEntry>[
  NavigationCategoryEntry(
    icon: '📱',
    label: 'Smartphones',
    slug: 'smartphones',
  ),
  NavigationCategoryEntry(icon: '💻', label: 'Laptops', slug: 'laptops'),
  NavigationCategoryEntry(icon: '🧴', label: 'Skincare', slug: 'skincare'),
  NavigationCategoryEntry(
    icon: '🏠',
    label: 'Home decoration',
    slug: 'home-decoration',
  ),
  NavigationCategoryEntry(icon: '🚗', label: 'Automotive', slug: 'automotive'),
  NavigationCategoryEntry(icon: '💄', label: 'Beauty', slug: 'beauty'),
];

class NavigationCategoryGrid extends StatelessWidget {
  final List<NavigationCategoryEntry> categories;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const NavigationCategoryGrid({
    super.key,
    required this.categories,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;

    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: categories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.08,
      ),
      itemBuilder: (context, index) {
        final category = categories[index];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CategoryPage(
                    categoryName: category.slug,
                    categoryIcon: category.icon,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: appColors.inputBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category.icon, style: const TextStyle(fontSize: 30)),
                  const Spacer(),
                  Text(
                    category.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Voir les produits',
                    style: TextStyle(
                      color: appColors.mutedText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
