import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'BAHIBO_API_BASE_URL',
  );
  static const String _configuredScheme = String.fromEnvironment(
    'BAHIBO_API_SCHEME',
    defaultValue: 'http',
  );
  static const String _configuredHost = String.fromEnvironment(
    'BAHIBO_API_HOST',
  );
  static const String _configuredPort = String.fromEnvironment(
    'BAHIBO_API_PORT',
    defaultValue: '4000',
  );
  static const String _configuredPath = String.fromEnvironment(
    'BAHIBO_API_PATH',
    defaultValue: '/api/v1',
  );

  static String get _defaultHost {
    if (kIsWeb) {
      return 'localhost';
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => '10.0.2.2',
      _ => 'localhost',
    };
  }

  static String get _normalizedPath {
    final trimmed = _configuredPath.trim();
    if (trimmed.isEmpty) {
      return '/api/v1';
    }

    return trimmed.startsWith('/') ? trimmed : '/$trimmed';
  }

  static String get _derivedBaseUrl {
    final host = _configuredHost.trim().isEmpty
        ? _defaultHost
        : _configuredHost.trim();
    final port = _configuredPort.trim();
    final path = _normalizedPath;
    return '$_configuredScheme://$host:$port$path';
  }

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }

    return _derivedBaseUrl;
  }

  static String get socketUrl {
    final uri = Uri.parse(baseUrl);
    return uri.replace(path: '', query: null, fragment: '').toString();
  }
}
