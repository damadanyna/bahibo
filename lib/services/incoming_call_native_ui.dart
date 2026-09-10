import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

/// The phone's own incoming-call surface: a full-screen, ringing call UI on
/// Android (ConnectionService-style, over the lock screen) and CallKit on
/// iOS, through `flutter_callkit_incoming` (MIT, free).
///
/// Also usable from the FCM background isolate, which is how a killed app
/// still rings: the OS shows this UI, and accepting launches the app.
class IncomingCallNativeUi {
  IncomingCallNativeUi._();

  static const Duration ringWindow = Duration(seconds: 45);
  static const String _brandBackground = '#0B1220';
  static const String _acceptGreen = '#2FBF71';

  static Future<void> show({
    required String callId,
    required String conversationId,
    required String callerName,
    String callerAvatarUrl = '',
    String callerUserId = '',
  }) async {
    if (callId.isEmpty) {
      return;
    }
    final name = callerName.trim().isNotEmpty ? callerName.trim() : 'Banay';
    final avatar = callerAvatarUrl.trim();

    final params = CallKitParams(
      id: callId,
      nameCaller: name,
      appName: 'Banay',
      avatar: avatar.isNotEmpty ? avatar : null,
      handle: 'Appel vocal Banay',
      // 0 = audio call.
      type: 0,
      duration: ringWindow.inMilliseconds,
      // The server sends its own "Appel manqué" push (with the caller's
      // name, opening the conversation): no second tile from the plugin.
      missedCallNotification: const NotificationParams(
        showNotification: false,
        isShowCallback: false,
      ),
      // Everything the app needs to pick the call up after a cold start.
      extra: <String, dynamic>{
        'callId': callId,
        'conversationId': conversationId,
        'callerName': name,
        'callerAvatarUrl': avatar,
        'callerUserId': callerUserId,
      },
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: _brandBackground,
        actionColor: _acceptGreen,
        textColor: '#FFFFFF',
        incomingCallNotificationChannelName: 'Appels entrants',
        missedCallNotificationChannelName: 'Appels manqués',
        isShowFullLockedScreen: true,
        isImportant: true,
        isShowCallID: false,
        textAccept: 'Accepter',
        textDecline: 'Refuser',
      ),
      ios: const IOSParams(
        iconName: 'AppIcon',
        handleType: 'generic',
        supportsVideo: false,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
        supportsDTMF: false,
        supportsHolding: false,
        supportsGrouping: false,
        supportsUngrouping: false,
        audioSessionMode: 'voiceChat',
        audioSessionActive: true,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    try {
      await FlutterCallkitIncoming.showCallkitIncoming(params);
    } catch (error) {
      debugPrint('Native incoming call UI failed: $error');
    }
  }

  /// Takes the ringing UI down (caller gave up, answered elsewhere, ended).
  static Future<void> dismiss(String callId) async {
    if (callId.isEmpty) {
      return;
    }
    try {
      await FlutterCallkitIncoming.endCall(callId);
    } catch (error) {
      debugPrint('Native call dismiss failed: $error');
    }
  }

  static Future<void> dismissAll() async {
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (error) {
      debugPrint('Native call dismissAll failed: $error');
    }
  }

  /// iOS: starts CallKit's timer once the audio is actually flowing.
  static Future<void> markConnected(String callId) async {
    if (callId.isEmpty) {
      return;
    }
    try {
      await FlutterCallkitIncoming.setCallConnected(callId);
    } catch (_) {
      // Android has no equivalent; harmless.
    }
  }

  /// Calls the OS still knows about (id, `isAccepted`, our `extra`). On
  /// Android only the last one is returned.
  static Future<List<CallKitParams>> activeCalls() async {
    try {
      return await FlutterCallkitIncoming.activeCalls();
    } catch (error) {
      debugPrint('Native activeCalls failed: $error');
      return const [];
    }
  }

  /// Our call id for a native event: stored in `extra`, falls back to the
  /// native id (which we set to the same value).
  static String callIdOf(CallKitParams params) {
    final extra = params.extra;
    final fromExtra = extra?['callId']?.toString().trim() ?? '';
    return fromExtra.isNotEmpty ? fromExtra : params.id;
  }
}
