import 'package:bahibo/component/app_network_image.dart';
import 'package:bahibo/component/theme_menu_button.dart';
import 'package:bahibo/component/ui/dinamic_icon_input.dart';
import 'package:bahibo/page/category_page.dart';
import 'package:bahibo/page/productList.dart';
import 'package:bahibo/page/seller_chat_page.dart';
import 'package:flutter/material.dart';

class MainNavigationItem {
  final IconData icon;
  final String label;

  const MainNavigationItem({required this.icon, required this.label});
}

const List<MainNavigationItem> bahiboMainNavigationItems = [
  MainNavigationItem(icon: Icons.home_filled, label: 'Accueil'),
  MainNavigationItem(icon: Icons.search_rounded, label: 'Recherche'),
  MainNavigationItem(icon: Icons.message, label: 'Messages'),
  MainNavigationItem(icon: Icons.person, label: 'Compte'),
];

class BahiboNavigationShell extends StatefulWidget {
  const BahiboNavigationShell({super.key});

  @override
  State<BahiboNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<BahiboNavigationShell> {
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
    const pages = [
      Productlist(),
      MainNavigationSearchPanel(),
      MainNavigationMessagesPanel(),
      MainNavigationSettingsPanel(),
    ];

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
              items: bahiboMainNavigationItems,
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
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final theme = Theme.of(context);
    final barColor = theme.brightness == Brightness.dark
        ? const Color(0xFF04211B)
        : theme.scaffoldBackgroundColor;
    final activeColor = theme.cardColor;
    final borderColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.outlineVariant.withValues(alpha: 0.18)
        : theme.colorScheme.onSurface.withValues(alpha: 0.12);
    final accentGreen = theme.colorScheme.primary;
    final inactiveIconColor = theme.brightness == Brightness.dark
        ? Colors.white
        : Colors.grey.shade600;
    final activeIconColor = accentGreen;
    const innerHorizontalPadding = 16.0;
    const barHeight = 38.0;
    const activeBubbleSize = 35.0;
    const cradleSize = 50.0;

    return SizedBox(
      height: barHeight + bottomInset + 10,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth =
              constraints.maxWidth - (innerHorizontalPadding * 2);
          final slotWidth = contentWidth / items.length;
          final activeLeft =
              innerHorizontalPadding +
              (slotWidth * currentIndex) +
              ((slotWidth - activeBubbleSize) / 2);
          final cradleLeft =
              innerHorizontalPadding +
              (slotWidth * currentIndex) +
              ((slotWidth - cradleSize) / 2);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: barHeight + bottomInset,
                  padding: EdgeInsets.fromLTRB(
                    innerHorizontalPadding,
                    0,
                    innerHorizontalPadding,
                    bottomInset,
                  ),
                  decoration: BoxDecoration(
                    color: barColor,
                    border: Border(top: BorderSide(color: borderColor)),
                    // borderRadius: const BorderRadius.only(
                    //   topLeft: Radius.circular(barRadius),
                    //   topRight: Radius.circular(barRadius),
                    // ),
                  ),
                  child: SizedBox(
                    height: barHeight,
                    child: Row(
                      children: List.generate(items.length, (index) {
                        final isSelected = index == currentIndex;
                        return Expanded(
                          child: Center(
                            child: isSelected
                                ? const SizedBox(
                                    width: activeBubbleSize,
                                    height: activeBubbleSize,
                                  )
                                : _CapsuleNavigationButton(
                                    icon: _navigationDisplayIcon(
                                      index,
                                      items[index].icon,
                                    ),
                                    isSelected: false,
                                    activeColor: activeColor,
                                    iconColor: inactiveIconColor,
                                    onTap: () => onTap(index),
                                    size: activeBubbleSize,
                                  ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: cradleLeft,
                top: -((cradleSize - barHeight) / 1.4),
                child: Container(
                  width: cradleSize,
                  height: cradleSize,

                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor, width: 2.5),
                    color: barColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 0),
                curve: Curves.easeOutCubic,
                left: activeLeft,
                top: 1.4,
                child: _CapsuleNavigationButton(
                  icon: _navigationDisplayIcon(
                    currentIndex,
                    items[currentIndex].icon,
                  ),
                  isSelected: true,
                  activeColor: activeColor,
                  iconColor: activeIconColor,
                  onTap: () => onTap(currentIndex),
                  size: activeBubbleSize,
                ),
              ),
            ],
          );
        },
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
      return Icons.message;
    case 3:
      return Icons.person;
    default:
      return fallback;
  }
}

class MainNavigationSettingsPanel extends StatelessWidget {
  const MainNavigationSettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final categories = MainNavigationCategoryHubPanel._categories;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF08120E)
          : const Color(0xFFF2F8F3),
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
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
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
          ],
        ),
      ),
    );
  }
}

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

class MainNavigationMessagesPanel extends StatelessWidget {
  const MainNavigationMessagesPanel({super.key});

