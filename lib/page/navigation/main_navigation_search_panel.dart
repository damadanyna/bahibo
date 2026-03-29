import 'package:bahibo/component/navigation/navigation_search_chip.dart';
import 'package:bahibo/component/ui/dinamic_icon_input.dart';
import 'package:flutter/material.dart';

class MainNavigationSearchPanel extends StatefulWidget {
  const MainNavigationSearchPanel({super.key});

  @override
  State<MainNavigationSearchPanel> createState() =>
      _MainNavigationSearchPanelState();
}

class _MainNavigationSearchPanelState extends State<MainNavigationSearchPanel> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
                'Recherche',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFD6E4DA),
                  ),
                ),
                child: DynamicIconInput(
                  controller: _searchController,
                  primary: isDark ? Colors.white70 : const Color(0xFF4A5B52),
                  panelColor: theme.cardColor,
                  borderColor: Colors.transparent,
                  showBorder: false,
                  hintText: 'Rechercher un produit, une categorie...',
                  contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                  leadingSize: 24,
                  leadingIcon: Icon(
                    Icons.search_rounded,
                    color: isDark ? Colors.white70 : const Color(0xFF4A5B52),
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: const [
                  NavigationSearchChip(label: 'Samsung'),
                  NavigationSearchChip(label: 'Telephone'),
                  NavigationSearchChip(label: 'Mode'),
                  NavigationSearchChip(label: 'Cuisine'),
                  NavigationSearchChip(label: 'Auto'),
                  NavigationSearchChip(label: 'Laptop'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
