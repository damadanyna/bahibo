import 'dart:async';
import 'dart:convert';

import 'package:banay/component/main_navigation_shell.dart';
import 'package:banay/page/chat_page.dart';
import 'package:banay/page/notifications_page.dart';
import 'package:banay/page/productDetail.dart';
import 'package:banay/services/app_api_client.dart';
import 'package:banay/services/app_event_log_service.dart';
import 'package:banay/services/conversations_api_service.dart';
import 'package:banay/services/session_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!PushNotificationService.isSupportedPlatform) {
    return;
  }

  await Firebase.initializeApp();

  final type = message.data['type'];
  unawaited(
    AppEventLogService.instance.record(
      name: 'push_background_message_received',
      source: 'push',
      parameters: {'type': type ?? ''},
    ),
  );

  if (type == 'chat_message' || type == 'chat_message_delivery_ping') {
    await PushNotificationService.acknowledgeChatMessageDeliveryInBackground();
  }
}

@pragma('vm:entry-point')
void onDidReceiveBackgroundNotificationResponse(NotificationResponse response) {
  final payload = response.payload;
  if (payload == null || payload.isEmpty) {
    return;
  }

  PushNotificationService.queueNotificationPayloadString(payload);
}

class PushNotificationService {
  static const String _androidNotificationChannelId = 'banay_messages_v2';
  static const RawResourceAndroidNotificationSound _androidNotificationSound =
      RawResourceAndroidNotificationSound('notification');
  static const AndroidNotificationChannel _messagesChannel =
      AndroidNotificationChannel(
        _androidNotificationChannelId,
        'Messages Banay',
        description: 'Notifications des nouveaux messages Banay.',
        importance: Importance.high,
        sound: _androidNotificationSound,
        playSound: true,
      );

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final RouteObserver<ModalRoute<void>> routeObserver =
      RouteObserver<ModalRoute<void>>();
  static const MethodChannel _nativeNotificationChannel = MethodChannel(
    'banay/notifications',
  );
  static final AppApiClient _apiClient = AppApiClient();
  static final ConversationsApiService _conversationsApiService =
      ConversationsApiService();
  static final SessionStorage _sessionStorage = SessionStorage();

  static bool _initialized = false;
  static bool _isNavigatingFromNotification = false;
  static Map<String, String>? _pendingNotificationData;
  static String? _visibleConversationId;

  static bool get isSupportedPlatform {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static Future<void> initialize() async {
    if (_initialized || !isSupportedPlatform) {
      return;
    }

    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _initializeLocalNotifications();
    await _initializeNativeNotificationBridge();
    await _hydratePendingNavigationFromLocalLaunch();

    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    final token = await messaging.getToken();
    if (kDebugMode) {
      debugPrint('FCM permission: ${settings.authorizationStatus.name}');
      debugPrint('FCM token: $token');
    }

    if (token != null && token.isNotEmpty) {
      await _syncDeviceToken(token);
    }

    messaging.onTokenRefresh.listen((nextToken) {
      unawaited(_syncDeviceToken(nextToken));
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedAppMessage);

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleOpenedAppMessage(initialMessage);
    }

    _initialized = true;
  }

  static Future<void> _initializeLocalNotifications() async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _handleLocalNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          onDidReceiveBackgroundNotificationResponse,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.deleteNotificationChannel('BANAY_messages');
    await androidPlugin?.createNotificationChannel(_messagesChannel);
  }

  static Future<void> _initializeNativeNotificationBridge() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    _nativeNotificationChannel.setMethodCallHandler((call) async {
      if (call.method != 'notificationOpened') {
        return;
      }

      final arguments = call.arguments;
      if (arguments is Map) {
        _queueNotificationData(arguments.cast<String, dynamic>());
        await processPendingNotificationNavigation();
      }
    });

