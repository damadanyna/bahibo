import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'app_logger.dart';

class ApiConfig {
  static const String _vpsBaseUrl = 'https://77.37.51.154/api/v1';
  static const int _devPort = 4000;
  static const String _apiPath = '/api/v1';

  // Optional build-time override: --dart-define=BANAY_API_BASE_URL=https://...
  static const String _configuredBaseUrl = String.fromEnvironment(
    'BANAY_API_BASE_URL',
  );

  // Explicit dev host override: --dart-define=BANAY_DEV_HOST=192.168.x.x
  static const String _configuredDevHost = String.fromEnvironment(
    'BANAY_DEV_HOST',
  );

  // IP du PC sur le réseau hotspot du téléphone.

  // Mise à jour quand le PC change de réseau.
  static const String _knownDevHost = '192.168.167.62';

  static String _resolvedDevUrl = 'http://$_knownDevHost:$_devPort$_apiPath';

  /// Must be called once in main() before runApp().
  static Future<void> initialize() async {
    if (kReleaseMode || _configuredBaseUrl.isNotEmpty) return;
    _resolvedDevUrl = await _detectDevUrl();
    AppLogger.info('ApiConfig', 'Dev API → $_resolvedDevUrl');
  }

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;
    if (kReleaseMode) return _vpsBaseUrl;
    return _resolvedDevUrl;
  }

  static String get socketUrl {
    final uri = Uri.parse(baseUrl);
    return uri.replace(path: '', query: null, fragment: '').toString();
  }

  static Future<String> _detectDevUrl() async {
    // 1. dart-define explicite → priorité absolue.
    if (_configuredDevHost.isNotEmpty) {
      return 'http://$_configuredDevHost:$_devPort$_apiPath';
    }

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      // 2. Émulateurs Android (l'hôte est toujours une IP connue).
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final parts = addr.address.split('.');
          if (parts.length != 4) continue;
          // Android emulator: device 10.0.2.15 → host 10.0.2.2
          if (parts[0] == '10' && parts[1] == '0' && parts[2] == '2') {
            return 'http://10.0.2.2:$_devPort$_apiPath';
          }
          // Genymotion: device 10.0.3.15 → host 10.0.3.2
          if (parts[0] == '10' && parts[1] == '0' && parts[2] == '3') {
            return 'http://10.0.3.2:$_devPort$_apiPath';
          }
        }
      }

      // 3. Device physique : tester le fallback connu en premier (rapide).
      //    Utile si le PC est sur un subnet différent du téléphone (hotspot).
      if (await _canReach(_knownDevHost)) {
        AppLogger.debug('ApiConfig', 'Fallback host $_knownDevHost reachable.');
        return 'http://$_knownDevHost:$_devPort$_apiPath';
      }

      // 4. Scan de tous les subnets visibles par le téléphone.
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final parts = addr.address.split('.');
          if (parts.length != 4) continue;
          if (parts[0] == '127' || parts[0] == '169') continue;

          final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
          AppLogger.debug(
            'ApiConfig',
            'Scanning $subnet.* for port $_devPort...',
          );
          final host = await _scanSubnet(subnet);
          if (host != null) return 'http://$host:$_devPort$_apiPath';
        }
      }
    } catch (e) {
      AppLogger.warning('ApiConfig', 'Network detection failed', e);
    }

    AppLogger.warning(
      'ApiConfig',
      'Auto-detect failed. Using last-known host: $_knownDevHost',
    );
    return 'http://$_knownDevHost:$_devPort$_apiPath';
  }

  /// Tente une connexion TCP rapide sur [host]:[_devPort].
  static Future<bool> _canReach(String host) async {
    try {
      final socket = await Socket.connect(
        host,
        _devPort,
        timeout: const Duration(milliseconds: 600),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Scanne les 253 hôtes du subnet en parallèle, retourne le premier
  /// qui accepte une connexion sur [_devPort].
  static Future<String?> _scanSubnet(String subnet) async {
    const timeout = Duration(milliseconds: 300);
    final futures = List.generate(253, (i) async {
      final host = '$subnet.${i + 1}';
      try {
        final socket = await Socket.connect(host, _devPort, timeout: timeout);
        socket.destroy();
        return host;
      } catch (_) {
        return null;
      }
    });
    final results = await Future.wait(futures);
    for (final host in results) {
      if (host != null) return host;
    }
    return null;
  }
}
