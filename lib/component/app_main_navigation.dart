import 'package:flutter/material.dart';

class AppMainNavigationItem {
  final IconData icon;
  final String label;

  const AppMainNavigationItem({required this.icon, required this.label});
}

class AppMainNavigationBar extends StatelessWidget {
  final int currentIndex;
  final List<AppMainNavigationItem> items;
  final ValueChanged<int> onTap;

  const AppMainNavigationBar({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const barColor = Colors.green; // Color(0xFF1E56E6);

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: SizedBox(
        height: 92,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 68,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: List.generate(items.length, (index) {
                    final item = items[index];
                    final isSelected = index == currentIndex;
                    final isHome = index == 0;

                    return Expanded(
                      child: Align(
                        alignment: isHome
                            ? const Alignment(-0.15, 0)
                            : Alignment.center,
                        child: _AppMainNavigationButton(
                          icon: item.icon,
                          selected: isSelected,
                          highlighted: isHome && isSelected,
                          onTap: () => onTap(index),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            Positioned(
              left: -2,
              top: 6,
              child: Container(
                width: 58,
                height: 46,
                decoration: const BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(30),
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(34),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 20,
              top: 0,
              child: GestureDetector(
                onTap: () => onTap(0),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.home_filled,
                    color: barColor,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppMainNavigationMenuButton extends StatelessWidget {
  final int currentIndex;
  final List<AppMainNavigationItem> items;
  final ValueChanged<int> onSelected;

  const AppMainNavigationMenuButton({
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
                color: isSelected
                    ? Colors.green
                    : null, // Color(0xFF1E56E6) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? Colors.green
                        : null, // Color(0xFF1E56E6) : null,
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

class _AppMainNavigationButton extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final bool highlighted;
  final VoidCallback onTap;

  const _AppMainNavigationButton({
    required this.icon,
    required this.selected,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (highlighted) {
      return const SizedBox(width: 38, height: 38);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(
            icon,
            size: 27,
            color: selected ? Colors.white : Colors.white.withOpacity(0.92),
          ),
        ),
      ),
    );
  }
}
