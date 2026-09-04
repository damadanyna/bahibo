import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:banay/services/link_preview_service.dart';

/// Renders [text] with tappable links (opened in the external browser) and,
/// optionally, highlighted mention triggers such as "@Name".
class AppLinkifiedText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final TextStyle? linkStyle;
  final List<String> mentionTriggers;
  final TextStyle? mentionStyle;
  final int? maxLines;
  final TextOverflow overflow;

  const AppLinkifiedText({
    super.key,
    required this.text,
    required this.style,
    this.linkStyle,
    this.mentionTriggers = const <String>[],
    this.mentionStyle,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  @override
  State<AppLinkifiedText> createState() => _AppLinkifiedTextState();
}

class _AppLinkifiedTextState extends State<AppLinkifiedText> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  Future<void> _openLink(String url) async {
    final opened = await LinkPreviewService.instance.open(url);
    if (opened || !mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Impossible d\'ouvrir ce lien.')),
    );
  }

  List<_TextSegment> _segments() {
    final text = widget.text;
    final segments = <_TextSegment>[];

    for (final range in LinkPreviewService.findLinkRanges(text)) {
      if (range.url.isEmpty) {
        continue;
      }
      segments.add(
        _TextSegment(start: range.start, end: range.end, url: range.url),
      );
    }

    if (widget.mentionTriggers.isNotEmpty) {
      final lower = text.toLowerCase();
      for (final trigger in widget.mentionTriggers) {
        final needle = trigger.toLowerCase();
        if (needle.isEmpty) {
          continue;
        }
        var from = 0;
        while (true) {
          final index = lower.indexOf(needle, from);
          if (index < 0) {
            break;
          }
          segments.add(
            _TextSegment(
              start: index,
              end: index + needle.length,
              isMention: true,
            ),
          );
          from = index + needle.length;
        }
      }
    }

    segments.sort((a, b) => a.start.compareTo(b.start));

    // Drop overlaps, links win over mentions because they were added first
    // and a stable sort keeps them ahead on equal starts.
    final result = <_TextSegment>[];
    var cursor = 0;
    for (final segment in segments) {
      if (segment.start < cursor) {
        continue;
      }
      result.add(segment);
      cursor = segment.end;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();

    final text = widget.text;
    final segments = _segments();
    if (segments.isEmpty) {
      return Text(
        text,
        style: widget.style,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      );
    }

    final linkStyle =
        widget.linkStyle ??
        widget.style.copyWith(
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
        );
    final mentionStyle =
        widget.mentionStyle ??
        widget.style.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        );

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final segment in segments) {
      if (segment.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, segment.start)));
      }
      final piece = text.substring(segment.start, segment.end);
      if (segment.url != null) {
        final recognizer = TapGestureRecognizer()
          ..onTap = () => _openLink(segment.url!);
        _recognizers.add(recognizer);
        spans.add(
          TextSpan(text: piece, style: linkStyle, recognizer: recognizer),
        );
      } else {
        spans.add(TextSpan(text: piece, style: mentionStyle));
      }
      cursor = segment.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(
      TextSpan(style: widget.style, children: spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}

class _TextSegment {
  final int start;
  final int end;
  final String? url;
  final bool isMention;

  const _TextSegment({
    required this.start,
    required this.end,
    this.url,
    this.isMention = false,
  });
}
