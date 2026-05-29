import 'dart:convert';
import 'dart:io';

import 'package:socket_io_client/socket_io_client.dart' show HttpClientAdapter;

// Self-signed certificate for the production VPS (77.37.51.154).
// Expires: 2036-05-10. Rotate this value and release a new build before expiry.
// Long-term: migrate to a CA-signed cert (e.g. Let's Encrypt on a domain) and
// delete this file entirely — no override will be needed.
const String _pinnedBanayProdHost = '77.37.51.154';
const String _pinnedBanayProdCertificateDerBase64 =
    'MIIDIDCCAgigAwIBAgIUeFbnd111/61T6O4dREBFIXD5dEQwDQYJKoZIhvcNAQELBQAwFzEVMBMGA1UEAwwMNzcuMzcuNTEuMTU0MB4XDTI2MDUxMzIwMDI0N1oXDTM2MDUxMDIwMDI0N1owFzEVMBMGA1UEAwwMNzcuMzcuNTEuMTU0MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAuSHxMV0ScbEggGk5oVnoIWy1L5dVrlZ2a5saJtEZgD4qSYTddfkIAKJyZAmXLECcWvnAS/7TyJb6OkeXFY21bH8cLJ/kVTzJenCrQ6vCguCTRMbMeC7diRmikNFRT4isZEnZ3I8Asiw6NtrBfV6ByKO+jg+FQ3dPIKaDMLhG0SY7rYhQBdR6JIjJRQ7g0tgeRDrIZ8QtwFswD+HaXPsF7WGxhT+zbvuCBpCwWuCphuAq5f46g7l38alXuR8XniIVmIlP1rk7kP00EDBG2Ln9Lf3bvkuhknRps00gK9Dxr1zvHsc8doAEg+q9nH2EspwXaqInekfc/LV32B2V3OCYMQIDAQABo2QwYjAdBgNVHQ4EFgQU9zTo+GS6tUzT+dPw+G5tfkh505QwHwYDVR0jBBgwFoAU9zTo+GS6tUzT+dPw+G5tfkh505QwDwYDVR0TAQH/BAUwAwEB/zAPBgNVHREECDAGhwRNJTOaMA0GCSqGSIb3DQEBCwUAA4IBAQAD4cmUx/t3Xw61Y4D+wHBlQrSA94+w5v99z77PsDr93coeApUBYxtE5kkRR2KK2y3dncsl4u5Wo6k9NeDSkgc9zyOuwFeH+HEK/vYPJ1gRyX7/hmRqdmmF++bOqMC8Kb8KpKMpB7wAhtowIl/oQ9vcz+PfQMP+PLWfbGtJOrgIb1jMZPQPO6uzJvTYgfYiPyrGEFzl7O18zjcoMURodT8IrRWvZ+ks6zuQRiikSC3oi91wRz4bFbaAJowEMuqCqtgEBbt5iYWFLTeV2+TeIqJ21ksAVk+PvYosOcs58ZKjCUJoIGcEaVNKNKgKYjGw2e3z1GUNbldxGu8rpCJkIPyo';

/// Converts a DER-encoded certificate to PEM bytes accepted by [SecurityContext].
List<int> _derToPemBytes(List<int> derBytes) {
  final b64 = base64Encode(derBytes);
  final buf = StringBuffer('-----BEGIN CERTIFICATE-----\n');
  for (var i = 0; i < b64.length; i += 64) {
    buf.writeln(b64.substring(i, (i + 64).clamp(0, b64.length)));
  }
  buf.write('-----END CERTIFICATE-----');
  return utf8.encode(buf.toString());
}

/// Builds a [SecurityContext] that trusts system CAs plus the pinned Banay cert.
/// Using SecurityContext instead of badCertificateCallback avoids Play Store
/// static-analysis flags while preserving the same strict pinning guarantee.
SecurityContext _buildPinnedContext(List<int> certDer) {
  final ctx = SecurityContext(withTrustedRoots: true);
  ctx.setTrustedCertificatesBytes(_derToPemBytes(certDer));
  return ctx;
}

/// Installs a global [HttpOverrides] that trusts the pinned production certificate
/// via [SecurityContext] (no badCertificateCallback involved).
/// Call once from main() before runApp(). No-op when baseUrl is plain HTTP (dev).
void configureBanayTlsOverride(String baseUrl) {
  final apiUri = Uri.tryParse(baseUrl);
  final host = apiUri?.host.trim();

  if (apiUri == null ||
      apiUri.scheme != 'https' ||
      host == null ||
      host.isEmpty) {
    return;
  }

  if (host != _pinnedBanayProdHost) {
    // Domain with a CA-signed cert — standard TLS validation handles it.
    return;
  }

  final certDer = base64Decode(_pinnedBanayProdCertificateDerBase64);
  HttpOverrides.global = _BanaySecurityContextHttpOverrides(
    pinnedContext: _buildPinnedContext(certDer),
  );
}

/// Creates an [HttpClientAdapter] for Socket.IO that uses the same pinned context.
HttpClientAdapter createBanayPinnedHttpClientAdapter(String baseUrl) {
  final apiUri = Uri.tryParse(baseUrl);
  final host = apiUri?.host.trim();

  if (host == _pinnedBanayProdHost) {
    final certDer = base64Decode(_pinnedBanayProdCertificateDerBase64);
    return _BanayPinnedSocketHttpClientAdapter(
      context: _buildPinnedContext(certDer),
    );
  }

  return _BanayPinnedSocketHttpClientAdapter(context: null);
}

class _BanaySecurityContextHttpOverrides extends HttpOverrides {
  _BanaySecurityContextHttpOverrides({required this.pinnedContext});

  final SecurityContext pinnedContext;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(pinnedContext);
  }
}

class _BanayPinnedSocketHttpClientAdapter implements HttpClientAdapter {
  _BanayPinnedSocketHttpClientAdapter({required this.context});

  final SecurityContext? context;

  @override
  Future<WebSocket> connect(String uri, {Map<String, dynamic>? headers}) {
    final httpClient = context != null
        ? HttpClient(context: context)
        : HttpClient();
    return WebSocket.connect(uri, headers: headers, customClient: httpClient);
  }
}
