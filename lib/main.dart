import 'dart:io';

import 'package:banay/auth/session_gate.dart';
import 'package:banay/services/api_config.dart';
import 'package:banay/services/chat_realtime_service.dart';
import 'package:banay/services/location_permission_service.dart';
import 'package:banay/providers/theme_provider.dart';
import 'package:banay/services/push_notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

enum _LocationPermissionDialogAction { later, continueRequest }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _configureDevelopmentTlsOverride();
  await PushNotificationService.initialize();

  // Désactiver la rotation et forcer le mode portrait
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MyApp());
}

void _configureDevelopmentTlsOverride() {
  if (kReleaseMode) {
    return;
  }

  final apiUri = Uri.tryParse(ApiConfig.baseUrl);
  final host = apiUri?.host;
  if (apiUri == null ||
      apiUri.scheme != 'https' ||
      host == null ||
      host.isEmpty) {
    return;
  }

  HttpOverrides.global = _BanayDevHttpOverrides(allowedHost: host);
}

class _BanayDevHttpOverrides extends HttpOverrides {
  _BanayDevHttpOverrides({required this.allowedHost});

  final String allowedHost;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (cert, host, port) {
      return host == allowedHost;
    };
    return client;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AppLifecycleBootstrap();
  }
}

class _AppLifecycleBootstrap extends StatefulWidget {
  const _AppLifecycleBootstrap();

  @override
  State<_AppLifecycleBootstrap> createState() => _AppLifecycleBootstrapState();
}

class _AppLifecycleBootstrapState extends State<_AppLifecycleBootstrap>
    with WidgetsBindingObserver {
  Future<void> _showLocationPermissionPreDialog() async {
    while (mounted) {
      final permission =
          await LocationPermissionService.checkPermissionStatus();
      if (!mounted) {
        return;
      }

      if (!LocationPermissionService.shouldExplainOnLaunch(permission)) {
        return;
      }

      final dialogContext = PushNotificationService.navigatorKey.currentContext;
      if (dialogContext == null || !dialogContext.mounted) {
        return;
      }
      final isDeniedForever = permission == LocationPermission.deniedForever;
      final action = await showDialog<_LocationPermissionDialogAction>(
        context: dialogContext,
        barrierDismissible: false,
        builder: (context) {
          return _LocationPermissionDialog(isDeniedForever: isDeniedForever);
        },
      );
      if (!mounted) {
        return;
      }

      if (action != _LocationPermissionDialogAction.continueRequest) {
        await Future<void>.delayed(const Duration(milliseconds: 220));
        continue;
      }

      if (isDeniedForever) {
        await LocationPermissionService.openAppSettingsForPermission();
      } else {
        await LocationPermissionService.requestPermissionAfterExplanation();
      }

      if (!mounted) {
        return;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showLocationPermissionPreDialog();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ChatRealtimeService.instance.handleAppLifecycleStateChanged(state);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            navigatorKey: PushNotificationService.navigatorKey,
            navigatorObservers: [PushNotificationService.routeObserver],
            home: const SessionGatePage(),
            theme: ThemeProvider.lightTheme,
            darkTheme: ThemeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
          );
        },
      ),
    );
  }
}

class _LocationPermissionDialog extends StatelessWidget {
  final bool isDeniedForever;

  const _LocationPermissionDialog({required this.isDeniedForever});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final surfaceTint = isDeniedForever
        ? colors.error.withValues(alpha: 0.18)
        : colors.primary.withValues(alpha: 0.18);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.18),
              blurRadius: 30,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: [
                      surfaceTint,
                      colors.surfaceContainerHighest.withValues(alpha: 0.88),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: isDeniedForever ? colors.error : colors.primary,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Icon(
                        isDeniedForever
                            ? Icons.settings_suggest_rounded
                            : Icons.location_searching_rounded,
                        color: colors.onPrimary,
                        size: 34,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isDeniedForever
                                ? 'Autorisation bloquee'
                                : 'Active la localisation',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isDeniedForever
                                ? 'Ouvre les reglages pour autoriser BANAY a acceder a ta position.'
                                : 'BANAY a besoin de ta position pour afficher ce qui est pertinent autour de toi.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurface.withValues(alpha: 0.76),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _PermissionInfoRow(
                icon: Icons.storefront_rounded,
                label: 'Voir les profils, vendeurs et contenus proches de toi.',
                tint: colors.primary,
              ),
              const SizedBox(height: 10),
              _PermissionInfoRow(
                icon: Icons.local_shipping_rounded,
                label:
                    'Mieux preparer la livraison et les options autour de ta zone.',
                tint: colors.secondary,
              ),
              const SizedBox(height: 10),
              _PermissionInfoRow(
                icon: Icons.shield_moon_rounded,
                label: isDeniedForever
                    ? 'Android a bloque la demande. Il faut maintenant passer par les reglages.'
                    : 'Ta position reste utilisee pour ameliorer l\'experience dans BANAY.',
                tint: isDeniedForever ? colors.error : colors.tertiary,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(_LocationPermissionDialogAction.later),
                      icon: const Icon(Icons.schedule_rounded),
                      label: const Text('Plus tard'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(_LocationPermissionDialogAction.continueRequest),
                      icon: Icon(
                        isDeniedForever
                            ? Icons.open_in_new_rounded
                            : Icons.my_location_rounded,
                      ),
                      label: Text(
                        isDeniedForever ? 'Ouvrir reglages' : 'Autoriser',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color tint;

  const _PermissionInfoRow({
    required this.icon,
    required this.label,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: tint, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.onSurface.withValues(alpha: 0.84),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