  static const _conversations =
      <
        ({
          String name,
          String preview,
          String time,
          String avatarUrl,
          bool unread,
        })
      >[
        (
          name: 'John Rakoto',
          preview: 'Bonjour, le Samsung S20 est-il toujours disponible ?',
          time: '13:06',
          avatarUrl:
              'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=600',
          unread: true,
        ),
        (
          name: 'Miora Andrianiaina',
          preview: 'Je peux vous envoyer les photos cet apres-midi.',
          time: '11:24',
          avatarUrl:
              'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300',
          unread: false,
        ),
        (
          name: 'Kevin R.',
          preview: 'Merci, je passe demain matin vers 9h.',
          time: 'Hier',
          avatarUrl:
              'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=300',
          unread: false,
        ),
        (
          name: 'Aina Shop',
          preview: 'Le produit est reserve jusqu a ce soir.',
          time: 'Lun',
          avatarUrl:
              'https://images.unsplash.com/photo-1544723795-3fb6469f5b39?w=300',
          unread: true,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final backgroundColor = isDark
        ? const Color(0xFF031915)
        : const Color(0xFFEAF5EE);
    final heroColor = isDark
        ? const Color(0xFF0C2C26)
        : const Color(0xFFDDF2E2);
    final searchFillColor = isDark ? const Color(0xFF17342E) : Colors.white;
    final quickActionColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : primary.withValues(alpha: 0.12);
    final titleColor = isDark ? Colors.white : const Color(0xFF0E2018);
    final mutedColor = isDark
        ? Colors.white.withValues(alpha: 0.74)
        : const Color(0xFF53665C);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(18, 20, 18, 0),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primary.withValues(alpha: isDark ? 0.2 : 0.14),
                    heroColor,
                    heroColor,
                  ],
                ),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : primary.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Messages',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: titleColor,
                          ),
                        ),
                      ),
                      _MessageActionButton(
                        icon: Icons.camera_alt_rounded,
                        backgroundColor: quickActionColor,
                        iconColor: titleColor,
                      ),
                      const SizedBox(width: 10),
                      _MessageActionButton(
                        icon: Icons.edit_rounded,
                        backgroundColor: quickActionColor,
                        iconColor: titleColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Retrouvez vos discussions recentes avec les autres utilisateurs.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: mutedColor,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _MessageSearchBar(
                    fillColor: searchFillColor,
                    iconColor: mutedColor,
                    hintColor: mutedColor,
                    borderColor: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFFD7E8DC),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 92,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _conversations.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 16),
                      itemBuilder: (context, index) {
                        final conversation = _conversations[index];
                        return _MessageStoryAvatar(
                          name: conversation.name.split(' ').first,
                          avatarUrl: conversation.avatarUrl,
                          isActive: true,
                          primary: primary,
                          labelColor: titleColor,
                          haloColor: heroColor,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
                itemCount: _conversations.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final conversation = _conversations[index];
                  return _ConversationTile(
                    name: conversation.name,
                    preview: conversation.preview,
                    time: conversation.time,
                    avatarUrl: conversation.avatarUrl,
                    unread: conversation.unread,
                    primary: primary,
                    isDark: isDark,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SellerChatPage(),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageSearchBar extends StatefulWidget {
  final Color fillColor;
  final Color iconColor;
  final Color hintColor;
  final Color borderColor;

  const _MessageSearchBar({
    required this.fillColor,
    required this.iconColor,
    required this.hintColor,
    required this.borderColor,
  });

  @override
  State<_MessageSearchBar> createState() => _MessageSearchBarState();
}

class _MessageSearchBarState extends State<_MessageSearchBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DynamicIconInput(
      controller: _controller,
      primary: widget.iconColor,
      panelColor: widget.fillColor,
      borderColor: widget.borderColor,
      hintText: 'Rechercher dans message',
      contentPadding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      leadingSize: 26,
      leadingIcon: Icon(
        Icons.search_rounded,
        color: widget.iconColor,
        size: 22,
      ),
      onLeadingTap: () {},
    );
  }
}

class _MessageStoryAvatar extends StatelessWidget {
  final String name;
  final String avatarUrl;
  final bool isActive;
  final Color primary;
  final Color labelColor;
  final Color haloColor;

  const _MessageStoryAvatar({
    required this.name,
    required this.avatarUrl,
    required this.isActive,
    required this.primary,
    required this.labelColor,
    required this.haloColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: primary.withValues(alpha: 0.42)),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: AppCircleNetworkAvatar(radius: 26, imageUrl: avatarUrl),
              ),
              if (isActive)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFF61D86A),
                      shape: BoxShape.circle,
                      border: Border.all(color: haloColor, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: labelColor,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final String name;
  final String preview;
  final String time;
  final String avatarUrl;
  final bool unread;
  final Color primary;
  final bool isDark;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.name,
    required this.preview,
    required this.time,
    required this.avatarUrl,
    required this.unread,
    required this.primary,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = unread
        ? (isDark ? const Color(0xFF0A2824) : Colors.white)
        : (isDark ? const Color(0xFF061E1A) : const Color(0xFFF5FBF6));
    final titleColor = isDark ? Colors.white : const Color(0xFF11221A);
    final previewColor = isDark
        ? Colors.white.withValues(alpha: unread ? 0.86 : 0.68)
        : const Color(0xFF56685F);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: unread
                  ? primary.withValues(alpha: isDark ? 0.22 : 0.16)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFDCE9DF)),
            ),
            boxShadow: unread
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.18 : 0.05,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: primary.withValues(alpha: unread ? 0.42 : 0.18),
                      ),
                    ),
                    child: AppCircleNetworkAvatar(
                      radius: 28,
                      imageUrl: avatarUrl,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 1,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF61D86A),
                        shape: BoxShape.circle,
                        border: Border.all(color: surfaceColor, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: titleColor,
                              fontWeight: unread
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Text(
                          time,
                          style: TextStyle(
                            color: unread ? primary : previewColor,
                            fontWeight: unread
                                ? FontWeight.w800
                                : FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: previewColor,
                              fontWeight: unread
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 10),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFF56C04E),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
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

class _MessageActionButton extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;

  const _MessageActionButton({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: Icon(icon, color: iconColor, size: 20),
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
          // decoration: BoxDecoration(
          //   color: isSelected ? activeColor : Colors.transparent,
          //   shape: BoxShape.circle,
          // ),
          child: Icon(icon, size: isSelected ? 35 : 23, color: iconColor),
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
