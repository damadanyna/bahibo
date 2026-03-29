import 'package:bahibo/component/navigation/navigation_category_grid.dart';
import 'package:flutter/material.dart';

class MainNavigationCategoryHubPanel extends StatelessWidget {
  const MainNavigationCategoryHubPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.cardColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Categories',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Accedez rapidement aux univers les plus recherches.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white70 : const Color(0xFF5F6F66),
                ),
              ),
              const SizedBox(height: 20),
              const Expanded(
                child: NavigationCategoryGrid(
                  categories: bahiboNavigationCategories,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
