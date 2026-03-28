import 'package:flutter/material.dart';
import 'package:bahibo/component/app_network_image.dart';
import '../page/productDetail.dart';
import '../page/image_viewer_page.dart';

class ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  static const Color _cardBackgroundColor = Color(0xFF222120);
  static const Color _cardBorderColor = Color(0x1FFFFFFF);
  static const Color _titleColor = Colors.white;
  static const Color _metaTextColor = Color(0xFFD4D7DC);

  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
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
          border: Border.all(width: 1, color: _cardBorderColor),
          borderRadius: BorderRadius.circular(10),
          color: _cardBackgroundColor,
        ),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Row(
            children: [
              // Images
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _buildImageGrid(context),
                ),
              ),
              const SizedBox(width: 10),
              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['title'] ?? 'Sans titre',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.account_circle,
                          size: 18,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            product['category'] ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: const [
                        Icon(Icons.star, color: Colors.amber, size: 16),
                        Icon(Icons.star, color: Colors.amber, size: 16),
                        Icon(Icons.star, color: Colors.amber, size: 16),
                        Icon(Icons.star, color: Colors.amber, size: 16),
                        Icon(Icons.star, color: Colors.amber, size: 16),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Text(
                      '${((product['price'] as num).toDouble() * 400).toStringAsFixed(0)} MGA',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.red,
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
    // ✅ CORRECTION — uniquement product['images'], thumbnail en fallback
    final List<String> images =
        (product['images'] as List?)?.whereType<String>().toList() ?? [];

    final String placeholder =
        product['thumbnail'] as String? ?? 'https://via.placeholder.com/150';
    final List<String> galleryImages = images.isEmpty ? [placeholder] : images;

    void openGallery(int index) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ImageViewerPage(
            imageUrls: galleryImages,
            initialIndex: index,
            overlay: ImageViewerOverlayData(
              title: product['title'] as String? ?? 'Produit',
              description: product['category'] as String? ?? 'Annonce Bahibo',
            ),
          ),
        ),
      );
    }

    // images vide → thumbnail seul
    if (images.isEmpty) {
      return SizedBox(
        height: 170,
        child: _imageItem(placeholder, onTap: () => openGallery(0)),
      );
    }

    // 1 image
    if (images.length == 1) {
      final [first] = images;
      return SizedBox(
        height: 170,
        child: _imageItem(first, onTap: () => openGallery(0)),
      );
    }

    // 2 images
    if (images.length == 2) {
      final [first, second] = images;
      return SizedBox(
        height: 170,
        child: Row(
          children: [
            Expanded(child: _imageItem(first, onTap: () => openGallery(0))),
            const SizedBox(width: 2),
            Expanded(child: _imageItem(second, onTap: () => openGallery(1))),
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
            Expanded(child: _imageItem(first, onTap: () => openGallery(0))),
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: _imageItem(second, onTap: () => openGallery(1)),
                  ),
                  const SizedBox(height: 2),
                  Expanded(
                    child: _imageItem(third, onTap: () => openGallery(2)),
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
                Expanded(child: _imageItem(first, onTap: () => openGallery(0))),
                const SizedBox(width: 2),
                Expanded(
                  child: _imageItem(second, onTap: () => openGallery(1)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _imageItem(third, onTap: () => openGallery(2))),
                const SizedBox(width: 2),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _imageItem(fourth, onTap: () => openGallery(3)),
                      if (extra > 0)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(
                            child: Text(
                              '+$extra',
                              style: const TextStyle(
                                color: Colors.white,
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
  Widget _imageItem(String url, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AppNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        borderRadius: BorderRadius.circular(4),
        errorChild: const Icon(
          Icons.image_not_supported,
          color: _metaTextColor,
        ),
      ),
    );
  }
}
