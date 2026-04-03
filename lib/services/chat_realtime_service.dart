import 'dart:async';

import 'package:bahibo/services/api_config.dart';
import 'package:bahibo/services/session_storage.dart';
import 'package:flutter/widgets.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class ChatRealtimeService {
  ChatRealtimeService._();

  static final ChatRealtimeService instance = ChatRealtimeService._();

  final SessionStorage _sessionStorage = SessionStorage();
  final StreamController<Map<String, dynamic>> _eventsController =
      StreamController<Map<String, dynamic>>.broadcast();

  io.Socket? _socket;
  String? _currentAccessToken;

  Stream<Map<String, dynamic>> get events => _eventsController.stream;

  void handleAppLifecycleStateChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(ensureConnected());
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _disposeSocket();
        break;
    }
  }

  Future<void> ensureConnected() async {
    final accessToken = await _sessionStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      return;
    }

    if (_socket != null &&
        _socket!.connected &&
        _currentAccessToken == accessToken) {
      return;
    }

    if (_currentAccessToken != accessToken) {
      _disposeSocket();
      _currentAccessToken = accessToken;
    }

    _socket ??= io.io(
      ApiConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setAuth({'token': accessToken})
          .setExtraHeaders({'Authorization': 'Bearer $accessToken'})
          .build(),
    );

    _socket!
      ..off('connect')
      ..off('disconnect')
      ..off('connect_error')
      ..off('conversations:updated')
      ..off('conversations:typing');

    _socket!
      ..on('connect', (_) {
        debugPrint('Chat realtime connected');
      })
      ..on('disconnect', (_) {
        debugPrint('Chat realtime disconnected');
      })
      ..on('connect_error', (error) {
        debugPrint('Chat realtime connection error: $error');
      })
      ..on('conversations:updated', (payload) {
        if (payload is Map) {
          _eventsController.add(Map<String, dynamic>.from(payload));
        }
      })
      ..on('conversations:typing', (payload) {
        if (payload is Map) {
          _eventsController.add(Map<String, dynamic>.from(payload));
        }
      });

    if (!_socket!.connected) {
      _socket!.connect();
    }
  }

  void disconnect() {
    _disposeSocket();
    _currentAccessToken = null;
  }

  void emitTyping({
    required String conversationId,
    required String recipientUserId,
    required bool isTyping,
  }) {
    final socket = _socket;
    if (socket == null || !socket.connected) {
      return;
    }

    socket.emit('conversations:typing', {
      'conversationId': conversationId,
      'recipientUserId': recipientUserId,
      'isTyping': isTyping,
    });
  }

  void _disposeSocket() {
    _socket?.dispose();
    _socket = null;
  }
}
