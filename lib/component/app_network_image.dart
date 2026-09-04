import 'dart:io';

import 'package:flutter/material.dart';

import 'package:banay/services/chat_media_cache_service.dart';
import 'package:banay/services/presence_service.dart';
import 'package:banay/theme/app_theme_extensions.dart';

class AppImagePlaceholder extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxShape shape;
  final Widget? child;

  const AppImagePlaceholder({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).appColors;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: appColors.placeholderFill,
        shape: shape,
        borderRadius: shape == BoxShape.circle ? null : borderRadius,
      ),
      child: child,
    );
  }
}

class AppNetworkImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final FilterQuality filterQuality;
  final BorderRadius? borderRadius;
  final BoxShape shape;
  final Widget? errorChild;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.filterQuality = FilterQuality.low,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.errorChild,
  });

  @override
  State<AppNetworkImage> createState() => _AppNetworkImageState();
}

class _AppNetworkImageState extends State<AppNetworkImage> {
  Future<File?>? _fileFuture;
  File? _resolvedFile;

  int? _resolveCacheDimension(double? dimension, double devicePixelRatio) {
    if (dimension == null || !dimension.isFinite || dimension <= 0) {
      return null;
    }

    final scaledDimension = dimension * devicePixelRatio;
    if (!scaledDimension.isFinite || scaledDimension <= 0) {
      return null;
    }

    return scaledDimension.round();
  }

  @override
  void initState() {
    super.initState();
    _resolvedFile = ChatMediaCacheService.instance.peekResolvedFile(
      widget.imageUrl,
    );
    _fileFuture = _loadFile();
  }

  @override
  void didUpdateWidget(covariant AppNetworkImage oldWidget) {
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

  Widget _wrapImage(Widget image) {
    if (widget.shape == BoxShape.circle) {
      return ClipOval(
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: image,
        ),
      );
    }

    if (widget.borderRadius != null) {
      return ClipRRect(borderRadius: widget.borderRadius!, child: image);
    }

    return image;
  }

  Widget _buildFallbackNetworkImage({
    required BuildContext context,
    required int? cacheWidth,
    required int? cacheHeight,
  }) {
    final appColors = Theme.of(context).appColors;
    return _wrapImage(
      Image.network(
        widget.imageUrl,
        fit: widget.fit,
        filterQuality: widget.filterQuality,
        width: widget.width,
        height: widget.height,
        gaplessPlayback: true,
        cacheWidth: cacheWidth != null && cacheWidth > 0 ? cacheWidth : null,
        cacheHeight: cacheHeight != null && cacheHeight > 0
            ? cacheHeight
            : null,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return AppImagePlaceholder(
            width: widget.width,
            height: widget.height,
            borderRadius: widget.borderRadius,
            shape: widget.shape,
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: appColors.placeholderIcon,
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return AppImagePlaceholder(
            width: widget.width,
            height: widget.height,
            borderRadius: widget.borderRadius,
            shape: widget.shape,
            child: Center(
              child:
                  widget.errorChild ??
                  Icon(
                    Icons.image_not_supported,
                    color: appColors.placeholderIcon,
                    size: 28,
                  ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFileImage(File file) {
    return _wrapImage(
      Image.file(
        file,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        filterQuality: widget.filterQuality,
        gaplessPlayback: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final devicePixelRatio = mediaQuery?.devicePixelRatio ?? 1.0;
    final cacheWidth = _resolveCacheDimension(widget.width, devicePixelRatio);
    final cacheHeight = _resolveCacheDimension(widget.height, devicePixelRatio);

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

        return _buildFallbackNetworkImage(
          context: context,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
        );
      },
    );
  }
}

/// Stock portraits (pravatar / Unsplash) that the app and the backend used
/// to hand out for users without a photo. They must render as "no avatar"
/// (person icon), never as a real picture, even if a cached response, demo
/// data or a database row still carries one. Real avatars are Cloudinary
/// uploads.
bool isPlaceholderAvatarUrl(String? url) {
  final normalized = url?.trim().toLowerCase() ?? '';
  return normalized.contains('i.pravatar.cc/') ||
      normalized.contains('images.unsplash.com/');
}

/// Trimmed avatar URL, or '' when absent or a known placeholder portrait.
String normalizeAvatarUrl(String? url) {
  final normalized = url?.trim() ?? '';
  return isPlaceholderAvatarUrl(normalized) ? '' : normalized;
}

class AppCircleNetworkAvatar extends StatelessWidget {
  final String imageUrl;
  final double radius;
  final String? userId;
  final bool showPresenceBadge;

  const AppCircleNetworkAvatar({
    super.key,
    required this.imageUrl,
    required this.radius,
    this.userId,
    this.showPresenceBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    final diameter = radius * 2;
    final normalizedUserId = userId?.trim() ?? '';
    final normalizedImageUrl = normalizeAvatarUrl(imageUrl);
    final shouldShowBadge = showPresenceBadge && normalizedUserId.isNotEmpty;

    if (shouldShowBadge) {
      PresenceService.instance.watchUser(normalizedUserId);
    }

    final avatar = normalizedImageUrl.isEmpty
        ? _DefaultCircleAvatar(radius: radius)
        : AppNetworkImage(
            key: ValueKey(normalizedImageUrl),
            imageUrl: normalizedImageUrl,
            width: diameter,
            height: diameter,
            shape: BoxShape.circle,
            errorChild: _DefaultCircleAvatarGlyph(radius: radius),
          );

    if (!shouldShowBadge) {
      return avatar;
    }

    return ValueListenableBuilder<int>(
      valueListenable: PresenceService.instance.changes,
      builder: (context, value, child) {
        final appColors = Theme.of(context).appColors;
        final isOnline =
            PresenceService.instance.presenceOf(normalizedUserId) == true;
        final badgeSize = radius <= 18 ? 10.0 : 14.0;
        const offlineBadgeColor = Color(0xFF9E9E9E);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            avatar,
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  color: isOnline ? appColors.onlineStatus : offlineBadgeColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DefaultCircleAvatar extends StatelessWidget {
  const _DefaultCircleAvatar({required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) {
    final diameter = radius * 2;
    return AppImagePlaceholder(
      width: diameter,
      height: diameter,
      shape: BoxShape.circle,
      child: _DefaultCircleAvatarGlyph(radius: radius),
    );
  }
}

class _DefaultCircleAvatarGlyph extends StatelessWidget {
  const _DefaultCircleAvatarGlyph({required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).appColors;
    final iconSize = radius <= 18
        ? 18.0
        : radius <= 24
        ? 22.0
        : 28.0;

    return Center(
      child: Icon(
        Icons.person,
        size: iconSize,
        color: appColors.placeholderIcon,
      ),
    );
  }
}
