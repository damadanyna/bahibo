import 'dart:async';

import 'package:banay/localization/banay_localizations.dart';
import 'package:banay_call_screen/banay_call_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Android "Display over other apps" (SYSTEM_ALERT_WINDOW): the one setting
/// that still lets Banay open its incoming-call screen from the background,
/// Google Play having refused USE_FULL_SCREEN_INTENT (2026-09-11). See
/// `IncomingCallNativeUi` for what happens with and without it.
///
/// Asked once, like the battery-optimization prompt, but behind a short
/// explanation: the system offers no dialog for it, only a bare settings
/// page the user would otherwise land on without knowing why.
class CallScreenPermissionService {
  CallScreenPermissionService._();

  static const String _promptShownPrefsKey =
      'call_screen_overlay_prompt_shown_v1';

  static bool get isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> isGranted() async {
    if (!isSupportedPlatform) {
      return false;
    }
    return BanayCallScreen.canDrawOverlays();
  }

  /// False on other platforms, when already granted, or once the prompt has
  /// been shown, whatever the user picked then.
  static Future<bool> shouldShowPrompt() async {
    if (!isSupportedPlatform || await isGranted()) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_promptShownPrefsKey) != true;
  }

  static Future<void> markPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_promptShownPrefsKey, true);
  }

  /// Opens the system page for this app; resolves when the user comes back.
  static Future<bool> request() async {
    if (!isSupportedPlatform) {
      return false;
    }
    try {
      final status = await Permission.systemAlertWindow.request();
      return status.isGranted;
    } catch (error) {
      debugPrint('Overlay permission request failed: $error');
      return false;
    }
  }

  /// One-time explanation, then [request] if the user agrees.
  static Future<void> showPromptIfNeeded(BuildContext context) async {
    if (!await shouldShowPrompt()) {
      return;
    }
    await markPromptShown();
    if (!context.mounted) {
      return;
    }
    final agreed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.phone_in_talk_outlined, size: 32),
        title: Text(
          dialogContext.tr(BanayLocalizationKeys.callScreenPermissionTitle),
          textAlign: TextAlign.center,
        ),
        content: Text(
          dialogContext.tr(BanayLocalizationKeys.callScreenPermissionMessage),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.tr(BanayLocalizationKeys.later)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.tr(BanayLocalizationKeys.allow)),
          ),
        ],
      ),
    );
    if (agreed == true) {
      await request();
    }
  }
}
