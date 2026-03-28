import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class AppOfflineBanner extends StatelessWidget {
  final String message;
  final double bottomOffset;

  const AppOfflineBanner({
    super.key,
    this.message = 'Vous n\'etes pas connecté a internet',
    this.bottomOffset = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomOffset,
      child: IgnorePointer(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFD32F2F),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Vous n\'etes pas connecté a internet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

mixin AppPageRefreshMixin<T extends StatefulWidget> on State<T> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOffline = false;
  bool _isRefreshing = false;

  bool get isOffline => _isOffline;

  @protected
  Future<void> onPageReload();

  @protected
  void initializePageRefresh() {
    _syncConnectivityState();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _handleConnectivityChange,
    );
  }

  @protected
  void disposePageRefresh() {
    _connectivitySubscription?.cancel();
  }

  @protected
  Future<void> refreshPageWithDialog() async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    final navigator = Navigator.of(context, rootNavigator: true);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Chargement en cours...',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );

    try {
      await onPageReload();
    } finally {
      if (navigator.canPop()) {
        navigator.pop();
      }
      _isRefreshing = false;
    }
  }

  Future<void> _syncConnectivityState() async {
    final results = await Connectivity().checkConnectivity();
    _handleConnectivityChange(results);
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final connected = results.any(
      (result) => result != ConnectivityResult.none,
    );
    final nextOffline = !connected;
    final wasOffline = _isOffline;

    if (_isOffline != nextOffline && mounted) {
      setState(() {
        _isOffline = nextOffline;
      });
    } else {
      _isOffline = nextOffline;
    }

    if (wasOffline && connected && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        refreshPageWithDialog();
      });
    }
  }
}
