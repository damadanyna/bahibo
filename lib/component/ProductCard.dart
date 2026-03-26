import 'package:flutter/material.dart';
import '../page/productDetail.dart';

class ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;

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
          border: Border.all(
            width: 1,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey.shade700
                : const Color.fromARGB(255, 223, 223, 223),
          ),
          borderRadius: BorderRadius.circular(10),
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey.shade900
              : Colors.white,
        ),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Row(
            children: [
              // Images
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _buildImageGrid(),
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
                      style: const TextStyle(fontWeight: FontWeight.w700),
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

  Widget _buildImageGrid() {
    // ✅ CORRECTION — uniquement product['images'], thumbnail en fallback
    final List<String> images =
        (product['images'] as List?)?.whereType<String>().toList() ?? [];

    final String placeholder =
        product['thumbnail'] as String? ?? 'https://via.placeholder.com/150';

    // images vide → thumbnail seul
    if (images.isEmpty) {
      return SizedBox(height: 170, child: _imageItem(placeholder));
    }

    // 1 image
    if (images.length == 1) {
      final [first] = images;
      return SizedBox(height: 170, child: _imageItem(first));
    }

    // 2 images
    if (images.length == 2) {
      final [first, second] = images;
      return SizedBox(
        height: 170,
        child: Row(
          children: [
            Expanded(child: _imageItem(first)),
            const SizedBox(width: 2),
            Expanded(child: _imageItem(second)),
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
            Expanded(child: _imageItem(first)),
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _imageItem(second)),
                  const SizedBox(height: 2),
                  Expanded(child: _imageItem(third)),
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
                Expanded(child: _imageItem(first)),
                const SizedBox(width: 2),
                Expanded(child: _imageItem(second)),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _imageItem(third)),
                const SizedBox(width: 2),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _imageItem(fourth),
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
  Widget _imageItem(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.green,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey.shade200,
          child: const Icon(Icons.image_not_supported, color: Colors.grey),
        ),
      ),
    );
  }
}
