import 'package:bahibo/component/navigation/navigation_category_grid.dart';
import 'package:bahibo/component/theme_menu_button.dart';
import 'package:flutter/material.dart';

class MainNavigationSettingsPanel extends StatelessWidget {
  const MainNavigationSettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.cardColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 120),
          children: [
            Text(
              'Parametres',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reglez rapidement l apparence et vos preferences.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.white70 : const Color(0xFF5F6F66),
              ),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFD6E4DA),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.palette_outlined,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Changer le theme de l application',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const ThemeMenuButton(),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'Categories populaires',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Accedez rapidement aux univers les plus recherches.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.white70 : const Color(0xFF5F6F66),
              ),
            ),
            const SizedBox(height: 16),
            const NavigationCategoryGrid(
              categories: bahiboNavigationCategories,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
            ),
          ],
        ),
      ),
    );
  }
}
