import 'package:bahibo/component/theme_menu_button.dart';
import 'package:bahibo/page/category_page.dart';
import 'package:flutter/material.dart';

typedef MainNavigationPagesBuilder =
    List<Widget> Function(
      int currentIndex,
      List<MainNavigationItem> items,
      ValueChanged<int> onIndexChanged,
    );

class MainNavigationItem {
  final IconData icon;
  final String label;

  const MainNavigationItem({required this.icon, required this.label});
}

const List<MainNavigationItem> bahiboMainNavigationItems = [
  MainNavigationItem(icon: Icons.home_filled, label: 'Accueil'),
  MainNavigationItem(icon: Icons.settings, label: 'Parametres'),
  MainNavigationItem(icon: Icons.search_rounded, label: 'Recherche'),
  MainNavigationItem(icon: Icons.grid_view_rounded, label: 'Categories'),
];

class MainNavigationShell extends StatefulWidget {
  final List<MainNavigationItem> items;
  final MainNavigationPagesBuilder pagesBuilder;

  const MainNavigationShell({
    super.key,
    required this.items,
    required this.pagesBuilder,
  });

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  void _handleNavigationSelection(int index) {
    if (_currentIndex == index) {
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pages = widget.pagesBuilder(
      _currentIndex,
      widget.items,
      _handleNavigationSelection,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(index: _currentIndex, children: pages),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MainNavigationBar(
              currentIndex: _currentIndex,
              items: widget.items,
              onTap: _handleNavigationSelection,
            ),
          ),
        ],
      ),
    );
  }
}

class MainNavigationBar extends StatelessWidget {
  final int currentIndex;
  final List<MainNavigationItem> items;
  final ValueChanged<int> onTap;

  const MainNavigationBar({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const barColor = Color(0xFFD7AF83);
    const activeColor = Color(0xFFE9C8A0);
    const iconColor = Colors.white;
    const horizontalPadding = 18.0;
    const barHeight = 58.0;
    const barRadius = 18.0;
    const activeBubbleSize = 42.0;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: barHeight,
        padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
        decoration: BoxDecoration(
          color: barColor,
          borderRadius: BorderRadius.circular(barRadius),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(items.length, (index) {
            final isSelected = index == currentIndex;
            return _CapsuleNavigationButton(
              icon: _navigationDisplayIcon(index, items[index].icon),
              isSelected: isSelected,
              activeColor: activeColor,
              iconColor: iconColor,
              onTap: () => onTap(index),
              size: activeBubbleSize,
            );
          }),
        ),
      ),
    );
  }
}

IconData _navigationDisplayIcon(int index, IconData fallback) {
  switch (index) {
    case 0:
      return Icons.home_outlined;
    case 1:
      return Icons.search_rounded;
    case 2:
      return Icons.favorite_border_rounded;
    case 3:
      return Icons.person_outline_rounded;
    default:
      return fallback;
  }
}

class MainNavigationMenuButton extends StatelessWidget {
  final int currentIndex;
  final List<MainNavigationItem> items;
  final ValueChanged<int> onSelected;

  const MainNavigationMenuButton({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Navigation',
      icon: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white10
                : const Color(0xFFD6E4DA),
          ),
        ),
        child: const Icon(Icons.menu_rounded),
      ),
      onSelected: onSelected,
      itemBuilder: (context) => List.generate(items.length, (index) {
        final item = items[index];
        final isSelected = index == currentIndex;
        return PopupMenuItem<int>(
          value: index,
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 20,
                color: isSelected ? const Color(0xFF1E56E6) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? const Color(0xFF1E56E6) : null,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class MainNavigationSettingsPanel extends StatelessWidget {
  const MainNavigationSettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF08120E)
          : const Color(0xFFF2F8F3),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
            ],
          ),
        ),
      ),
    );
  }
}

class MainNavigationSearchPanel extends StatelessWidget {
  const MainNavigationSearchPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF08120E)
          : const Color(0xFFF6FBF7),
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
                child: TextField(
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    icon: Icon(
                      Icons.search_rounded,
                      color: isDark ? Colors.white70 : const Color(0xFF4A5B52),
                    ),
                    hintText: 'Rechercher un produit, une categorie...',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: const [
                  _SearchChip(label: 'Samsung'),
                  _SearchChip(label: 'Telephone'),
                  _SearchChip(label: 'Mode'),
                  _SearchChip(label: 'Cuisine'),
                  _SearchChip(label: 'Auto'),
                  _SearchChip(label: 'Laptop'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainNavigationCategoryHubPanel extends StatelessWidget {
  const MainNavigationCategoryHubPanel({super.key});

  static const _categories = <({String icon, String label, String slug})>[
    (icon: '📱', label: 'Smartphones', slug: 'smartphones'),
    (icon: '💻', label: 'Laptops', slug: 'laptops'),
    (icon: '🧴', label: 'Skincare', slug: 'skincare'),
    (icon: '🏠', label: 'Home decoration', slug: 'home-decoration'),
    (icon: '🚗', label: 'Automotive', slug: 'automotive'),
    (icon: '💄', label: 'Beauty', slug: 'beauty'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF08120E)
          : const Color(0xFFF2F7F3),
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
              Expanded(
                child: GridView.builder(
                  itemCount: _categories.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.08,
                  ),
                  itemBuilder: (context, index) {
                    final category = _categories[index];
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
                            border: Border.all(
                              color: isDark
                                  ? Colors.white10
                                  : const Color(0xFFD6E4DA),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category.icon,
                                style: const TextStyle(fontSize: 30),
                              ),
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
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(0xFF64756B),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _CapsuleNavigationButton extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final Color activeColor;
  final Color iconColor;
  final VoidCallback onTap;
  final double size;

  const _CapsuleNavigationButton({
    required this.icon,
    required this.isSelected,
    required this.activeColor,
    required this.iconColor,
    required this.onTap,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 25, color: iconColor),
        ),
      ),
    );
  }
}

class _SearchChip extends StatelessWidget {
  final String label;

  const _SearchChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFD6E4DA),
        ),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}
