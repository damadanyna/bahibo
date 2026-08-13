import 'package:banay/services/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helps the user exempt Banay from Android's battery optimization and, on
/// OEM skins (ColorOS, MIUI, FuntouchOS, EMUI, ...) that layer their own
/// aggressive background/auto-start management on top of stock Android,
/// opens that manufacturer's auto-start settings screen too. Without this,
/// the OS can kill the app or block background FCM delivery even after all
/// the app-side reliability fixes (grace-period disconnect, delivery ping,
/// TLS re-init in the background isolate) — this is a device setting, not
/// something app code alone can control.
class BatteryOptimizationService {
  BatteryOptimizationService._();

  static const String _promptShownPrefsKey = 'battery_optimization_prompt_shown_v1';
  static const MethodChannel _channel = MethodChannel(
    'banay/battery_optimization',
  );

  static bool get isSupportedPlatform {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android;
  }

  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!isSupportedPlatform) {
      return true;
    }

    final status = await Permission.ignoreBatteryOptimizations.status;
    return status.isGranted;
  }

  /// Whether the one-time prompt should be shown: unsupported platform or
  /// already-granted status short-circuit to false, and it never shows
  /// twice regardless of what the user picked the first time.
  static Future<bool> shouldShowPrompt() async {
    if (!isSupportedPlatform) {
      return false;
    }

    if (await isIgnoringBatteryOptimizations()) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_promptShownPrefsKey) != true;
  }

  static Future<void> markPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_promptShownPrefsKey, true);
  }

  static Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!isSupportedPlatform) {
      return true;
    }

    final status = await Permission.ignoreBatteryOptimizations.request();
    return status.isGranted;
  }

  /// Best-effort: not every manufacturer/firmware version exposes this
  /// screen under the same component name, so this can silently fall back
  /// to the app's own system settings page on the native side.
  static Future<void> openManufacturerAutostartSettings() async {
    if (!isSupportedPlatform) {
      return;
    }

    try {
      await _channel.invokeMethod<bool>('openManufacturerAutostartSettings');
    } catch (error) {
      AppLogger.warning(
        'BatteryOptimizationService',
        'openManufacturerAutostartSettings failed',
        error,
      );
    }
  }
}
