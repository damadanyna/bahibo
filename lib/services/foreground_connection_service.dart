import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

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
        channelId: 'banay_background_connection',
        channelName: 'Connexion Banay',
        channelDescription:
            'Maintient Banay actif pour recevoir vos messages en arriere-plan.',
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
      notificationText: 'Actif en arriere-plan pour recevoir vos messages.',
      callback: _foregroundConnectionTaskCallback,
    );
  }

  Future<void> stop() async {
    if (!isSupportedPlatform) {
      return;
    }
    await FlutterForegroundTask.stopService();
  }
}
