import 'package:banay/services/link_preview_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LinkPreviewService.extractUrls', () {
    test('detects http, https and www links', () {
      final urls = LinkPreviewService.extractUrls(
        'Regarde https://banay.mg/produit/12 et www.exemple.com ok http://a.b',
      );
      expect(urls, [
        'https://banay.mg/produit/12',
        'https://www.exemple.com',
        'http://a.b',
      ]);
    });

    test('strips trailing punctuation and dedupes', () {
      final urls = LinkPreviewService.extractUrls(
        'Voir https://x.com/page. Encore https://x.com/page, merci!',
      );
      expect(urls, ['https://x.com/page']);
    });

    test('keeps balanced parenthesis in url', () {
      final urls = LinkPreviewService.extractUrls(
        '(https://fr.wikipedia.org/wiki/Moto_(v%C3%A9hicule))',
      );
      expect(urls, ['https://fr.wikipedia.org/wiki/Moto_(v%C3%A9hicule)']);
    });

    test('returns nothing for plain text', () {
      expect(
        LinkPreviewService.extractUrls('Cet article est disponible ?'),
        isEmpty,
      );
    });
  });

  test('findLinkRanges gives ranges matching the original text', () {
    const text = 'lien: www.site.mg/x, fin';
    final ranges = LinkPreviewService.findLinkRanges(text);
    expect(ranges.length, 1);
    expect(
      text.substring(ranges.first.start, ranges.first.end),
      'www.site.mg/x',
    );
    expect(ranges.first.url, 'https://www.site.mg/x');
  });
}
