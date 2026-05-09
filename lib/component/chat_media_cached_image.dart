import 'dart:io';

import 'package:banay/component/app_network_image.dart';
import 'package:banay/services/chat_media_cache_service.dart';
import 'package:flutter/material.dart';

class ChatMediaCachedImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final FilterQuality filterQuality;
  final double? width;
  final double? height;
  final Widget? errorChild;

  const ChatMediaCachedImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.filterQuality = FilterQuality.medium,
    this.width,
    this.height,
    this.errorChild,
  });

  @override
  State<ChatMediaCachedImage> createState() => _ChatMediaCachedImageState();
}

class _ChatMediaCachedImageState extends State<ChatMediaCachedImage> {
  Future<File?>? _fileFuture;

  @override
  void initState() {
    super.initState();
    _fileFuture = _loadFile();
  }

  @override
  void didUpdateWidget(covariant ChatMediaCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _fileFuture = _loadFile();
    }
  }

  Future<File?> _loadFile() async {
    final normalizedUrl = widget.imageUrl.trim();
    if (normalizedUrl.isEmpty) {
      return null;
    }

    try {
      return await ChatMediaCacheService.instance.getOrDownloadFile(
        normalizedUrl,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: _fileFuture,
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file != null) {
          return Image.file(
            file,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            filterQuality: widget.filterQuality,
            errorBuilder: (context, error, stackTrace) {
              return AppNetworkImage(
                imageUrl: widget.imageUrl,
                width: widget.width,
                height: widget.height,
                fit: widget.fit,
                filterQuality: widget.filterQuality,
                errorChild: widget.errorChild,
              );
            },
          );
        }

        return AppNetworkImage(
          imageUrl: widget.imageUrl,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          filterQuality: widget.filterQuality,
          errorChild: widget.errorChild,
        );
      },
    );
  }
}
