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
  File? _resolvedFile;

  @override
  void initState() {
    super.initState();
    _resolvedFile = ChatMediaCacheService.instance.peekResolvedFile(
      widget.imageUrl,
    );
    _fileFuture = _loadFile();
  }

  @override
  void didUpdateWidget(covariant ChatMediaCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _resolvedFile = ChatMediaCacheService.instance.peekResolvedFile(
        widget.imageUrl,
      );
      _fileFuture = _loadFile();
    }
  }

  Future<File?> _loadFile() async {
    final normalizedUrl = widget.imageUrl.trim();
    if (normalizedUrl.isEmpty) {
      return null;
    }

    try {
      final file = await ChatMediaCacheService.instance.getOrDownloadFile(
        normalizedUrl,
      );
      if (mounted) {
        setState(() => _resolvedFile = file);
      } else {
        _resolvedFile = file;
      }
      return file;
    } catch (_) {
      return null;
    }
  }

  Widget _buildFileImage(File file) {
    return Image.file(
      file,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      filterQuality: widget.filterQuality,
      gaplessPlayback: true,
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

  @override
  Widget build(BuildContext context) {
    final resolvedFile = _resolvedFile;
    if (resolvedFile != null) {
      return _buildFileImage(resolvedFile);
    }

    return FutureBuilder<File?>(
      future: _fileFuture,
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file != null) {
          return _buildFileImage(file);
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
