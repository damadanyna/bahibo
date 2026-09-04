import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Google Play In-App Updates: brings users still on an old version to the
/// current one without waiting for the store's own auto-update cycle.
///
/// - Update priority >= [_forcedPriorityThreshold] (set per release in the
///   Play Console / Publishing API): blocking "immediate" flow, the app cannot
///   be used until updated.
/// - Otherwise: "flexible" flow, downloaded in the background, then a
///   snackbar offers to restart. Prompted at most once per [_promptInterval]
///   so it never nags.
///
/// Android + Play Store installs only; every other case is a silent no-op.
class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  static const String _lastPromptKey = 'app_update_last_prompt_at';
  static const Duration _promptInterval = Duration(hours: 12);
  static const int _forcedPriorityThreshold = 4;

  bool _checking = false;

  Future<void> checkForUpdate(BuildContext context) async {
    if (kIsWeb ||
        kDebugMode ||
        defaultTargetPlatform != TargetPlatform.android ||
        _checking) {
      return;
    }
    _checking = true;
    try {
      final info = await InAppUpdate.checkForUpdate();

      if (info.installStatus == InstallStatus.downloaded) {
        // A flexible update finished downloading during a previous session.
        await InAppUpdate.completeFlexibleUpdate();
        return;
      }
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }

      final forced =
          info.updatePriority >= _forcedPriorityThreshold &&
          info.immediateUpdateAllowed;
      if (forced) {
        await InAppUpdate.performImmediateUpdate();
        return;
      }

      if (!info.flexibleUpdateAllowed || !await _shouldPromptAgain()) {
        return;
      }
      await _markPrompted();

      final result = await InAppUpdate.startFlexibleUpdate();
      if (result != AppUpdateResult.success || !context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Mise a jour telechargee.'),
          duration: const Duration(seconds: 12),
          action: SnackBarAction(
            label: 'Redemarrer',
            onPressed: () => unawaited(InAppUpdate.completeFlexibleUpdate()),
          ),
        ),
      );
    } catch (_) {
      // Sideloaded / non-Play install, Play services unavailable, or the
      // user dismissed the dialog: never block the app for an update check.
    } finally {
      _checking = false;
    }
  }

  Future<bool> _shouldPromptAgain() async {
    final prefs = await SharedPreferences.getInstance();
    final lastPromptMillis = prefs.getInt(_lastPromptKey);
    if (lastPromptMillis == null) {
      return true;
    }
    final lastPrompt = DateTime.fromMillisecondsSinceEpoch(lastPromptMillis);
    return DateTime.now().difference(lastPrompt) >= _promptInterval;
  }

  Future<void> _markPrompted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastPromptKey, DateTime.now().millisecondsSinceEpoch);
  }
}
