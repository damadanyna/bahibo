import 'package:flutter/material.dart';
import 'package:bahibo/component/app_network_image.dart';
import 'package:bahibo/theme/app_theme_extensions.dart';
import '../page/productDetail.dart';

class ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;

  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final borderColor = appColors.borderColor;
    final cardColor = theme.cardColor;
    final titleColor =
        theme.textTheme.titleMedium?.color ?? theme.colorScheme.onSurface;
    final categoryColor = theme.colorScheme.primary;
    final priceColor = theme.colorScheme.error;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailPage(product: product),
          ),
        );
      },
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
                  child: _buildImageGrid(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['title'] ?? 'Sans titre',
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
                            product['category'] ?? '',
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
                    Row(
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
                          TextSpan(
                            text: ((product['price'] as num).toDouble() * 400)
                                .toStringAsFixed(0),
                          ),
                          const TextSpan(text: ' '),
                          TextSpan(
                            text: 'MGA',
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
  }

  Widget _buildImageGrid(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;

    // ✅ CORRECTION — uniquement product['images'], thumbnail en fallback
    final List<String> images =
        (product['images'] as List?)?.whereType<String>().toList() ?? [];

    final String placeholder =
        product['thumbnail'] as String? ?? 'https://via.placeholder.com/150';

    void openProductDetail() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductDetailPage(product: product)),
      );
    }

    // images vide → thumbnail seul
    if (images.isEmpty) {
      return SizedBox(
        height: 170,
        child: _imageItem(context, placeholder, onTap: openProductDetail),
      );
    }

    // 1 image
    if (images.length == 1) {
      final [first] = images;
      return SizedBox(
        height: 170,
        child: _imageItem(context, first, onTap: openProductDetail),
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
              child: _imageItem(context, first, onTap: openProductDetail),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: _imageItem(context, second, onTap: openProductDetail),
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
              child: _imageItem(context, first, onTap: openProductDetail),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: _imageItem(
                      context,
                      second,
                      onTap: openProductDetail,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Expanded(
                    child: _imageItem(context, third, onTap: openProductDetail),
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
                  child: _imageItem(context, first, onTap: openProductDetail),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: _imageItem(context, second, onTap: openProductDetail),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _imageItem(context, third, onTap: openProductDetail),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _imageItem(context, fourth, onTap: openProductDetail),
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

  // ✅ _imageItem inchangé
  Widget _imageItem(BuildContext context, String url, {VoidCallback? onTap}) {
    final theme = Theme.of(context);
    final fallbackIconColor =
        theme.iconTheme.color ?? theme.colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      child: AppNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        borderRadius: BorderRadius.circular(4),
        errorChild: Icon(Icons.image_not_supported, color: fallbackIconColor),
      ),
    );
  }
}
