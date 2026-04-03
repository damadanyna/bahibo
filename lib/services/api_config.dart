import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'BAHIBO_API_BASE_URL',
  );
  static const String _localNetworkBaseUrl = 'http://10.44.12.62:4000/api/v1';

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }

    if (kIsWeb) {
      return _localNetworkBaseUrl;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _localNetworkBaseUrl,
      _ => _localNetworkBaseUrl,
    };
  }

  static String get socketUrl {
    final uri = Uri.parse(baseUrl);
    return uri.replace(path: '', query: null, fragment: '').toString();
  }
}
