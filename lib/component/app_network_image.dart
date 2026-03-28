import 'package:flutter/material.dart';

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

  static const Color backgroundColor = Color.fromARGB(75, 158, 158, 158);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
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
  final BorderRadius? borderRadius;
  final BoxShape shape;
  final Widget? errorChild;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.errorChild,
  });

  @override
  Widget build(BuildContext context) {
    final image = Image.network(
      imageUrl,
      fit: fit,
      width: width,
      height: height,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return AppImagePlaceholder(
          width: width,
          height: height,
          borderRadius: borderRadius,
          shape: shape,
        );
      },
      errorBuilder: (_, __, ___) {
        return AppImagePlaceholder(
          width: width,
          height: height,
          borderRadius: borderRadius,
          shape: shape,
          child: Center(
            child:
                errorChild ??
                const Icon(
                  Icons.image_not_supported,
                  color: Colors.grey,
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

  const AppCircleNetworkAvatar({
    super.key,
    required this.imageUrl,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final diameter = radius * 2;
    return AppNetworkImage(
      imageUrl: imageUrl,
      width: diameter,
      height: diameter,
      shape: BoxShape.circle,
    );
  }
}
