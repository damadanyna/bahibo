import 'package:flutter/material.dart';

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

class AppNetworkImage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).appColors;
    final mediaQuery = MediaQuery.maybeOf(context);
    final devicePixelRatio = mediaQuery?.devicePixelRatio ?? 1.0;
    final cacheWidth = _resolveCacheDimension(width, devicePixelRatio);
    final cacheHeight = _resolveCacheDimension(height, devicePixelRatio);

    final image = Image.network(
      imageUrl,
      fit: fit,
      filterQuality: filterQuality,
      width: width,
      height: height,
      cacheWidth: cacheWidth != null && cacheWidth > 0 ? cacheWidth : null,
      cacheHeight: cacheHeight != null && cacheHeight > 0 ? cacheHeight : null,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return AppImagePlaceholder(
          width: width,
          height: height,
          borderRadius: borderRadius,
          shape: shape,
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
          width: width,
          height: height,
          borderRadius: borderRadius,
          shape: shape,
          child: Center(
            child:
                errorChild ??
                Icon(
                  Icons.image_not_supported,
                  color: appColors.placeholderIcon,
                  size: 28,
                ),
          ),
        );
      },
    );

    if (shape == BoxShape.circle) {
      return ClipOval(
        child: SizedBox(width: width, height: height, child: image),
      );
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }
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
    final shouldShowBadge = showPresenceBadge && normalizedUserId.isNotEmpty;

    if (shouldShowBadge) {
      PresenceService.instance.watchUser(normalizedUserId);
    }

    final avatar = AppNetworkImage(
      imageUrl: imageUrl,
      width: diameter,
      height: diameter,
      shape: BoxShape.circle,
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

