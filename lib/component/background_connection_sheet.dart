import 'package:banay/services/foreground_connection_service.dart';
import 'package:banay/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';

/// Settings sheet for the opt-in "reinforced connection" foreground service.
/// Android-only by design: callers should hide the entry point elsewhere
/// (see ForegroundConnectionService.isSupportedPlatform).
Future<void> showBackgroundConnectionSheet(BuildContext context) {
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
            child: const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: _BackgroundConnectionSheetBody(),
            ),
          ),
        ),
      );
    },
  );
}

class _BackgroundConnectionSheetBody extends StatefulWidget {
  const _BackgroundConnectionSheetBody();

  @override
  State<_BackgroundConnectionSheetBody> createState() =>
      _BackgroundConnectionSheetBodyState();
}

class _BackgroundConnectionSheetBodyState
    extends State<_BackgroundConnectionSheetBody> {
  bool? _isEnabled;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final enabled = await ForegroundConnectionService.instance.isEnabledByUser;
    if (mounted) {
      setState(() => _isEnabled = enabled);
    }
  }

  Future<void> _toggle(bool enabled) async {
    if (_isBusy) {
      return;
    }
    setState(() {
      _isBusy = true;
      _isEnabled = enabled;
    });
    try {
      await ForegroundConnectionService.instance.setEnabledByUser(enabled);
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEnabled = _isEnabled;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          child: Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: theme.dividerColor.withValues(alpha: 0.5),
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
                colorScheme.primary.withValues(alpha: 0.18),
                colorScheme.primary.withValues(alpha: 0.08),
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
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.wifi_tethering_rounded,
                  color: colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connexion renforcee',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pour les telephones qui retardent les messages.',
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
        const SizedBox(height: 16),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: isEnabled ?? false,
          onChanged: isEnabled == null || _isBusy ? null : _toggle,
          title: Text(
            'Garder Banay actif en arriere-plan',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Affiche une notification permanente, mais garantit la '
              'reception des messages meme quand le telephone limite les '
              'applications en arriere-plan. Laissez desactive si vos '
              'messages arrivent deja correctement.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.64),
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
