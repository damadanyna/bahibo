import 'package:bahibo/auth/session_gate.dart';
import 'package:bahibo/services/chat_realtime_service.dart';
import 'package:bahibo/services/location_permission_service.dart';
import 'package:bahibo/providers/theme_provider.dart';
import 'package:bahibo/services/push_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotificationService.initialize();

  // Désactiver la rotation et forcer le mode portrait
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MyApp());
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
    final permission = await LocationPermissionService.checkPermissionStatus();
    if (!LocationPermissionService.shouldExplainOnLaunch(permission)) {
      return;
    }

    final dialogContext =
        PushNotificationService.navigatorKey.currentContext ?? context;
    final theme = Theme.of(dialogContext);
    final confirmed = await showDialog<bool>(
      context: dialogContext,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Activer votre localisation'),
          content: const Text(
            'Bahibo utilise votre localisation pour mieux afficher les profils, les contenus et les options proches de vous.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Plus tard',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Continuer', style: TextStyle(color: colors.primary)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await LocationPermissionService.requestPermissionAfterExplanation();
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
