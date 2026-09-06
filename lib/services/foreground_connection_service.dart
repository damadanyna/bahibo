import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
void _foregroundConnectionTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_ForegroundConnectionTaskHandler());
}

/// No-op on purpose: the only job of this foreground service is to keep the
/// app's Android process alive so the socket connection already managed by
/// ChatRealtimeService (in the main isolate, same process) survives being
/// backgrounded on OEM skins (ColorOS, MIUI, ...) that would otherwise kill
/// it. There is nothing to actually run inside this separate task isolate.
class _ForegroundConnectionTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

/// Keeps Banay's process alive in the background via a persistent Android
/// foreground-service notification. Android-only — iOS has no equivalent
/// mechanism, and this is a deliberately heavier-handed complement to
/// BatteryOptimizationService's opt-in prompt: starting this doesn't need
/// extra user consent beyond the standard notification permission already
/// requested by PushNotificationService.
class ForegroundConnectionService {
  ForegroundConnectionService._();

  static final ForegroundConnectionService instance =
      ForegroundConnectionService._();

  static const int _serviceId = 4001;

  /// Opt-in, off by default (Telegram / Signal model): FCM high-priority push
  /// is the primary background mechanism for everyone, and the always-on
  /// notification that Android forces on a foreground service is only shown
  /// to users who explicitly enabled the "reinforced connection" toggle.
  static const String _enabledPrefsKey = 'banay_reinforced_connection_enabled';
  bool _isInitialized = false;

  static bool get isSupportedPlatform {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android;
  }

  Future<bool> get isRunning async {
    if (!isSupportedPlatform) {
      return false;
    }
    return FlutterForegroundTask.isRunningService;
  }

  void _ensureInitialized() {
    if (_isInitialized || !isSupportedPlatform) {
      return;
    }
    _isInitialized = true;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        // Android freezes a channel's importance once created, so lowering it
        // needs a new channel id; the old 'banay_background_connection' one
        // stays orphaned in the system settings on existing installs.
        channelId: 'banay_background_connection_quiet',
        channelName: 'Connexion Banay',
        channelDescription:
            'Maintient Banay actif pour recevoir vos messages en arrière-plan.',
        // MIN: no status-bar icon, collapsed into the "silent" section of the
        // shade. The service itself is unchanged; only the notice is quieter.
        channelImportance: NotificationChannelImportance.MIN,
        priority: NotificationPriority.MIN,
        visibility: NotificationVisibility.VISIBILITY_SECRET,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: false,
        allowWifiLock: false,
      ),
    );
  }

  Future<void> start() async {
    if (!isSupportedPlatform || await isRunning) {
      return;
    }

    _ensureInitialized();

    final notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: [ForegroundServiceTypes.remoteMessaging],
      notificationTitle: 'Banay',
      notificationText: 'Connecté pour vos messages',
      callback: _foregroundConnectionTaskCallback,
    );
  }

  Future<void> stop() async {
    if (!isSupportedPlatform) {
      return;
    }
    await FlutterForegroundTask.stopService();
  }

  Future<bool> get isEnabledByUser async {
    if (!isSupportedPlatform) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledPrefsKey) == true;
  }

  /// Post-login entry point: only holds the process open when the user asked
  /// for it. Logout paths keep calling [stop] unconditionally, which is a no-op
  /// when the service was never started.
  Future<void> startIfEnabled() async {
    if (await isEnabledByUser) {
      await start();
    } else {
      // Defensive: a service left running by a previous build (before the
      // opt-in existed) must not survive the first launch of this one.
      await stop();
    }
  }

  /// Persists the choice and applies it immediately.
  Future<void> setEnabledByUser(bool enabled) async {
    if (!isSupportedPlatform) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledPrefsKey, enabled);
    if (enabled) {
      await start();
    } else {
      await stop();
    }
  }
}
