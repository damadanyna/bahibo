import 'dart:io';

import 'package:banay/formatter/price_formatter.dart';
import 'package:banay/services/product_realtime_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:banay/component/app_network_image.dart';
import 'package:banay/theme/app_theme_extensions.dart';
import '../page/productDetail.dart';

class ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final Widget Function(Map<String, dynamic> product)? detailPageBuilder;
  final ValueChanged<int>? onTap;

  const ProductCard({
    super.key,
    required this.product,
    this.detailPageBuilder,
    this.onTap,
  });

  Widget _buildDetailPage([Map<String, dynamic>? resolvedProduct]) {
    final effectiveProduct = resolvedProduct ?? product;
    if (detailPageBuilder != null) {
      return detailPageBuilder!(effectiveProduct);
    }

    return ProductDetailPage(product: effectiveProduct);
  }

  void _handleTap(
    BuildContext context,
    Map<String, dynamic> resolvedProduct, {
    int initialImageIndex = 0,
  }) {
    if (onTap != null) {
      onTap!(initialImageIndex);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _buildDetailPage(resolvedProduct)),
    );
  }

  bool _isDefaultPlaceholderImage(String value) {
    final normalizedValue = value.trim().toLowerCase();
    return normalizedValue.isEmpty ||
        normalizedValue.contains('via.placeholder.com');
  }

  List<String> _resolveProductImages(Map<String, dynamic> resolvedProduct) {
    final images =
        (resolvedProduct['images'] as List?)
            ?.whereType<String>()
            .map((image) => image.trim())
            .where((image) => !_isDefaultPlaceholderImage(image))
            .toList() ??
        <String>[];
    if (images.isNotEmpty) {
      return images;
    }

    final thumbnail = (resolvedProduct['thumbnail'] as String?)?.trim() ?? '';
    if (_isDefaultPlaceholderImage(thumbnail)) {
      return const <String>[];
    }

    return <String>[thumbnail];
  }

  @override
  Widget build(BuildContext context) {
    ProductRealtimeSyncService.instance.ensureInitialized();

    return ValueListenableBuilder<int>(
      valueListenable: ProductRealtimeSyncService.instance.changes,
      builder: (context, value, child) {
        final resolvedProduct = ProductRealtimeSyncService.instance
            .mergeIntoProduct(product);
        final theme = Theme.of(context);
        final appColors = theme.appColors;
        final borderColor = appColors.borderColor;
        final cardColor = appColors.productCardBackground;
        final titleColor =
            theme.textTheme.titleMedium?.color ?? theme.colorScheme.onSurface;
        final categoryColor = theme.colorScheme.primary;
        final priceColor = theme.colorScheme.error;
        final price = (resolvedProduct['price'] as num?)?.toDouble() ?? 0.0;
        final currency = resolveProductCurrency(resolvedProduct);

        return GestureDetector(
          onTap: () => _handleTap(context, resolvedProduct),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(width: 1, color: borderColor),
              borderRadius: BorderRadius.circular(10),
              color: cardColor,
            ),
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: _buildImageGrid(context, resolvedProduct),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resolvedProduct['title'] ?? 'Sans titre',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.account_circle,
                              size: 18,
                              color: categoryColor,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                resolvedProduct['category'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: categoryColor,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 2,
                          runSpacing: 2,
                          children: const [
                            Icon(Icons.star, color: Colors.white, size: 16),
                            Icon(Icons.star, color: Colors.white, size: 16),
                            Icon(Icons.star, color: Colors.white, size: 16),
                            Icon(Icons.star, color: Colors.white, size: 16),
                            Icon(Icons.star, color: Colors.white, size: 16),
                          ],
                        ),
                        const SizedBox(height: 30),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: formatPriceAmount(price)),
                              const TextSpan(text: ' '),
                              TextSpan(
                                text: currency,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: priceColor.withValues(alpha: 0.82),
                                ),
                              ),
                            ],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: priceColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageGrid(
    BuildContext context,
    Map<String, dynamic> resolvedProduct,
  ) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final List<String> images = _resolveProductImages(resolvedProduct);

    void openProductDetail([int initialImageIndex = 0]) {
      _handleTap(
        context,
        resolvedProduct,
        initialImageIndex: initialImageIndex,
      );
    }

    // Aucune image fournie → icone de fallback
    if (images.isEmpty) {
      return SizedBox(
        height: 170,
        child: _missingImageItem(context, onTap: () => openProductDetail()),
      );
    }

    // 1 image
    if (images.length == 1) {
      final [first] = images;
      return SizedBox(
        height: 170,
        child: _imageItem(context, first, onTap: () => openProductDetail()),
      );
    }

    // 2 images
    if (images.length == 2) {
      final [first, second] = images;
      return SizedBox(
        height: 170,
        child: Row(
          children: [
            Expanded(
              child: _imageItem(
                context,
                first,
                onTap: () => openProductDetail(0),
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: _imageItem(
                context,
                second,
                onTap: () => openProductDetail(1),
              ),
            ),
          ],
        ),
      );
    }

    // 3 images
    if (images.length == 3) {
      final [first, second, third] = images;
      return SizedBox(
        height: 170,
        child: Row(
          children: [
            Expanded(
              child: _imageItem(
                context,
                first,
                onTap: () => openProductDetail(0),
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: _imageItem(
                      context,
                      second,
                      onTap: () => openProductDetail(1),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Expanded(
                    child: _imageItem(
                      context,
                      third,
                      onTap: () => openProductDetail(2),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 4+ images → grille 2x2 + badge "+N"
    final [first, second, third, fourth, ...rest] = images;
    final int extra = rest.length;

    return SizedBox(
      height: 170,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _imageItem(
                    context,
                    first,
                    onTap: () => openProductDetail(0),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: _imageItem(
                    context,
                    second,
                    onTap: () => openProductDetail(1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _imageItem(
                    context,
                    third,
                    onTap: () => openProductDetail(2),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _imageItem(
                        context,
                        fourth,
                        onTap: () => openProductDetail(3),
                      ),
                      if (extra > 0)
                        Container(
                          decoration: BoxDecoration(
                            color: appColors.scrimSoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(
                            child: Text(
                              '+$extra',
                              style: TextStyle(
                                color: appColors.heroForeground,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _missingImageItem(BuildContext context, {VoidCallback? onTap}) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;

    return GestureDetector(
      onTap: onTap,
      child: AppImagePlaceholder(
        width: double.infinity,
        height: double.infinity,
        borderRadius: BorderRadius.circular(4),
        child: Center(
          child: Icon(
            Icons.image_not_supported,
            color: appColors.placeholderIcon,
            size: 30,
          ),
        ),
      ),
    );
  }

  Widget _imageItem(BuildContext context, String url, {VoidCallback? onTap}) {
    final theme = Theme.of(context);
    final fallbackIconColor =
        theme.iconTheme.color ?? theme.colorScheme.onSurfaceVariant;
    final isLocalFile =
        !(url.startsWith('http://') || url.startsWith('https://'));

    return GestureDetector(
      onTap: onTap,
      child: isLocalFile
          ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.file(
                File(url),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, _, _) =>
                    Icon(Icons.image_not_supported, color: fallbackIconColor),
              ),
            )
          : AppNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              borderRadius: BorderRadius.circular(4),
              errorChild: Icon(
                Icons.image_not_supported,
                color: fallbackIconColor,
              ),
            ),
    );
  }
}
