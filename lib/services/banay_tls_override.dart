import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' show HttpClientAdapter;

const String _pinnedBanayProdHost = '77.37.51.154';
const String _pinnedBanayProdCertificateDerBase64 =
    'MIIDIDCCAgigAwIBAgIUeFbnd111/61T6O4dREBFIXD5dEQwDQYJKoZIhvcNAQELBQAwFzEVMBMGA1UEAwwMNzcuMzcuNTEuMTU0MB4XDTI2MDUxMzIwMDI0N1oXDTM2MDUxMDIwMDI0N1owFzEVMBMGA1UEAwwMNzcuMzcuNTEuMTU0MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAuSHxMV0ScbEggGk5oVnoIWy1L5dVrlZ2a5saJtEZgD4qSYTddfkIAKJyZAmXLECcWvnAS/7TyJb6OkeXFY21bH8cLJ/kVTzJenCrQ6vCguCTRMbMeC7diRmikNFRT4isZEnZ3I8Asiw6NtrBfV6ByKO+jg+FQ3dPIKaDMLhG0SY7rYhQBdR6JIjJRQ7g0tgeRDrIZ8QtwFswD+HaXPsF7WGxhT+zbvuCBpCwWuCphuAq5f46g7l38alXuR8XniIVmIlP1rk7kP00EDBG2Ln9Lf3bvkuhknRps00gK9Dxr1zvHsc8doAEg+q9nH2EspwXaqInekfc/LV32B2V3OCYMQIDAQABo2QwYjAdBgNVHQ4EFgQU9zTo+GS6tUzT+dPw+G5tfkh505QwHwYDVR0jBBgwFoAU9zTo+GS6tUzT+dPw+G5tfkh505QwDwYDVR0TAQH/BAUwAwEB/zAPBgNVHREECDAGhwRNJTOaMA0GCSqGSIb3DQEBCwUAA4IBAQAD4cmUx/t3Xw61Y4D+wHBlQrSA94+w5v99z77PsDr93coeApUBYxtE5kkRR2KK2y3dncsl4u5Wo6k9NeDSkgc9zyOuwFeH+HEK/vYPJ1gRyX7/hmRqdmmF++bOqMC8Kb8KpKMpB7wAhtowIl/oQ9vcz+PfQMP+PLWfbGtJOrgIb1jMZPQPO6uzJvTYgfYiPyrGEFzl7O18zjcoMURodT8IrRWvZ+ks6zuQRiikSC3oi91wRz4bFbaAJowEMuqCqtgEBbt5iYWFLTeV2+TeIqJ21ksAVk+PvYosOcs58ZKjCUJoIGcEaVNKNKgKYjGw2e3z1GUNbldxGu8rpCJkIPyo';

void configureBanayTlsOverride(String baseUrl) {
  final apiUri = Uri.tryParse(baseUrl);
  final host = apiUri?.host.trim();

  if (apiUri == null ||
      apiUri.scheme != 'https' ||
      host == null ||
      host.isEmpty) {
    return;
  }

  HttpOverrides.global = _BanayPinnedHttpOverrides(
    allowedHost: host,
    pinnedCertificateDer: host == _pinnedBanayProdHost
        ? base64Decode(_pinnedBanayProdCertificateDerBase64)
        : null,
    allowHostOnlyFallback: !kReleaseMode,
  );
}

HttpClientAdapter createBanayPinnedHttpClientAdapter(String baseUrl) {
  final apiUri = Uri.tryParse(baseUrl);
  final host = apiUri?.host.trim();

  return _BanayPinnedSocketHttpClientAdapter(
    allowedHost: host,
    pinnedCertificateDer: host == _pinnedBanayProdHost
        ? base64Decode(_pinnedBanayProdCertificateDerBase64)
        : null,
    allowHostOnlyFallback: !kReleaseMode,
  );
}

class _BanayPinnedHttpOverrides extends HttpOverrides {
  _BanayPinnedHttpOverrides({
    required this.allowedHost,
    required this.allowHostOnlyFallback,
    this.pinnedCertificateDer,
  });

  final String allowedHost;
  final List<int>? pinnedCertificateDer;
  final bool allowHostOnlyFallback;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (cert, host, port) {
      if (host != allowedHost) {
        return false;
      }

      final pinnedDer = pinnedCertificateDer;
      if (pinnedDer != null) {
        return _sameBytes(cert.der, pinnedDer);
      }

      return allowHostOnlyFallback;
    };
    return client;
  }

  bool _sameBytes(List<int> left, List<int> right) {
    if (left.length != right.length) {
      return false;
    }

    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }

    return true;
  }
}

class _BanayPinnedSocketHttpClientAdapter implements HttpClientAdapter {
  _BanayPinnedSocketHttpClientAdapter({
    required this.allowedHost,
    required this.allowHostOnlyFallback,
    this.pinnedCertificateDer,
  });

  final String? allowedHost;
  final List<int>? pinnedCertificateDer;
  final bool allowHostOnlyFallback;

  @override
  Future<WebSocket> connect(String uri, {Map<String, dynamic>? headers}) {
    final httpClient = HttpClient();
    final expectedHost = allowedHost;

    if (expectedHost != null && expectedHost.isNotEmpty) {
      httpClient.badCertificateCallback = (cert, host, port) {
        if (host != expectedHost) {
          return false;
        }

        final pinnedDer = pinnedCertificateDer;
        if (pinnedDer != null) {
          return _sameBytes(cert.der, pinnedDer);
        }

        return allowHostOnlyFallback;
      };
    }

    return WebSocket.connect(uri, headers: headers, customClient: httpClient);
  }

  bool _sameBytes(List<int> left, List<int> right) {
    if (left.length != right.length) {
      return false;
    }

    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }

    return true;
  }
}
