import 'dart:async';

import 'package:banay/services/api_config.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:banay/services/session_storage.dart';
import 'package:flutter/widgets.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class ChatRealtimeService {
  ChatRealtimeService._();

  static final ChatRealtimeService instance = ChatRealtimeService._();

  final SessionStorage _sessionStorage = SessionStorage();
  final StreamController<Map<String, dynamic>> _eventsController =
      StreamController<Map<String, dynamic>>.broadcast();
  final Connectivity _connectivity = Connectivity();

  io.Socket? _socket;
  String? _currentAccessToken;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _hasInternetConnection = true;

  Stream<Map<String, dynamic>> get events => _eventsController.stream;

  void handleAppLifecycleStateChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(ensureConnected());
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _disposeSocket();
        break;
    }
  }

  Future<void> ensureConnected() async {
    _ensureConnectivityMonitoring();

    if (!await _syncConnectivityState()) {
      disconnect();
      return;
    }

    final accessToken = await _sessionStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      disconnect();
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
      ..off('conversations:typing')
      ..off('products:updated')
      ..off('profiles:updated')
      ..off('notifications:updated')
      ..off('presence:updated')
      ..off('live:updated');

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
      })
      ..on('products:updated', (payload) {
        if (payload is Map) {
          _eventsController.add(Map<String, dynamic>.from(payload));
        }
      })
      ..on('profiles:updated', (payload) {
        if (payload is Map) {
          _eventsController.add(Map<String, dynamic>.from(payload));
        }
      })
      ..on('notifications:updated', (payload) {
        if (payload is Map) {
          _eventsController.add(Map<String, dynamic>.from(payload));
        }
      })
      ..on('presence:updated', (payload) {
        if (payload is Map) {
          _eventsController.add(Map<String, dynamic>.from(payload));
        }
      })
      ..on('live:updated', (payload) {
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

  void _ensureConnectivityMonitoring() {
    _connectivitySubscription ??= _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChanged,
    );
  }

  Future<bool> _syncConnectivityState() async {
    final results = await _connectivity.checkConnectivity();
    _handleConnectivityChanged(results);
    return _hasInternetConnection;
  }

  void _handleConnectivityChanged(List<ConnectivityResult> results) {
    final hasConnection = results.any(
      (result) => result != ConnectivityResult.none,
    );

    if (_hasInternetConnection == hasConnection) {
      return;
    }

    _hasInternetConnection = hasConnection;

    if (!hasConnection) {
      disconnect();
      return;
    }

    unawaited(ensureConnected());
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
    final socket = _socket;
    if (socket != null) {
      socket.disconnect();
      socket.dispose();
    }
    _socket = null;
  }
}

