import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Metadata resolved for a link found in a message or a comment.
class LinkPreviewData {
  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? siteName;

  /// False when the link could not be reached (timeout, DNS error, HTTP
  /// error...). The card is still rendered so the user can try to open it.
  final bool isReachable;

  const LinkPreviewData({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
    required this.isReachable,
  });

  String get host {
    final uri = Uri.tryParse(url);
    final host = uri?.host ?? '';
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  bool get hasMetadata =>
      (title?.isNotEmpty ?? false) ||
      (description?.isNotEmpty ?? false) ||
      (imageUrl?.isNotEmpty ?? false);
}

/// Detects URLs inside free text, fetches their Open Graph metadata once
/// (in-memory cache) and opens them in the external browser.
class LinkPreviewService {
  LinkPreviewService._();

  static final LinkPreviewService instance = LinkPreviewService._();

  static const Duration _timeout = Duration(seconds: 8);
  static const int _maxHtmlBytes = 256 * 1024;

  /// Browser-like UA, used to download preview pictures (CDNs often reject
  /// the default Dart client) and as a fallback for pages.
  static const String userAgent =
      'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/124.0 Mobile Safari/537.36';

  /// Messaging-app UA tried first: Facebook, Instagram and similar sites only
  /// serve their Open Graph tags to link-preview crawlers, and answer a
  /// login page to anonymous browsers.
  static const String _previewCrawlerUserAgent = 'WhatsApp/2.23.20.0 A';

  static final RegExp _urlPattern = RegExp(
    r'(?:https?://|www\.)[^\s<>"]+',
    caseSensitive: false,
  );
  static const String _trailingPunctuation = '.,;:!?)]}\'"';

  final Map<String, Future<LinkPreviewData>> _cache =
      <String, Future<LinkPreviewData>>{};

  /// Every http(s) / www. link in [text], in order of appearance, without
  /// duplicates. Trailing punctuation ("voir https://x.com.") is stripped.
  static List<String> extractUrls(String text) {
    if (text.isEmpty) {
      return const <String>[];
    }
    final seen = <String>{};
    final urls = <String>[];
    for (final match in _urlPattern.allMatches(text)) {
      final raw = _trimTrailingPunctuation(match.group(0)!);
      final normalized = normalizeUrl(raw);
      if (normalized.isEmpty || !seen.add(normalized)) {
        continue;
      }
      urls.add(normalized);
    }
    return urls;
  }

  /// Ranges (start, end) of every link in [text], used to make them tappable
  /// inline. Same trimming rules as [extractUrls].
  static List<LinkTextRange> findLinkRanges(String text) {
    final ranges = <LinkTextRange>[];
    for (final match in _urlPattern.allMatches(text)) {
      final raw = _trimTrailingPunctuation(match.group(0)!);
      if (raw.isEmpty) {
        continue;
      }
      ranges.add(
        LinkTextRange(
          start: match.start,
          end: match.start + raw.length,
          url: normalizeUrl(raw),
        ),
      );
    }
    return ranges;
  }

  static String normalizeUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final withScheme = trimmed.toLowerCase().startsWith('www.')
        ? 'https://$trimmed'
        : trimmed;
    final uri = Uri.tryParse(withScheme);
    if (uri == null || uri.host.isEmpty) {
      return '';
    }
    return withScheme;
  }

  static String _trimTrailingPunctuation(String value) {
    var end = value.length;
    while (end > 0 && _trailingPunctuation.contains(value[end - 1])) {
      // Keep a closing parenthesis when it is balanced (wikipedia-style urls).
      if (value[end - 1] == ')' &&
          value.substring(0, end).split('(').length ==
              value.substring(0, end).split(')').length) {
        break;
      }
      end--;
    }
    return value.substring(0, end);
  }

  Future<LinkPreviewData> fetch(String url) {
    return _cache.putIfAbsent(url, () => _fetchUncached(url));
  }

