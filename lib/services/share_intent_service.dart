import 'dart:async';

import 'package:banay/component/main_navigation_shell.dart';
import 'package:banay/page/share_target_picker_page.dart';
import 'package:banay/services/app_logger.dart';
import 'package:banay/services/push_notification_service.dart';
import 'package:banay/services/session_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Lets Banay receive photos/videos/files shared from other apps (Android
/// share sheet / iOS share extension) and routes the user to a "choose a
/// conversation" screen. Mirrors PushNotificationService's
/// pending-navigation pattern: shared content that arrives before the
/// navigator/session is ready is held until [processPendingShareNavigation]
/// is called again from a point where it is.
class ShareIntentService {
  ShareIntentService._();

  static final ShareIntentService instance = ShareIntentService._();

  final SessionStorage _sessionStorage = SessionStorage();

  StreamSubscription<List<SharedMediaFile>>? _mediaStreamSubscription;
  List<SharedMediaFile>? _pendingSharedFiles;
  bool _isInitialized = false;
  bool _isNavigating = false;

  static bool get isSupportedPlatform {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> initialize() async {
    if (_isInitialized || !isSupportedPlatform) {
      return;
    }
    _isInitialized = true;

    _mediaStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(
          (files) {
            if (files.isEmpty) {
              return;
            }
            _pendingSharedFiles = files;
            unawaited(processPendingShareNavigation());
          },
          onError: (Object error) {
            AppLogger.warning('ShareIntentService', 'getMediaStream error', error);
          },
        );

    try {
      final initialFiles = await ReceiveSharingIntent.instance.getInitialMedia();
      if (initialFiles.isNotEmpty) {
        _pendingSharedFiles = initialFiles;
      }
    } catch (error) {
      AppLogger.warning('ShareIntentService', 'getInitialMedia error', error);
    }
  }

  Future<void> processPendingShareNavigation() async {
    if (_isNavigating) {
      return;
    }

    final pendingFiles = _pendingSharedFiles;
    if (pendingFiles == null || pendingFiles.isEmpty) {
      return;
    }

    final accessToken = await _sessionStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      return;
    }

    final navigator =
        BANAYNavigationShell.shellKey.currentState != null
            ? PushNotificationService.navigatorKey.currentState
            : null;
    if (navigator == null) {
      return;
    }

    _isNavigating = true;
    _pendingSharedFiles = null;

    try {
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => ShareTargetPickerPage(sharedFiles: pendingFiles),
        ),
      );
    } finally {
      _isNavigating = false;
      unawaited(ReceiveSharingIntent.instance.reset());
    }
  }

  void dispose() {
    _mediaStreamSubscription?.cancel();
    _mediaStreamSubscription = null;
    _isInitialized = false;
  }
}
