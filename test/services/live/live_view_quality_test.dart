import 'package:banay/services/live/live_view_quality.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

void main() {
  group('resolveLiveViewQuality', () {
    test('HD on Wi-Fi, SD on mobile data', () {
      expect(resolveLiveViewQuality(isOnCellular: false), VideoQuality.HIGH);
      expect(resolveLiveViewQuality(isOnCellular: true), VideoQuality.MEDIUM);
    });
  });

  group('isCellularOnly', () {
    test('mobile alone is metered', () {
      expect(isCellularOnly([ConnectivityResult.mobile]), isTrue);
    });

    test('any Wi-Fi or ethernet link wins over mobile', () {
      expect(
        isCellularOnly([ConnectivityResult.mobile, ConnectivityResult.wifi]),
        isFalse,
      );
      expect(isCellularOnly([ConnectivityResult.ethernet]), isFalse);
    });

    test('offline or unknown transports are not throttled', () {
      expect(isCellularOnly([]), isFalse);
      expect(isCellularOnly([ConnectivityResult.none]), isFalse);
      expect(isCellularOnly([ConnectivityResult.vpn]), isFalse);
    });
  });
}
