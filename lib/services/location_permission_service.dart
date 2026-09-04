import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Combined state of the device location services and the app permission.
enum LocationAccessStatus {
  granted,
  servicesDisabled,
  permissionDenied,
  permissionDeniedForever,

  /// Web / desktop: location access is never enforced there.
  unsupported,
}

class LocationPermissionService {
  LocationPermissionService._();

  static bool get isEnforcedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<LocationPermission> checkPermissionStatus() async {
    if (kIsWeb) {
      return LocationPermission.unableToDetermine;
    }

    return Geolocator.checkPermission();
  }

  static Future<LocationPermission> requestPermissionAfterExplanation() async {
    if (kIsWeb) {
      return LocationPermission.unableToDetermine;
    }

    return Geolocator.requestPermission();
  }

  /// Checks the device services first, then the app permission.
  static Future<LocationAccessStatus> checkAccessStatus() async {
    if (!isEnforcedPlatform) {
      return LocationAccessStatus.unsupported;
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccessStatus.servicesDisabled;
    }

    return switch (await Geolocator.checkPermission()) {
      LocationPermission.denied => LocationAccessStatus.permissionDenied,
      LocationPermission.deniedForever =>
        LocationAccessStatus.permissionDeniedForever,
      // `unableToDetermine` never blocks: better to let the user in than to
      // loop on a state the OS itself cannot report.
      LocationPermission.always ||
      LocationPermission.whileInUse ||
      LocationPermission.unableToDetermine => LocationAccessStatus.granted,
    };
  }
}
