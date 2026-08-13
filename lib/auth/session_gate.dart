import 'package:banay/auth/language.dart';
import 'package:banay/component/main_navigation_shell.dart';
import 'package:banay/services/app_auth_service.dart';
import 'package:banay/services/chat_realtime_service.dart';
import 'package:banay/services/push_notification_service.dart';
import 'package:banay/services/share_intent_service.dart';
import 'package:banay/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';

class SessionGatePage extends StatefulWidget {
  const SessionGatePage({super.key});

  @override
  State<SessionGatePage> createState() => _SessionGatePageState();
}

class _SessionGatePageState extends State<SessionGatePage> {
  final AppAuthService _authService = AppAuthService();
  late final Future<bool> _sessionFuture;
  bool _didBootstrapAuthenticatedSession = false;

  @override
  void initState() {
    super.initState();
    _sessionFuture = _authService.restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;

    return FutureBuilder<bool>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: appColors.backgroundBase,
            body: Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            ),
          );
        }

        if (snapshot.data == true) {
          if (!_didBootstrapAuthenticatedSession) {
            _didBootstrapAuthenticatedSession = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await ChatRealtimeService.instance.ensureConnected();
              await PushNotificationService.syncDeviceTokenIfAuthenticated();
              await PushNotificationService.processPendingNotificationNavigation();
              await ShareIntentService.instance.processPendingShareNavigation();
            });
          }
          return BANAYNavigationShell(key: BANAYNavigationShell.shellKey);
        }

        return const LanguagePage();
      },
    );
  }
}


