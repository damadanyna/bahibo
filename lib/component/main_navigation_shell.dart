import 'package:bahibo/page/productList.dart';
import 'package:bahibo/page/navigation/main_navigation_messages_panel.dart';
import 'package:bahibo/page/navigation/main_navigation_search_panel.dart';
import 'package:bahibo/page/navigation/main_navigation_account_panel.dart';
import 'package:flutter/material.dart';

import 'package:bahibo/theme/app_theme_extensions.dart';

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
      MainNavigationAccountPanel(),
    ];

    return Scaffold(
      backgroundColor: theme.cardColor,
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
    final appColors = theme.appColors;
    final barColor = theme.cardColor;
    final activeColor = theme.cardColor;
    final borderColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.outlineVariant.withValues(alpha: 0.18)
        : theme.colorScheme.onSurface.withValues(alpha: 0.12);
    final accentGreen = theme.colorScheme.primary;
    final inactiveIconColor = theme.brightness == Brightness.dark
        ? appColors.heroForeground
        : appColors.mutedText;
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
      return Icons.home;
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
