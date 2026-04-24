import 'dart:async';
import 'dart:convert';

import 'package:bahibo/component/main_navigation_shell.dart';
import 'package:bahibo/page/chat_page.dart';
import 'package:bahibo/page/notifications_page.dart';
import 'package:bahibo/page/productDetail.dart';
import 'package:bahibo/services/app_api_client.dart';
import 'package:bahibo/services/session_storage.dart';
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
  static const String _androidNotificationChannelId = 'bahibo_messages_v2';
  static const RawResourceAndroidNotificationSound _androidNotificationSound =
      RawResourceAndroidNotificationSound('notification');
  static const AndroidNotificationChannel _messagesChannel =
      AndroidNotificationChannel(
        _androidNotificationChannelId,
        'Messages Bahibo',
        description: 'Notifications des nouveaux messages Bahibo.',
        importance: Importance.high,
        sound: _androidNotificationSound,
        playSound: true,
      );

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static const MethodChannel _nativeNotificationChannel = MethodChannel(
    'bahibo/notifications',
  );
  static final AppApiClient _apiClient = AppApiClient();
  static final SessionStorage _sessionStorage = SessionStorage();

  static bool _initialized = false;
  static bool _isNavigatingFromNotification = false;
  static Map<String, String>? _pendingNotificationData;

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
    debugPrint('FCM permission: ${settings.authorizationStatus.name}');
    debugPrint('FCM token: $token');

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
    await androidPlugin?.deleteNotificationChannel('bahibo_messages');
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

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title =
        notification?.title ?? message.data['title']?.toString() ?? 'Bahibo';
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

    final shellState = BahiboNavigationShell.shellKey.currentState;
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

        try {
          await navigator.push(
            MaterialPageRoute(
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
            ),
          );
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
