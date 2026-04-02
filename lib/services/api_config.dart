import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'BAHIBO_API_BASE_URL',
  );

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }

    if (kIsWeb) {
      return 'http://localhost:4000/api/v1';
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'http://10.0.2.2:4000/api/v1',
      _ => 'http://localhost:4000/api/v1',
    };
  }
}