  Future<bool> open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return false;
    }
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<LinkPreviewData> _fetchUncached(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return LinkPreviewData(url: url, isReachable: false);
    }

    final asCrawler = await _fetchAs(url, uri, _previewCrawlerUserAgent);
    if (asCrawler.isReachable && asCrawler.hasMetadata) {
      return asCrawler;
    }
    // Sites that block unknown bots (challenge pages) usually answer a
    // browser; keep whichever attempt got further.
    final asBrowser = await _fetchAs(url, uri, userAgent);
    if (asBrowser.isReachable &&
        (asBrowser.hasMetadata || !asCrawler.isReachable)) {
      return asBrowser;
    }
    return asCrawler;
  }

  Future<LinkPreviewData> _fetchAs(String url, Uri uri, String agent) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', uri)
        ..headers['User-Agent'] = agent
        ..headers['Accept'] = 'text/html,application/xhtml+xml,*/*;q=0.8'
        ..followRedirects = true
        ..maxRedirects = 5;
      final response = await client.send(request).timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 400) {
        return LinkPreviewData(url: url, isReachable: false);
      }

      final contentType = (response.headers['content-type'] ?? '')
          .toLowerCase();
      if (contentType.startsWith('image/')) {
        // Direct link to a picture: the picture itself is the preview.
        return LinkPreviewData(
          url: url,
          imageUrl: url,
          title: _fileNameOf(uri),
          isReachable: true,
        );
      }
      if (!contentType.contains('html')) {
        // Reachable but not a page (pdf, video...): plain reachable card.
        return LinkPreviewData(url: url, isReachable: true);
      }

      final html = await _readBounded(response.stream).timeout(_timeout);
      final finalUri = _resolveFinalUri(response, uri);
      return _parseHtml(url: url, baseUri: finalUri, html: html);
    } catch (_) {
      return LinkPreviewData(url: url, isReachable: false);
    } finally {
      client.close();
    }
  }

  String? _fileNameOf(Uri uri) {
    if (uri.pathSegments.isEmpty) {
      return null;
    }
    final name = uri.pathSegments.last.trim();
    return name.isEmpty ? null : name;
  }

  Uri _resolveFinalUri(http.StreamedResponse response, Uri requested) {
    final location = response.request?.url;
    return location ?? requested;
  }

  Future<String> _readBounded(http.ByteStream stream) async {
    final buffer = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      buffer.add(chunk);
      if (buffer.length >= _maxHtmlBytes) {
        break;
      }
    }
    return utf8.decode(buffer.takeBytes(), allowMalformed: true);
  }

  LinkPreviewData _parseHtml({
    required String url,
    required Uri baseUri,
    required String html,
  }) {
    final title =
        _metaContent(html, const ['og:title', 'twitter:title']) ??
        _titleTag(html);
    final description = _metaContent(html, const [
      'og:description',
      'twitter:description',
      'description',
    ]);
    final rawImage = _metaContent(html, const [
      'og:image',
      'og:image:url',
      'twitter:image',
    ]);
    final siteName = _metaContent(html, const ['og:site_name']);

    String? imageUrl;
    if (rawImage != null && rawImage.isNotEmpty) {
      final resolved = Uri.tryParse(rawImage);
      if (resolved != null) {
        final absolute = resolved.hasScheme
            ? resolved
            : baseUri.resolveUri(resolved);
        if (absolute.scheme == 'http' || absolute.scheme == 'https') {
          imageUrl = absolute.toString();
        }
      }
    }

    return LinkPreviewData(
      url: url,
      title: _clean(title),
      description: _clean(description),
      imageUrl: imageUrl,
      siteName: _clean(siteName),
      isReachable: true,
    );
  }

  /// Reads `<meta property|name="key" content="...">` in either attribute
  /// order. First key of [keys] found wins.
  String? _metaContent(String html, List<String> keys) {
    for (final key in keys) {
      final escaped = RegExp.escape(key);
      final patterns = <RegExp>[
        RegExp(
          '<meta[^>]*?(?:property|name)\\s*=\\s*["\']$escaped["\'][^>]*?content\\s*=\\s*["\']([^"\']*)["\']',
          caseSensitive: false,
        ),
        RegExp(
          '<meta[^>]*?content\\s*=\\s*["\']([^"\']*)["\'][^>]*?(?:property|name)\\s*=\\s*["\']$escaped["\']',
          caseSensitive: false,
        ),
      ];
      for (final pattern in patterns) {
        final match = pattern.firstMatch(html);
        final value = match?.group(1)?.trim();
        if (value != null && value.isNotEmpty) {
          return value;
        }
      }
    }
    return null;
  }

  String? _titleTag(String html) {
    final match = RegExp(
      r'<title[^>]*>([\s\S]*?)</title>',
      caseSensitive: false,
    ).firstMatch(html);
    return match?.group(1)?.trim();
  }

  String? _clean(String? value) {
    if (value == null) {
      return null;
    }
    final decoded = _decodeEntities(
      value,
    ).replaceAll(RegExp(r'\s+'), ' ').trim();
    return decoded.isEmpty ? null : decoded;
  }

  String _decodeEntities(String value) {
    return value
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', '\'')
        .replaceAll('&apos;', '\'')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAllMapped(
          RegExp(r'&#x([0-9a-fA-F]+);'),
          (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
        )
        .replaceAllMapped(
          RegExp(r'&#(\d+);'),
          (m) => String.fromCharCode(int.parse(m.group(1)!)),
        )
        .replaceAll('&amp;', '&');
  }
}

class LinkTextRange {
  final int start;
  final int end;
  final String url;

  const LinkTextRange({
    required this.start,
    required this.end,
    required this.url,
  });
}