    try {
      final initialPayload = await _nativeNotificationChannel
          .invokeMapMethod<String, dynamic>('getInitialNotificationPayload');
      if (initialPayload != null && initialPayload.isNotEmpty) {
        _queueNotificationData(initialPayload);
      }
    } catch (error) {
      debugPrint('Unable to read native notification payload: $error');
    }
  }

  static Future<void> _hydratePendingNavigationFromLocalLaunch() async {
    final launchDetails = await _localNotifications
        .getNotificationAppLaunchDetails();
    final payload = launchDetails?.notificationResponse?.payload;
    if (payload == null || payload.isEmpty) {
      return;
    }

    queueNotificationPayloadString(payload);
  }

  /// Best-effort: lets the sender see "distribue" as soon as this device is
  /// reachable, without requiring the recipient to open the app. Runs in
  /// the isolate FCM spins up for background/terminated-app notifications
  /// (see firebaseMessagingBackgroundHandler above), so failures here must
  /// never throw back into the plugin.
  static Future<void> acknowledgeChatMessageDeliveryInBackground() async {
    try {
      await _conversationsApiService.pingDelivery();
      unawaited(
        AppEventLogService.instance.record(
          name: 'delivery_ping_sent',
          source: 'push',
          status: 'success',
        ),
      );
    } catch (error) {
      // A live socket connection or the next foreground open will still
      // mark the message delivered eventually.
      unawaited(
        AppEventLogService.instance.record(
          name: 'delivery_ping_sent',
          source: 'push',
          status: 'failure',
          parameters: {'reason': error.toString()},
        ),
      );
    }
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final type = message.data['type'];
    if (type == 'chat_message' || type == 'chat_message_delivery_ping') {
      unawaited(acknowledgeChatMessageDeliveryInBackground());
    }

    // The delivery ping carries no title/body: it must never fall through
    // to the display logic below, or it shows up as a bogus "BANAY - Vous
    // avez recu un nouveau message" notification with nothing behind it.
    if (type == 'chat_message_delivery_ping') {
      return;
    }

    if (!_shouldShowForegroundNotification(message)) {
      return;
    }

    final notification = message.notification;
    final title =
        notification?.title ?? message.data['title']?.toString() ?? 'BANAY';
    final body =
        notification?.body ??
        message.data['body']?.toString() ??
        'Vous avez recu un nouveau message.';

    await _localNotifications.show(
      message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _messagesChannel.id,
          _messagesChannel.name,
          channelDescription: _messagesChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          sound: _androidNotificationSound,
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data.isEmpty ? null : jsonEncode(message.data),
    );
  }

  static void setVisibleConversation(String? conversationId) {
    final normalized = conversationId?.trim();
    if (normalized == null || normalized.isEmpty) {
      _visibleConversationId = null;
      return;
    }

    _visibleConversationId = normalized;
  }

  static String? get visibleConversationId => _visibleConversationId;

  static bool _shouldShowForegroundNotification(RemoteMessage message) {
    final notificationType =
        message.data['type']?.toString().trim().toLowerCase() ?? '';
    if (notificationType == 'user_feedback') {
      return false;
    }

    // The recipient is already looking at this exact conversation (ChatPage
    // marks it visible via setVisibleConversation): the message shows up
    // live through the socket, a popup notification would be redundant.
    final conversationId = message.data['conversationId']?.trim();
    if (notificationType == 'chat_message' &&
        conversationId != null &&
        conversationId.isNotEmpty &&
        conversationId == _visibleConversationId) {
      return false;
    }

    return true;
  }

  static void _handleOpenedAppMessage(RemoteMessage message) {
    _queueNotificationData(message.data);
    unawaited(processPendingNotificationNavigation());
  }

  static void _handleLocalNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) {
      return;
    }

    queueNotificationPayloadString(payload);
    unawaited(processPendingNotificationNavigation());
  }

  static void queueNotificationPayloadString(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        _queueNotificationData(decoded);
      }
    } catch (error) {
      debugPrint('Unable to decode notification payload: $error');
    }
  }

  static Future<void> syncDeviceTokenIfAuthenticated() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      return;
    }

    await _syncDeviceToken(token);
  }

  static Future<void> processPendingNotificationNavigation() async {
    if (_isNavigatingFromNotification) {
      return;
    }

    final pendingData = _pendingNotificationData;
    if (pendingData == null) {
      return;
    }

    final accessToken = await _sessionStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      return;
    }

    final notificationType = pendingData['type']?.trim().toLowerCase() ?? '';
    final conversationId = pendingData['conversationId']?.trim();
    final isConversationNotification =
        conversationId != null &&
        conversationId.isNotEmpty &&
        (notificationType.isEmpty || notificationType == 'chat_message');

    if (isConversationNotification) {
      unawaited(_markConversationOpenedAsRead(conversationId));
    }

    final shellState = BANAYNavigationShell.shellKey.currentState;
    final navigator = navigatorKey.currentState;
    if (shellState == null && navigator == null) {
      return;
    }

    if (!isConversationNotification) {
      if (shellState != null) {
        _isNavigatingFromNotification = true;
        _pendingNotificationData = null;

        try {
          await shellState.openNotificationsFromNotification();
        } finally {
          _isNavigatingFromNotification = false;
        }
        return;
      }

      if (navigator != null) {
        _isNavigatingFromNotification = true;
        _pendingNotificationData = null;

        try {
          await navigator.push(
            MaterialPageRoute(
              builder: (_) => const NotificationsPage(notifications: []),
            ),
          );
        } finally {
          _isNavigatingFromNotification = false;
        }
      }
      return;
    }

    if (shellState == null) {
      if (navigator != null) {
        _isNavigatingFromNotification = true;
        _pendingNotificationData = null;

        final visibleConversationId = _visibleConversationId;
        if (visibleConversationId == conversationId) {
          _isNavigatingFromNotification = false;
          return;
        }

        final chatRoute = MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: conversationId,
            productPageBuilder: (product, {openedFromChat = false}) =>
                ProductDetailPage(
                  product: product,
                  openedFromChat: openedFromChat,
                ),
            sellerName:
                pendingData['participantName']?.trim().isNotEmpty == true
                ? pendingData['participantName']!.trim()
                : 'Conversation',
            sellerRole:
                pendingData['participantRole']?.trim().isNotEmpty == true
                ? pendingData['participantRole']!.trim()
                : 'Utilisateur',
            avatarUrl: pendingData['participantAvatarUrl']?.trim() ?? '',
          ),
        );

        try {
          if (visibleConversationId != null &&
              visibleConversationId.isNotEmpty) {
            await navigator.pushReplacement(chatRoute);
          } else {
            await navigator.push(chatRoute);
          }
        } finally {
          _isNavigatingFromNotification = false;
        }
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(processPendingNotificationNavigation());
      });
      return;
    }

    _isNavigatingFromNotification = true;
    _pendingNotificationData = null;

    try {
      await shellState.openConversationFromNotification(
        conversationId: conversationId,
        sellerName: pendingData['participantName']?.trim().isNotEmpty == true
            ? pendingData['participantName']!.trim()
            : 'Conversation',
        sellerRole: pendingData['participantRole']?.trim().isNotEmpty == true
            ? pendingData['participantRole']!.trim()
            : 'Utilisateur',
        avatarUrl: pendingData['participantAvatarUrl']?.trim() ?? '',
      );
    } finally {
      _isNavigatingFromNotification = false;
    }
  }

  static Future<void> _markConversationOpenedAsRead(
    String conversationId,
  ) async {
    try {
      await _conversationsApiService.markConversationRead(
        conversationId: conversationId,
      );
    } on AppApiException {
      // ChatPage keeps its own read sync as a fallback after navigation.
    }
  }

  static Future<void> _syncDeviceToken(String token) async {
    final accessToken = await _sessionStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      return;
    }

    try {
      await _apiClient.post(
        '/auth/device-token',
        authenticated: true,
        body: {'token': token, 'platform': _platformLabel},
      );
    } catch (error) {
      debugPrint('Unable to sync FCM token: $error');
    }
  }

  static String get _platformLabel {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'web';
    }
  }

  static void _queueNotificationData(Map<String, dynamic> data) {
    _pendingNotificationData = data.map(
      (key, value) => MapEntry(key, value?.toString() ?? ''),
    );
  }
}
