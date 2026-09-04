import 'package:flutter/material.dart';

import 'package:banay/services/link_preview_service.dart';

/// WhatsApp-style preview of a link found in a message or a comment.
/// Shows a loading state while the link is checked, then the page image,
/// title, description and domain. Tapping opens the link externally.
class AppLinkPreviewCard extends StatefulWidget {
  final String url;
  final Color primary;
  final Color cardColor;
  final Color textColor;
  final Color subtleText;
  final Color? borderColor;

  /// Smaller text / image for dense lists (comments).
  final bool compact;

  const AppLinkPreviewCard({
    super.key,
    required this.url,
    required this.primary,
    required this.cardColor,
    required this.textColor,
    required this.subtleText,
    this.borderColor,
    this.compact = false,
  });

  @override
  State<AppLinkPreviewCard> createState() => _AppLinkPreviewCardState();
}

class _AppLinkPreviewCardState extends State<AppLinkPreviewCard> {
  late Future<LinkPreviewData> _future;

  @override
  void initState() {
    super.initState();
    _future = LinkPreviewService.instance.fetch(widget.url);
  }

  @override
  void didUpdateWidget(covariant AppLinkPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _future = LinkPreviewService.instance.fetch(widget.url);
    }
  }

  Future<void> _open() async {
    final opened = await LinkPreviewService.instance.open(widget.url);
    if (opened || !mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Impossible d\'ouvrir ce lien.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.compact ? 12 : 16);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _open,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            color: widget.cardColor,
            borderRadius: radius,
            border: Border.all(
              color:
                  widget.borderColor ??
                  widget.subtleText.withValues(alpha: 0.25),
            ),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: FutureBuilder<LinkPreviewData>(
              future: _future,
              builder: (context, snapshot) {
                final data = snapshot.data;
                if (data == null) {
                  return _StatusRow(
                    icon: Icons.link_rounded,
                    iconColor: widget.primary,
                    title: _hostOf(widget.url),
                    subtitle: 'Verification du lien...',
                    textColor: widget.textColor,
                    subtleText: widget.subtleText,
                    compact: widget.compact,
                    trailing: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.primary,
                      ),
                    ),
                  );
                }

                if (!data.isReachable) {
                  return _StatusRow(
                    icon: Icons.link_off_rounded,
                    iconColor: widget.subtleText,
                    title: data.host.isEmpty ? widget.url : data.host,
                    subtitle: 'Lien inaccessible pour le moment',
                    textColor: widget.textColor,
                    subtleText: widget.subtleText,
                    compact: widget.compact,
                  );
                }

                if (!data.hasMetadata) {
                  return _StatusRow(
                    icon: Icons.open_in_new_rounded,
                    iconColor: widget.primary,
                    title: data.host.isEmpty ? widget.url : data.host,
                    subtitle: widget.url,
                    textColor: widget.textColor,
                    subtleText: widget.subtleText,
                    compact: widget.compact,
                  );
                }

                return _MetadataBody(
                  data: data,
                  primary: widget.primary,
                  textColor: widget.textColor,
                  subtleText: widget.subtleText,
                  compact: widget.compact,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  static String _hostOf(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    if (host.isEmpty) {
      return url;
    }
    return host.startsWith('www.') ? host.substring(4) : host;
  }
}

class _MetadataBody extends StatelessWidget {
  final LinkPreviewData data;
  final Color primary;
  final Color textColor;
  final Color subtleText;
  final bool compact;

  const _MetadataBody({
    required this.data,
    required this.primary,
    required this.textColor,
    required this.subtleText,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = data.imageUrl;
    final title = data.title;
    final description = data.description;
    final host = data.siteName?.isNotEmpty == true ? data.siteName! : data.host;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (imageUrl != null && imageUrl.isNotEmpty)
          _PreviewImage(
            imageUrl: imageUrl,
            height: compact ? 96 : 140,
            subtleText: subtleText,
          ),
        Padding(
          padding: EdgeInsets.all(compact ? 10 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null && title.isNotEmpty)
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: compact ? 13 : 14,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
              if (description != null && description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.82),
                    fontSize: compact ? 12 : 13,
                    height: 1.3,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.public_rounded, size: 13, color: subtleText),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subtleText,
                        fontSize: compact ? 11 : 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Loads the preview picture with a browser-like User-Agent (CDNs often
/// reject the default Dart client) and collapses to nothing on failure
/// instead of leaving an empty grey block.
class _PreviewImage extends StatelessWidget {
  final String imageUrl;
  final double height;
  final Color subtleText;

  const _PreviewImage({
    required this.imageUrl,
    required this.height,
    required this.subtleText,
  });

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      headers: const {'User-Agent': LinkPreviewService.userAgent},
      loadingBuilder: (context, child, progress) {
        if (progress == null) {
          return child;
        }
        return Container(
          height: height,
          width: double.infinity,
          color: subtleText.withValues(alpha: 0.10),
          alignment: Alignment.center,
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: subtleText),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color textColor;
  final Color subtleText;
  final bool compact;
  final Widget? trailing;

  const _StatusRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.textColor,
    required this.subtleText,
    required this.compact,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(compact ? 10 : 12),
      child: Row(
        children: [
          Container(
            width: compact ? 32 : 38,
            height: compact ? 32 : 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(compact ? 10 : 12),
            ),
            child: Icon(icon, color: iconColor, size: compact ? 18 : 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: compact ? 13 : 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: subtleText,
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}
