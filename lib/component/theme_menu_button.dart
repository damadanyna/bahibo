import 'package:bahibo/providers/theme_provider.dart';
import 'package:bahibo/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ThemeMenuButton extends StatelessWidget {
  final Widget? icon;

  const ThemeMenuButton({super.key, this.icon});

  const ThemeMenuButton.icon({super.key, this.icon});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final theme = Theme.of(context);

        return IconButton(
          onPressed: () => _showThemeSheet(context, themeProvider),
          icon: icon ?? const Icon(Icons.person),
          tooltip: 'Changer le theme',
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            foregroundColor: theme.colorScheme.primary,
            padding: const EdgeInsets.all(12),
          ),
        );
      },
    );
  }

  Future<void> _showThemeSheet(
    BuildContext context,
    ThemeProvider themeProvider,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final sheetTheme = Theme.of(sheetContext);
        final appColors = sheetTheme.appColors;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              decoration: BoxDecoration(
                color: sheetTheme.cardColor,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: appColors.scrimSoft,
                    blurRadius: 30,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: sheetTheme.dividerColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          colors: [
                            sheetTheme.colorScheme.primary.withValues(
                              alpha: 0.18,
                            ),
                            sheetTheme.colorScheme.primary.withValues(
                              alpha: 0.08,
                            ),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: sheetTheme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.palette_outlined,
                              color: sheetTheme.colorScheme.onPrimary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Apparence',
                                  style: sheetTheme.textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Choisis un style qui correspond a ton ambiance.',
                                  style: sheetTheme.textTheme.bodyMedium
                                      ?.copyWith(
                                        color: sheetTheme.colorScheme.onSurface
                                            .withValues(alpha: 0.72),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...ThemeMode.values.map(
                      (mode) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ThemeModeTile(
                          mode: mode,
                          isSelected: themeProvider.themeMode == mode,
                          onTap: () {
                            themeProvider.setThemeMode(mode);
                            Navigator.of(sheetContext).pop();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  final ThemeMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeModeTile({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appColors = theme.appColors;
    final data = _themeModePresentation(mode, context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outline.withValues(alpha: 0.18),
              width: isSelected ? 1.4 : 1,
            ),
            gradient: LinearGradient(
              colors: isSelected
                  ? [
                      data.tint.withValues(alpha: 0.2),
                      colorScheme.primary.withValues(alpha: 0.08),
                    ]
                  : [theme.cardColor, theme.cardColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: data.tint.withValues(alpha: isSelected ? 0.24 : 0.14),
                ),
                child: Icon(data.icon, color: data.tint),
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
                            data.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Actif',
                              style: TextStyle(
                                color: appColors.heroForeground,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data.subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.72),
                      ),
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

_ThemeModePresentation _themeModePresentation(
  ThemeMode mode,
  BuildContext context,
) {
  final theme = Theme.of(context);
  final appColors = theme.appColors;

  switch (mode) {
    case ThemeMode.light:
      return _ThemeModePresentation(
        title: 'Mode clair',
        subtitle: 'Interface lumineuse, nette et legere.',
        icon: Icons.wb_sunny_rounded,
        tint: theme.colorScheme.primary,
      );
    case ThemeMode.dark:
      return _ThemeModePresentation(
        title: 'Mode sombre',
        subtitle: 'Ambiance nocturne avec contraste plus doux.',
        icon: Icons.dark_mode_rounded,
        tint: appColors.heroAccent,
      );
    case ThemeMode.system:
      return _ThemeModePresentation(
        title: 'Systeme',
        subtitle: 'Suit automatiquement le theme de ton appareil.',
        icon: Icons.devices_rounded,
        tint: theme.colorScheme.secondary,
      );
  }
}

class _ThemeModePresentation {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;

  const _ThemeModePresentation({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
  });
}
