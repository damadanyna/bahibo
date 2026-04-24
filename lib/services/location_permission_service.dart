import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationPermissionService {
  LocationPermissionService._();

  static Future<LocationPermission> checkPermissionStatus() async {
    if (kIsWeb) {
      return LocationPermission.unableToDetermine;
    }

    return Geolocator.checkPermission();
  }

  static bool shouldExplainOnLaunch(LocationPermission permission) {
    return permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever;
  }

  static Future<LocationPermission> requestPermissionAfterExplanation() async {
    if (kIsWeb) {
      return LocationPermission.unableToDetermine;
    }

    return Geolocator.requestPermission();
  }

  static Future<bool> openAppSettingsForPermission() async {
    if (kIsWeb) {
      return false;
    }

    return Geolocator.openAppSettings();
  }

  static Future<LocationPermission> ensurePermissionRequestedOnLaunch() async {
    if (kIsWeb) {
      return LocationPermission.unableToDetermine;
    }

    var permission = await checkPermissionStatus();
    if (shouldExplainOnLaunch(permission)) {
      permission = await requestPermissionAfterExplanation();
    }

    return permission;
  }
}
