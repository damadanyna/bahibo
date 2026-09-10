import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:livekit_client/livekit_client.dart';

/// Viewer-side layer choice for a live, TikTok-style: HD on Wi-Fi, SD on
/// mobile data, with no manual control.
///
/// The simulcast ladder published by the host is 720p / 360p (both 30 fps)
/// / 180p, so HIGH and MEDIUM map to the first two layers. The SFU still
/// steps down on its own when the viewer's link cannot keep up: this only
/// sets the ceiling the viewer asks for.
VideoQuality resolveLiveViewQuality({required bool isOnCellular}) =>
    isOnCellular ? VideoQuality.MEDIUM : VideoQuality.HIGH;

/// `true` when the device reaches the network over a metered mobile link
/// only. Wi-Fi, ethernet or any other transport in the list counts as
/// unmetered, so a phone with both Wi-Fi and mobile data on is not throttled.
bool isCellularOnly(List<ConnectivityResult> results) {
  if (results.isEmpty || results.contains(ConnectivityResult.none)) {
    return false;
  }
  final hasUnmetered = results.any(
    (result) =>
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet,
  );
  return !hasUnmetered && results.contains(ConnectivityResult.mobile);
}
