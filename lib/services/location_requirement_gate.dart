import 'dart:async';

import 'package:banay/localization/banay_localizations.dart';
import 'package:banay/services/location_permission_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Keeps location mandatory while the app is in the foreground.
///
/// [enforce] runs one evaluation pass: it asks the OS for the permission when
/// it is simply denied, and otherwise shows (or updates) a single
/// non-dismissible dialog until both the device services and the app
/// permission are enabled. Call it on launch and on every resume; the dialog
/// removes itself as soon as a pass finds the location usable.
class LocationRequirementGate {
  LocationRequirementGate({required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  final ValueNotifier<LocationAccessStatus> _status = ValueNotifier(
    LocationAccessStatus.granted,
  );
  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;
  DialogRoute<void>? _dialogRoute;
  bool _isEnforcing = false;
  bool _isRerunRequested = false;
  bool _isDisposed = false;

  Future<void> enforce() async {
    if (_isDisposed || !LocationPermissionService.isEnforcedPlatform) {
      return;
    }

    // A pass can trigger a resume (system prompt, settings screen) which
    // calls enforce() again: coalesce it into one extra pass instead of
    // stacking prompts.
    if (_isEnforcing) {
      _isRerunRequested = true;
      return;
    }

    _isEnforcing = true;
    try {
      do {
        _isRerunRequested = false;
        await _runPass();
      } while (_isRerunRequested && !_isDisposed);
    } finally {
      _isEnforcing = false;
    }
  }

  void dispose() {
    _isDisposed = true;
    unawaited(_serviceStatusSubscription?.cancel());
    _serviceStatusSubscription = null;
    _dismissDialog();
    _status.dispose();
  }

  Future<void> _runPass() async {
    _listenToServiceStatus();

    var status = await _safeCheckAccessStatus();
    if (status == LocationAccessStatus.permissionDenied) {
      // Ask the OS directly; the dialog below is only the fallback when the
      // system prompt is refused or cannot be shown.
      try {
        await Geolocator.requestPermission();
      } catch (_) {
        // Another request is already running (e.g. from a page); the next
        // pass will read the final result.
      }
      status = await _safeCheckAccessStatus();
    }

    if (_isDisposed) {
      return;
    }

    if (status == LocationAccessStatus.granted ||
        status == LocationAccessStatus.unsupported) {
      _dismissDialog();
      return;
    }

    _status.value = status;
    _showDialogIfNeeded();
  }

  Future<LocationAccessStatus> _safeCheckAccessStatus() async {
    try {
      return await LocationPermissionService.checkAccessStatus();
    } catch (_) {
      // Never block the app on a plugin failure.
      return LocationAccessStatus.granted;
    }
  }

  /// Reacts instantly when the user toggles the GPS from the quick settings.
  void _listenToServiceStatus() {
    if (_serviceStatusSubscription != null) {
      return;
    }

    try {
      _serviceStatusSubscription = Geolocator.getServiceStatusStream().listen(
        (_) => unawaited(enforce()),
        onError: (_) {},
      );
    } catch (_) {
      // Stream not supported on this platform; resume events still cover it.
    }
  }

  void _showDialogIfNeeded() {
    if (_dialogRoute != null) {
      return;
    }

    final navigator = navigatorKey.currentState;
    final context = navigatorKey.currentContext;
    if (navigator == null || context == null) {
      // Navigator not mounted yet; the next pass (resume) retries.
      return;
    }

    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _LocationRequirementDialog(status: _status, onAction: _handleAction),
    );
    _dialogRoute = route;
    unawaited(
      navigator.push(route).whenComplete(() {
        if (identical(_dialogRoute, route)) {
          _dialogRoute = null;
        }
      }),
    );
  }

  void _dismissDialog() {
    final route = _dialogRoute;
    if (route == null) {
      return;
    }

    _dialogRoute = null;
    if (route.isActive) {
      // Remove that exact route: a page pushed on top (push notification)
      // must not be popped by mistake.
      navigatorKey.currentState?.removeRoute(route);
    }
  }

  Future<void> _handleAction() async {
    try {
      switch (_status.value) {
        case LocationAccessStatus.servicesDisabled:
          await Geolocator.openLocationSettings();
        case LocationAccessStatus.permissionDeniedForever:
          await Geolocator.openAppSettings();
        case LocationAccessStatus.permissionDenied:
        case LocationAccessStatus.granted:
        case LocationAccessStatus.unsupported:
          break;
      }
    } catch (_) {}

    // Android returns before the user comes back; the resume triggers the
    // real re-check. iOS / a refused system prompt rely on this call.
    await enforce();
  }
}

class _LocationRequirementDialog extends StatelessWidget {
  const _LocationRequirementDialog({
    required this.status,
    required this.onAction,
  });

  final ValueListenable<LocationAccessStatus> status;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      child: ValueListenableBuilder<LocationAccessStatus>(
        valueListenable: status,
        builder: (context, value, _) {
          final (icon, titleKey, messageKey, actionKey) = switch (value) {
            LocationAccessStatus.servicesDisabled => (
              Icons.location_off_outlined,
              BanayLocalizationKeys.accountLocationServicesDisabledTitle,
              BanayLocalizationKeys.accountLocationServicesDisabledMessage,
              BanayLocalizationKeys.accountOpenLocationSettings,
            ),
            LocationAccessStatus.permissionDeniedForever => (
              Icons.app_settings_alt_outlined,
              BanayLocalizationKeys.accountLocationPermissionRequiredTitle,
              BanayLocalizationKeys
                  .accountLocationPermissionDeniedForeverMessage,
              BanayLocalizationKeys.accountOpenAppSettings,
            ),
            LocationAccessStatus.permissionDenied ||
            LocationAccessStatus.granted ||
            LocationAccessStatus.unsupported => (
              Icons.location_searching_outlined,
              BanayLocalizationKeys.accountLocationPermissionDeniedTitle,
              BanayLocalizationKeys.accountLocationPermissionDeniedMessage,
              BanayLocalizationKeys.accountAllowNow,
            ),
          };

          return AlertDialog(
            icon: Icon(icon, color: colorScheme.error, size: 32),
            title: Text(context.tr(titleKey), textAlign: TextAlign.center),
            content: Text(context.tr(messageKey), textAlign: TextAlign.center),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              FilledButton(
                onPressed: () => unawaited(onAction()),
                child: Text(context.tr(actionKey)),
              ),
            ],
          );
        },
      ),
    );
  }
}
