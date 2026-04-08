import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationPermissionService {
  LocationPermissionService._();

  static bool _hasRequestedOnLaunch = false;

  static Future<LocationPermission> ensurePermissionRequestedOnLaunch() async {
    if (kIsWeb) {
      return LocationPermission.unableToDetermine;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && !_hasRequestedOnLaunch) {
      _hasRequestedOnLaunch = true;
      permission = await Geolocator.requestPermission();
    }

    return permission;
  }
}
