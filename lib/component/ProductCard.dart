import 'dart:io';

import 'package:banay/component/app_network_image.dart';
import 'package:banay/component/app_share_sheet.dart';
import 'package:banay/component/profile_models.dart';
import 'package:banay/component/seller_profile_page.dart';
import 'package:banay/component/ui/seller_certified_badge.dart';
import 'package:banay/formatter/price_formatter.dart';
import 'package:banay/page/productDetail.dart';
import 'package:banay/services/app_api_client.dart';
import 'package:banay/services/catalog_api_service.dart';
import 'package:banay/services/cloudinary_image_url.dart';
import 'package:banay/services/product_realtime_sync_service.dart';
import 'package:banay/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';

enum ProductCardVariant { editorial, marketplace }

class ProductCard extends StatefulWidget {
  final Map<String, dynamic> product;
  final Widget Function(Map<String, dynamic> product)? detailPageBuilder;
  final ValueChanged<int>? onTap;
  final ProductCardVariant variant;
  final Widget? topRightOverlay;

  const ProductCard({
    super.key,
    required this.product,
    this.detailPageBuilder,
    this.onTap,
    this.variant = ProductCardVariant.editorial,
    this.topRightOverlay,
  });

  Widget buildDetailPage([Map<String, dynamic>? resolvedProduct]) {
    final effectiveProduct = resolvedProduct ?? product;
    if (detailPageBuilder != null) {
      return detailPageBuilder!(effectiveProduct);
    }

    return ProductDetailPage(product: effectiveProduct);
  }

  bool isDefaultPlaceholderImage(String value) {
    final normalizedValue = value.trim().toLowerCase();
    return normalizedValue.isEmpty ||
        normalizedValue.contains('via.placeholder.com');
  }

  List<String> resolveProductImages(Map<String, dynamic> resolvedProduct) {
    final images =
        (resolvedProduct['images'] as List?)
            ?.whereType<String>()
            .map((image) => image.trim())
            .where((image) => !isDefaultPlaceholderImage(image))
            .toList() ??
        <String>[];
    if (images.isNotEmpty) {
      return images;
    }

    final thumbnail = (resolvedProduct['thumbnail'] as String?)?.trim() ?? '';
    if (isDefaultPlaceholderImage(thumbnail)) {
      return const <String>[];
    }

    return <String>[thumbnail];
  }

  Map<String, dynamic> resolveSeller(Map<String, dynamic> resolvedProduct) {
    final rawSeller = resolvedProduct['seller'];
    if (rawSeller is Map) {
      return Map<String, dynamic>.from(rawSeller);
    }
    return const <String, dynamic>{};
  }

  String resolveCategoryLabel(Map<String, dynamic> resolvedProduct) {
    final rawCategory = resolvedProduct['category'];
    if (rawCategory is String && rawCategory.trim().isNotEmpty) {
      return rawCategory.trim();
    }
    return 'Produit';
  }

