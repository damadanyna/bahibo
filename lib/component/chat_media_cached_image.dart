import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

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
  /// Optional raw bytes shown as a blurred placeholder until the file loads.
  /// Pass the upload task's previewBytes for instant display before the
  /// server-side thumbnail is cached.
  final Uint8List? previewBytes;

  const ChatMediaCachedImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.filterQuality = FilterQuality.medium,
    this.width,
    this.height,
    this.errorChild,
    this.previewBytes,
  });

  @override
  State<ChatMediaCachedImage> createState() => _ChatMediaCachedImageState();
}

class _ChatMediaCachedImageState extends State<ChatMediaCachedImage> {
  Future<File?>? _fileFuture;
  File? _resolvedFile;
  Uint8List? _tinyThumb;

  @override
  void initState() {
    super.initState();
    _resolvedFile =
        ChatMediaCacheService.instance.peekResolvedFile(widget.imageUrl);
    _tinyThumb =
        ChatMediaCacheService.instance.peekTinyThumb(widget.imageUrl);
    _fileFuture = _loadFile();
  }

  @override
  void didUpdateWidget(covariant ChatMediaCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _resolvedFile =
          ChatMediaCacheService.instance.peekResolvedFile(widget.imageUrl);
      _tinyThumb =
          ChatMediaCacheService.instance.peekTinyThumb(widget.imageUrl);
      _fileFuture = _loadFile();
    }
  }

  Future<File?> _loadFile() async {
    final normalizedUrl = widget.imageUrl.trim();
    if (normalizedUrl.isEmpty) return null;

    // Load tiny thumb from Sembast if not already in memory.
    if (_tinyThumb == null) {
      final thumb =
          await ChatMediaCacheService.instance.getTinyThumb(normalizedUrl);
      if (thumb != null && mounted) {
        setState(() => _tinyThumb = thumb);
      } else {
        _tinyThumb = thumb;
      }
    }

    try {
      final file = await ChatMediaCacheService.instance
          .getOrDownloadFile(normalizedUrl);
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

  Widget _buildBlurPlaceholder(Uint8List bytes) {
    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Image.memory(
        bytes,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolvedFile = _resolvedFile;
    if (resolvedFile != null) {
      return _buildFileImage(resolvedFile);
    }

    final placeholder = widget.previewBytes ?? _tinyThumb;

    return FutureBuilder<File?>(
      future: _fileFuture,
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file != null) {
          return _buildFileImage(file);
        }

        if (placeholder != null) {
          return _buildBlurPlaceholder(placeholder);
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
