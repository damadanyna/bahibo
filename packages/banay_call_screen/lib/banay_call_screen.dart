import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';

/// Android: the plugin's own ringing call screen, opened by Banay itself
/// when the user allowed it to draw over other apps (see the package
/// description). No-op everywhere else.
class BanayCallScreen {
  BanayCallScreen._();

  static const MethodChannel _channel = MethodChannel('banay/call_screen');

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  /// Whether "Display over other apps" is granted, the one condition under
  /// which [show] can work.
  static Future<bool> canDrawOverlays() async {
    if (!_supported) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('canDrawOverlays') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the call screen for [params], the same ones already given to
  /// `FlutterCallkitIncoming.showCallkitIncoming`. True when the activity
  /// was started; false when the permission is missing or the OS refused.
  static Future<bool> show(CallKitParams params) async {
    if (!_supported) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('show', params.toJson()) ??
          false;
    } catch (error) {
      debugPrint('Call screen not opened: $error');
      return false;
    }
  }
}