  String resolveSellerName(Map<String, dynamic> resolvedProduct) {
    final seller = resolveSeller(resolvedProduct);
    final candidates = <Object?>[
      seller['name'],
      seller['displayName'],
      seller['studioName'],
      seller['shopName'],
      seller['username'],
      seller['user']?['displayName'],
      resolvedProduct['sellerName'],
      resolvedProduct['vendorName'],
      resolvedProduct['displayName'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }

    return 'Vendeur';
  }

  String resolveSellerAvatarUrl(Map<String, dynamic> resolvedProduct) {
    final seller = resolveSeller(resolvedProduct);
    final candidates = <Object?>[
      seller['avatarUrl'],
      seller['profileImageUrl'],
      seller['user']?['avatarUrl'],
      resolvedProduct['sellerAvatarUrl'],
      resolvedProduct['avatarUrl'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isNotEmpty && !isDefaultPlaceholderImage(value)) {
        return value;
      }
    }

    return '';
  }

  String resolveSellerUserId(Map<String, dynamic> resolvedProduct) {
    final seller = resolveSeller(resolvedProduct);
    final candidates = <Object?>[seller['userId'], seller['id']];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }

  int resolveMetricCount(
    Map<String, dynamic> resolvedProduct,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = resolvedProduct[key];
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return 0;
  }

  bool resolveAvailability(Map<String, dynamic> resolvedProduct) {
    final rawValue = resolvedProduct['isAvailable'];
    if (rawValue is bool) {
      return rawValue;
    }
    return true;
  }

  String formatMetricCount(int value) {
    if (value >= 1000000) {
      final formatted = (value / 1000000).toStringAsFixed(
        value >= 10000000 ? 0 : 1,
      );
      return '${formatted.replaceAll('.0', '')}M';
    }
    if (value >= 1000) {
      final formatted = (value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1);
      return '${formatted.replaceAll('.0', '')}k';
    }
    return value.toString();
  }

  String resolveBadgeLabel(
    Map<String, dynamic> resolvedProduct,
    bool isMarketplace,
  ) {
    final rawBadge = resolvedProduct['badgeLabel'];
    if (rawBadge is String && rawBadge.trim().isNotEmpty) {
      return rawBadge.trim();
    }
    if (isMarketplace) {
      return 'A la une';
    }
    return resolveCategoryLabel(resolvedProduct);
  }

  String resolvePrimaryLine(
    Map<String, dynamic> resolvedProduct,
    String categoryLabel,
    bool isAvailable,
  ) {
    final rawSubtitle = resolvedProduct['subtitle'];
    if (rawSubtitle is String && rawSubtitle.trim().isNotEmpty) {
      return rawSubtitle.trim();
    }

    final rawTitle = resolvedProduct['title'];
    if (rawTitle is String && rawTitle.trim().isNotEmpty) {
      return rawTitle.trim();
    }

    return isAvailable ? categoryLabel : '$categoryLabel • Indisponible';
  }

  String resolveLocationLine(Map<String, dynamic> resolvedProduct) {
    final seller = resolveSeller(resolvedProduct);
    final candidates = <Object?>[
      resolvedProduct['locationLabel'],
      resolvedProduct['city'],
      resolvedProduct['postalCode'],
      resolvedProduct['zipCode'],
      seller['locationLabel'],
      seller['city'],
      seller['postalCode'],
      seller['zipCode'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }

  bool resolveSellerCertified(Map<String, dynamic> resolvedProduct) {
    final seller = resolveSeller(resolvedProduct);
    final candidates = <Object?>[
      seller['isSellerCertified'],
      seller['isCertified'],
      seller['isVerified'],
      resolvedProduct['isSellerCertified'],
      resolvedProduct['sellerCertified'],
    ];

    for (final candidate in candidates) {
      if (candidate is bool) {
        if (candidate) {
          return true;
        }
        continue;
      }

      final normalized = candidate?.toString().trim().toLowerCase() ?? '';
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
    }

    return false;
  }

  String resolvePriceMeta(
    String categoryLabel,
    int likesCount,
    int commentsCount,
    bool isAvailable,
  ) {
    if (categoryLabel.trim().isNotEmpty && categoryLabel != 'Produit') {
      return categoryLabel;
    }
    if (likesCount + commentsCount > 0) {
      return '${formatMetricCount(likesCount + commentsCount)} inter.';
    }
    return isAvailable ? 'Disponible' : 'Indisponible';
  }

  String resolvePublicationTimeLabel(Map<String, dynamic> resolvedProduct) {
    final rawCreatedAt = resolvedProduct['createdAt'];
    if (rawCreatedAt is! String || rawCreatedAt.trim().isEmpty) {
      return '';
    }

    final createdAt = DateTime.tryParse(rawCreatedAt.trim())?.toLocal();
    if (createdAt == null) {
      return '';
    }

    final difference = DateTime.now().difference(createdAt);
    if (difference.isNegative) {
      return '';
    }

    if (difference.inMinutes < 1) {
      return 'Il y a quelques secondes';
    }
    if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} min';
    }
    if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours} h';
    }
    if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} j';
    }
    if (difference.inDays < 30) {
      return 'Il y a ${(difference.inDays / 7).floor()} sem';
    }
    if (difference.inDays < 365) {
      return 'Il y a ${(difference.inDays / 30).floor()} mois';
    }
    return 'Il y a ${(difference.inDays / 365).floor()} an${(difference.inDays / 365).floor() > 1 ? 's' : ''}';
  }

  String resolveProductId(Map<String, dynamic> resolvedProduct) {
    return resolvedProduct['id']?.toString().trim() ?? '';
  }

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  final CatalogApiService _catalogApiService = CatalogApiService();

  bool _isLiked = false;
  bool _isLikeBusy = false;
  bool _isShareBusy = false;
  int? _likeCountOverride;
  int? _shareCountOverride;

  @override
  void initState() {
    super.initState();
    _loadLikeState();
  }

  @override
  void didUpdateWidget(covariant ProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldId = oldWidget.resolveProductId(oldWidget.product);
    final newId = widget.resolveProductId(widget.product);
    if (oldId != newId) {
      _isLiked = false;
      _isLikeBusy = false;
      _isShareBusy = false;
      _likeCountOverride = null;
      _shareCountOverride = null;
      _loadLikeState();
    }
  }

  Future<void> _loadLikeState() async {
    final productId = widget.resolveProductId(widget.product);
    if (productId.isEmpty) {
      return;
    }

    try {
      final isLiked = await _catalogApiService.hasLikedProduct(productId);
      if (!mounted) {
        return;
      }
      setState(() => _isLiked = isLiked);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLiked = false);
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> resolvedProduct) async {
    final productId = widget.resolveProductId(resolvedProduct);
    if (productId.isEmpty || _isLikeBusy) {
      return;
    }

    final baseLikeCount = _effectiveLikesCount(resolvedProduct);
    final nextLiked = !_isLiked;
    final optimisticCount = nextLiked
        ? baseLikeCount + 1
        : (baseLikeCount > 0 ? baseLikeCount - 1 : 0);

    setState(() {
      _isLikeBusy = true;
      _isLiked = nextLiked;
      _likeCountOverride = optimisticCount;
    });

    try {
      final updatedProduct = nextLiked
          ? await _catalogApiService.likeProduct(productId)
          : await _catalogApiService.unlikeProduct(productId);
      if (!mounted) {
        return;
      }
      setState(() {
        _isLikeBusy = false;
        _likeCountOverride = widget.resolveMetricCount(updatedProduct, [
          'likesCount',
          'likeCount',
        ]);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLikeBusy = false;
        _isLiked = !nextLiked;
        _likeCountOverride = baseLikeCount;
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Impossible de mettre a jour le like.')),
      );
    }
  }

  Future<void> _openComments(Map<String, dynamic> resolvedProduct) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(
          product: resolvedProduct,
          initialAction: ProductDetailInitialAction.comments,
          initialLikeCount: _effectiveLikesCount(resolvedProduct),
          initialCommentCount: _effectiveCommentsCount(resolvedProduct),
        ),
      ),
    );
  }

  Future<void> _shareProduct(Map<String, dynamic> resolvedProduct) async {
    final productId = widget.resolveProductId(resolvedProduct);
    final shareContent = _buildShareMessage(resolvedProduct);
    final productSnapshot = _buildShareProductSnapshot(resolvedProduct);
    if (_isShareBusy) {
      return;
    }

    final sharedCount = await showAppShareSheet(
      context,
      messageContent: shareContent,
      productSnapshot: productSnapshot,
      selectionHint: 'Cochez pour partager ce produit',
      successLabel: 'Produit',
    );

    if (productId.isEmpty || sharedCount <= 0) {
      return;
    }

    setState(() => _isShareBusy = true);
    try {
      Map<String, dynamic>? updatedProduct;
      for (var index = 0; index < sharedCount; index++) {
        updatedProduct = await _catalogApiService.shareProduct(productId);
      }

      if (!mounted || updatedProduct == null) {
        return;
      }

      setState(() {
        _shareCountOverride = widget.resolveMetricCount(updatedProduct!, [
          'sharesCount',
          'shareCount',
        ]);
      });
    } on AppApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _isShareBusy = false);
      }
    }
  }

  int _effectiveLikesCount(Map<String, dynamic> resolvedProduct) {
    return _likeCountOverride ??
        widget.resolveMetricCount(resolvedProduct, ['likesCount', 'likeCount']);
  }

  int _effectiveCommentsCount(Map<String, dynamic> resolvedProduct) {
    return widget.resolveMetricCount(resolvedProduct, [
      'commentsCount',
      'commentCount',
    ]);
  }

  int _effectiveSharesCount(Map<String, dynamic> resolvedProduct) {
    return _shareCountOverride ??
        widget.resolveMetricCount(resolvedProduct, [
          'sharesCount',
          'shareCount',
        ]);
  }

  String _buildShareMessage(Map<String, dynamic> resolvedProduct) {
    final title = widget.resolvePrimaryLine(
      resolvedProduct,
      widget.resolveCategoryLabel(resolvedProduct),
      widget.resolveAvailability(resolvedProduct),
    );
    final price = (resolvedProduct['price'] as num?)?.toDouble();
    final priceLabel = price == null ? '' : formatPriceAmount(price);

    final parts = <String>['Je te partage ce produit.'];
    if (title.trim().isNotEmpty) {
      parts.add(title.trim());
    }
    if (priceLabel.trim().isNotEmpty) {
      parts.add(priceLabel.trim());
    }

    return parts.join('\n');
  }

  Map<String, dynamic> _buildShareProductSnapshot(
    Map<String, dynamic> resolvedProduct,
  ) {
    final images = widget.resolveProductImages(resolvedProduct);
    final price = (resolvedProduct['price'] as num?)?.toDouble();

    return {
      'productId': widget.resolveProductId(resolvedProduct),
      'productTitle': widget.resolvePrimaryLine(
        resolvedProduct,
        widget.resolveCategoryLabel(resolvedProduct),
        widget.resolveAvailability(resolvedProduct),
      ),
      'productSubtitle': widget.resolvePriceMeta(
        widget.resolveCategoryLabel(resolvedProduct),
        _effectiveLikesCount(resolvedProduct),
        _effectiveCommentsCount(resolvedProduct),
        widget.resolveAvailability(resolvedProduct),
      ),
      'productPriceLabel': price == null ? '' : formatPriceAmount(price),
      'productImageUrl': images.isNotEmpty ? images.first : '',
    };
  }

  void _openProduct(
    Map<String, dynamic> resolvedProduct, {
    int imageIndex = 0,
  }) {
    if (widget.onTap != null) {
      widget.onTap!(imageIndex);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => widget.buildDetailPage(resolvedProduct),
      ),
    );
  }

  Future<void> _openSellerProfile(Map<String, dynamic> resolvedProduct) async {
    final seller = widget.resolveSeller(resolvedProduct);
    final sellerProfileId = seller['id']?.toString().trim() ?? '';
    final sellerUserId = widget.resolveSellerUserId(resolvedProduct);
    final sellerName = widget.resolveSellerName(resolvedProduct);
    final sellerAvatarUrl = widget.resolveSellerAvatarUrl(resolvedProduct);
    final sellerSubtitle = widget.resolveCategoryLabel(resolvedProduct);

    if (sellerProfileId.isEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SellerProfilePage(
            profile: buildProfileFromUser(
              userId: sellerUserId.isEmpty ? null : sellerUserId,
              name: sellerName,
              avatarUrl: sellerAvatarUrl,
              subtitle: sellerSubtitle,
            ),
          ),
        ),
      );
      return;
    }

    try {
      final sellerProfile = await _catalogApiService.fetchSellerProfile(
        sellerProfileId,
      );
      if (!mounted) {
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SellerProfilePage(
            profile: buildSellerProfileFromApi(sellerProfile),
          ),
        ),
      );
    } on AppApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    ProductRealtimeSyncService.instance.ensureInitialized();

    return ValueListenableBuilder<int>(
      valueListenable: ProductRealtimeSyncService.instance.changes,
      builder: (context, value, child) {
        final resolvedProduct = ProductRealtimeSyncService.instance
            .mergeIntoProduct(widget.product);
        final theme = Theme.of(context);
        final appColors = theme.appColors;
        const surfaceColor = Color(0xFF101112);
        final priceColor = Colors.white;
        final screenHeight = MediaQuery.sizeOf(context).height;
        final screenWidth = MediaQuery.sizeOf(context).width;
        final mutedColor = Colors.white.withValues(alpha: 0.84);
        const accentGreen = Color(0xFF159A52);
        const unavailableAccent = Color(0xFFD84343);
        final favoriteColor = appColors.favoriteAccent;
        final descriptionFontSize = screenWidth < 360 ? 10.5 : 11.0;
        final publicationFontSize = screenWidth < 360 ? 10.5 : 11.0;
        final metricFontSize = screenWidth < 360 ? 11.0 : 12.0;
        final galleryHeight = screenHeight * 0.55;
        final price = (resolvedProduct['price'] as num?)?.toDouble() ?? 0.0;
        final currency = resolveProductCurrency(resolvedProduct);
        final categoryLabel = widget.resolveCategoryLabel(resolvedProduct);
        final sellerName = widget.resolveSellerName(resolvedProduct);
        final sellerAvatarUrl = widget.resolveSellerAvatarUrl(resolvedProduct);
        final sellerUserId = widget.resolveSellerUserId(resolvedProduct);
        final isSellerCertified = widget.resolveSellerCertified(
          resolvedProduct,
        );
        final isMarketplace = widget.variant == ProductCardVariant.marketplace;
        final isAvailable = widget.resolveAvailability(resolvedProduct);
        final likesCount = _effectiveLikesCount(resolvedProduct);
        final commentsCount = _effectiveCommentsCount(resolvedProduct);
        final imageCount = widget.resolveProductImages(resolvedProduct).length;
        final primaryLine = widget.resolvePrimaryLine(
          resolvedProduct,
          categoryLabel,
          isAvailable,
        );
        final publicationTimeLabel = widget.resolvePublicationTimeLabel(
          resolvedProduct,
        );
        final locationLine = widget.resolveLocationLine(resolvedProduct);
        final badgeLabel = widget.resolveBadgeLabel(
          resolvedProduct,
          isMarketplace,
        );
        return GestureDetector(
          onTap: () => _openProduct(resolvedProduct),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: surfaceColor,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  color: Colors.black.withValues(alpha: 0.82),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _openSellerProfile(resolvedProduct),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                _buildSellerAvatar(
                                  sellerAvatarUrl,
                                  sellerUserId: sellerUserId,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        sellerName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              color: accentGreen,
                                              fontWeight: FontWeight.w900,
                                              height: 1.1,
                                            ),
                                      ),
                                      if (publicationTimeLabel.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          publicationTimeLabel,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: mutedColor,
                                                fontSize: publicationFontSize,
                                                fontWeight: FontWeight.w600,
                                                height: 1.1,
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatPriceAmount(price),
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: priceColor,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              currency,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: priceColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            margin: const EdgeInsets.only(bottom: 2),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color:
                                    (isAvailable
                                            ? accentGreen
                                            : unavailableAccent)
                                        .withValues(alpha: 0.7),
                              ),
                              color: isAvailable
                                  ? Colors.transparent
                                  : unavailableAccent.withValues(alpha: 0.14),
                            ),
                            child: Text(
                              categoryLabel.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isAvailable
                                    ? accentGreen
                                    : unavailableAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!isAvailable) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: unavailableAccent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: unavailableAccent.withValues(alpha: 0.46),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.visibility_off_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Produit actuellement indisponible',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        primaryLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: mutedColor,
                          fontSize: descriptionFontSize,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                      if (locationLine.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          locationLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: mutedColor,
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _buildImageHero(
                  resolvedProduct,
                  badgeLabel: badgeLabel,
                  isAvailable: isAvailable,
                  isSellerCertified: isSellerCertified,
                  imageCount: imageCount,
                  isMarketplace: isMarketplace,
                  height: galleryHeight,
                ),
                Container(
                  color: Colors.black.withValues(alpha: 0.82),
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildActionMetric(
                            icon: _isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            label: widget.formatMetricCount(likesCount),
                            iconColor: _isLiked ? favoriteColor : Colors.white,
                            labelColor: Colors.white,
                            fontSize: metricFontSize,
                            onTap: _isLikeBusy
                                ? null
                                : () => _toggleLike(resolvedProduct),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildActionMetric(
                            icon: Icons.mode_comment_rounded,
                            label: widget.formatMetricCount(commentsCount),
                            iconColor: Colors.white,
                            labelColor: Colors.white,
                            fontSize: metricFontSize,
                            onTap: () => _openComments(resolvedProduct),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _buildActionMetric(
                          icon: Icons.share_outlined,
                          label: widget.formatMetricCount(
                            _effectiveSharesCount(resolvedProduct),
                          ),
                          iconColor: Colors.white,
                          labelColor: Colors.white,
                          fontSize: metricFontSize,
                          onTap: () => _shareProduct(resolvedProduct),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageHero(
    Map<String, dynamic> resolvedProduct, {
    required String badgeLabel,
    required bool isAvailable,
    required bool isSellerCertified,
    required int imageCount,
    required bool isMarketplace,
    required double height,
  }) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final isFeaturedBadge = badgeLabel.trim().toLowerCase() == 'a la une';
    final images = widget.resolveProductImages(resolvedProduct);
    final previewImages = images.skip(1).take(3).toList(growable: false);
    final badgeColor = isFeaturedBadge
        ? Colors.red
        : isMarketplace
        ? const Color(0xFF8F42FF)
        : theme.colorScheme.primary;
    final showGalleryStrip = previewImages.isNotEmpty;
    final mainImageHeight = showGalleryStrip ? height - 104 : height;

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mainImageWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;

          return Column(
            children: [
              SizedBox(
                height: mainImageHeight,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (images.isEmpty)
                      _missingImageItem(
                        onTap: () => _openProduct(resolvedProduct),
                      )
                    else
                      _imageItem(
                        images.first,
                        onTap: () => _openProduct(resolvedProduct),
                        width: mainImageWidth,
                        height: mainImageHeight,
                        preferThumbnail: false,
                      ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            !isAvailable
                                ? Colors.black.withValues(alpha: 0.22)
                                : Colors.transparent,
                            !isAvailable
                                ? const Color(
                                    0xFFD84343,
                                  ).withValues(alpha: 0.12)
                                : Colors.transparent,
                            appColors.scrimSoft.withValues(alpha: 0.18),
                          ],
                        ),
                      ),
                    ),
                    if (!isAvailable)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFD84343,
                            ).withValues(alpha: 0.76),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.visibility_off_rounded,
                                color: Colors.white,
                                size: 34,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Produit indisponible',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: badgeColor.withValues(alpha: 0.22),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Text(
                          badgeLabel,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    if (widget.topRightOverlay != null)
                      Positioned(
                        right: 12,
                        top: 12,
                        child: widget.topRightOverlay!,
                      )
                    else if (isSellerCertified)
                      const Positioned(
                        right: 12,
                        top: 12,
                        child: SellerCertifiedMiniBadge(),
                      ),
                  ],
                ),
              ),
              if (showGalleryStrip) ...[
                const SizedBox(height: 2),
                SizedBox(
                  height: 102,
                  width: double.infinity,
                  child: _buildSubImageStrip(
                    images,
                    resolvedProduct: resolvedProduct,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSubImageStrip(
    List<String> images, {
    required Map<String, dynamic> resolvedProduct,
  }) {
    final previewImages = images.skip(1).take(3).toList(growable: false);
    final extraCount = images.length - 1 - previewImages.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final previewWidth = constraints.maxWidth.isFinite
            ? (constraints.maxWidth - ((previewImages.length - 1) * 2)) /
                  previewImages.length
            : 120.0;
        final previewHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 96.0;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(previewImages.length, (index) {
            final imageIndex = index + 1;
            final isLastVisible = index == previewImages.length - 1;
            final showExtraCount = extraCount > 0 && isLastVisible;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: index == 0 ? 0 : 2),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () =>
                        _openProduct(resolvedProduct, imageIndex: imageIndex),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _imageItem(
                          previewImages[index],
                          width: previewWidth,
                          height: previewHeight,
                          preferThumbnail: true,
                        ),
                        if (showExtraCount)
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                            ),
                            child: Center(
                              child: Text(
                                '+$extraCount',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildActionMetric({
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color labelColor,
    required VoidCallback? onTap,
    Color? backgroundColor,
    double? fontSize,
  }) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(999);
    final buttonBackground =
        backgroundColor ?? const Color.fromARGB(255, 38, 38, 38);
    final buttonBorder = const Color.fromARGB(255, 68, 68, 68);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: buttonBackground,
        borderRadius: borderRadius,
        border: Border.all(color: buttonBorder.withValues(alpha: 0.82)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: labelColor,
                    fontSize: (fontSize ?? 12) + 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSellerAvatar(String avatarUrl, {required String sellerUserId}) {
    return AppCircleNetworkAvatar(
      imageUrl: avatarUrl,
      radius: 24,
      userId: sellerUserId.isEmpty ? null : sellerUserId,
      showPresenceBadge: false,
    );
  }

  Widget _missingImageItem({VoidCallback? onTap}) {
    final appColors = Theme.of(context).appColors;

    return GestureDetector(
      onTap: onTap,
      child: AppImagePlaceholder(
        width: double.infinity,
        height: double.infinity,
        borderRadius: BorderRadius.zero,
        child: Center(
          child: Icon(
            Icons.image_not_supported,
            color: appColors.placeholderIcon,
            size: 34,
          ),
        ),
      ),
    );
  }

  String _optimizedProductCardImageUrl(
    String url, {
    required bool preferThumbnail,
  }) {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) {
      return normalizedUrl;
    }

    return preferThumbnail
        ? CloudinaryImageUrl.forProductCardThumbnail(normalizedUrl)
        : CloudinaryImageUrl.forProductCardMain(normalizedUrl);
  }

  Widget _imageItem(
    String url, {
    VoidCallback? onTap,
    double? width,
    double? height,
    bool preferThumbnail = false,
  }) {
    final theme = Theme.of(context);
    final fallbackIconColor =
        theme.iconTheme.color ?? theme.colorScheme.onSurfaceVariant;
    final isLocalFile =
        !(url.startsWith('http://') || url.startsWith('https://'));
    final optimizedUrl = _optimizedProductCardImageUrl(
      url,
      preferThumbnail: preferThumbnail,
    );

    return GestureDetector(
      onTap: onTap,
      child: isLocalFile
          ? Image.file(
              File(url),
              fit: BoxFit.cover,
              width: width ?? double.infinity,
              height: height ?? double.infinity,
              cacheWidth: width?.round(),
              cacheHeight: height?.round(),
              errorBuilder: (_, _, _) =>
                  Icon(Icons.image_not_supported, color: fallbackIconColor),
            )
          : AppNetworkImage(
              imageUrl: optimizedUrl,
              fit: BoxFit.cover,
              width: width ?? double.infinity,
              height: height ?? double.infinity,
              borderRadius: BorderRadius.zero,
              errorChild: Icon(
                Icons.image_not_supported,
                color: fallbackIconColor,
              ),
            ),
    );
  }
}
