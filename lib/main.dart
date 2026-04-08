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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LocationPermissionService.ensurePermissionRequestedOnLaunch();
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
