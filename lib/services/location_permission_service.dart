import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationPermissionService {
  LocationPermissionService._();

  static bool _hasRequestedOnLaunch = false;

  static Future<LocationPermission> checkPermissionStatus() async {
    if (kIsWeb) {
      return LocationPermission.unableToDetermine;
    }

    return Geolocator.checkPermission();
  }

  static bool shouldExplainOnLaunch(LocationPermission permission) {
    return permission == LocationPermission.denied && !_hasRequestedOnLaunch;
  }

  static Future<LocationPermission> requestPermissionAfterExplanation() async {
    if (kIsWeb) {
      return LocationPermission.unableToDetermine;
    }

    _hasRequestedOnLaunch = true;
    return Geolocator.requestPermission();
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
