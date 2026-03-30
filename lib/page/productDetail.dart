import 'package:bahibo/component/app_comments_sheet.dart';
import 'package:bahibo/component/profile_models.dart';
import 'package:bahibo/component/seller_profile_page.dart';
import 'package:bahibo/component/app_share_sheet.dart';
import 'package:bahibo/component/app_page_skeletons.dart';
import 'package:bahibo/component/app_page_refresh.dart';
import 'package:bahibo/component/app_back_button.dart';
import 'package:bahibo/component/ui/chat_message_input_not_plus.dart';
import 'package:flutter/material.dart';
import 'package:bahibo/component/app_network_image.dart';
import 'package:bahibo/page/chat_page.dart';
import 'package:bahibo/page/image_viewer_page.dart';
import 'package:bahibo/theme/app_theme_extensions.dart';

class ProductDetailPage extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage>
    with AppPageRefreshMixin<ProductDetailPage> {
  static const String _sellerName = 'John Doe';
  static const String _sellerBadge = 'En ligne';
  static const String _sellerImageUrl =
      'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=600';

  late PageController _pageController;
  final TextEditingController _availabilityController = TextEditingController();
  int _commentCount = 64;
  bool _showEntrySkeleton = true;
  final List<AppCommentItem> _comments = defaultAppComments();

  @override
  void initState() {
    super.initState();
    initializePageRefresh();
    _pageController = PageController();
    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      setState(() => _showEntrySkeleton = false);
    });
  }

  @override
  void dispose() {
    disposePageRefresh();
    _availabilityController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Future<void> onPageReload() async {
    if (mounted) {
      setState(() => _showEntrySkeleton = true);
    }
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() => _showEntrySkeleton = false);
  }

  @override
  Widget build(BuildContext context) {
    final List<String> images =
        (widget.product['images'] as List?)?.whereType<String>().toList() ??
        [widget.product['thumbnail'] ?? 'https://via.placeholder.com/150'];

    final String title = widget.product['title'] ?? 'Produit';
    final double price = (widget.product['price'] as num?)?.toDouble() ?? 0.0;
    final String priceFormatted = (price * 400)
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
        );

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appColors = theme.appColors;
    final pageBackgroundColor = appColors.backgroundBase;
    final topBarColor = appColors.panelMuted;
    final topBarForegroundColor = isDark
        ? (theme.appBarTheme.foregroundColor ?? appColors.heroForeground)
        : theme.colorScheme.onSurface;
    final bottomBarColor = isDark ? theme.scaffoldBackgroundColor : topBarColor;
    final detailCardColor = theme.cardColor;
    final detailPrimaryTextColor =
        theme.textTheme.bodyLarge?.color ?? theme.colorScheme.onSurface;
    final detailSecondaryTextColor =
        theme.textTheme.bodyMedium?.color ?? theme.colorScheme.onSurfaceVariant;
    final actionIconColor =
        theme.iconTheme.color ??
        (isDark ? appColors.heroForeground : theme.colorScheme.onSurface);

    return Scaffold(
      backgroundColor: pageBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: refreshPageWithDialog,
              child: _showEntrySkeleton
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [ProductDetailSkeleton()],
                    )
                  : CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  5,
                                  16,
                                  7,
                                ),
                                child: Text(
                                  'Abaoly',
                                  style: TextStyle(
                                    fontSize: 25,
                                    fontWeight: FontWeight.w900,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              // ── Grille d'images ──
                              _buildImageGrid(images),

                              // ── Actions ──
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _socialActionCard(
                                      icon: Icons.favorite,
                                      label: '6 374',
                                      iconColor: appColors.favoriteAccent,
                                    ),
                                    _socialActionCard(
                                      icon: Icons.chat,
                                      label: _commentCount.toString(),
                                      iconColor: actionIconColor,
                                      onTap: _showCommentsSheet,
                                    ),
                                    _socialActionCard(
                                      icon: Icons.reply_rounded,
                                      label: 'Partager',
                                      iconColor: actionIconColor,
                                      onTap: _showShareSuggestions,
                                    ),
                                  ],
                                ),
                              ),

                              // ── Carte principale ──
                              Container(
                                margin: const EdgeInsets.all(12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: detailCardColor,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Badge catégorie
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        widget.product['category'] ?? 'Produit',
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Titre
                                    Text(
                                      title,
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: detailPrimaryTextColor,
                                          ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Prix
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '$priceFormatted',
                                          style: TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 4,
                                          ),
                                          child: Text(
                                            'MGA',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),

                                    // Date publication
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 13,
                                          color: detailSecondaryTextColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Publié il y a plus d\'une semaine · Antananarivo',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: detailSecondaryTextColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // ── Carte détails produit ──
                              Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: detailCardColor,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Détails du Produit',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: detailPrimaryTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _detailRow(
                                      Icons.star_outline,
                                      'État',
                                      'Comme Neuf',
                                    ),
                                    _detailRow(
                                      Icons.verified_outlined,
                                      'Garantie',
                                      '3 Mois',
                                    ),
                                    _detailRow(
                                      Icons.check_circle_outline,
                                      'Contrôle',
                                      'Testé et Vérifié',
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

                              // ── Carte vendeur ──
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SellerProfilePage(
                                        profile: defaultSellerProfileData(),
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: detailCardColor,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      Stack(
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => ImageViewerPage(
                                                    imageUrls: const [
                                                      _sellerImageUrl,
                                                    ],
                                                    initialIndex: 0,
                                                    heroTag:
                                                        'seller-avatar-detail',
                                                    onSellerTap: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              SellerProfilePage(
                                                                profile:
                                                                    defaultSellerProfileData(),
                                                              ),
                                                        ),
                                                      );
                                                    },
                                                    onSellerMessageTap: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              const ChatPage(),
                                                        ),
                                                      );
                                                    },
                                                    overlay: ImageViewerOverlayData(
                                                      title: 'Profil vendeur',
                                                      description:
                                                          'Vendeur actif sur Bahibo, disponible pour des photos et details supplementaires.',
                                                      sellerName: _sellerName,
                                                      sellerAvatarUrl:
                                                          _sellerImageUrl,
                                                      sellerBadge: _sellerBadge,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Hero(
                                              tag: 'seller-avatar-detail',
                                              child: AppCircleNetworkAvatar(
                                                radius: 28,
                                                imageUrl: _sellerImageUrl,
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 0,
                                            right: 0,
                                            child: Container(
                                              width: 14,
                                              height: 14,
                                              decoration: BoxDecoration(
                                                color: appColors.success,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: detailCardColor,
                                                  width: 2,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _sellerName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: detailPrimaryTextColor,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: theme
                                                        .colorScheme
                                                        .primary
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.verified,
                                                        size: 12,
                                                        color: theme
                                                            .colorScheme
                                                            .primary,
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        'Vendeur Vérifié',
                                                        style: TextStyle(
                                                          color: theme
                                                              .colorScheme
                                                              .primary,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Bouton voir profil
                                      OutlinedButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => SellerProfilePage(
                                                profile:
                                                    defaultSellerProfileData(),
                                              ),
                                            ),
                                          );
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              theme.colorScheme.primary,
                                          side: BorderSide(
                                            color: theme.colorScheme.primary,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                        child: const Text(
                                          'Profil',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // ── Description ──
                              Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: detailCardColor,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Description',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: detailPrimaryTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      widget.product['description'] ??
                                          'Aucune description disponible.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: detailSecondaryTextColor,
                                        height: 1.6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

                              const SizedBox(
                                height: 100,
                              ), // espace pour le bouton fixe
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            if (isOffline) const AppOfflineBanner(bottomOffset: 20),
          ],
        ),
      ),

      // ── Bouton fixe en bas ──
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        decoration: BoxDecoration(color: bottomBarColor),
        child: UiChatMessageInput(
          controller: _availabilityController,
          primary: theme.colorScheme.primary,
          panelColor: theme.brightness == Brightness.dark
              ? theme.scaffoldBackgroundColor
              : theme.cardColor,
          hintText: 'Cet article est-il disponible ?',
          onSend: (text) {
            if (text.trim().isEmpty) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Message envoye')));
          },
        ),
      ),
    );
  }

  Widget _buildImageGrid(List<String> images) {
    final appColors = Theme.of(context).appColors;

    if (images.isEmpty) return const SizedBox.shrink();

    late final Widget galleryContent;

    if (images.length == 1) {
      galleryContent = SizedBox(
        height: 300,
        width: double.infinity,
        child: _imageItem(
          images.first,
          onTap: () => _openProductGallery(images, 0),
        ),
      );
    } else if (images.length == 2) {
      final [first, second] = images;
      galleryContent = SizedBox(
        height: 300,
        child: Row(
          children: [
            Expanded(
              child: _imageItem(
                first,
                onTap: () => _openProductGallery(images, 0),
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: _imageItem(
                second,
                onTap: () => _openProductGallery(images, 1),
              ),
            ),
          ],
        ),
      );
    } else {
      final String first = images.first;
      final List<String> rest = images.skip(1).take(3).toList();
      final int extra = images.length - 4;

      galleryContent = Column(
        children: [
          SizedBox(
            height: 220,
            width: double.infinity,
            child: _imageItem(
              first,
              onTap: () => _openProductGallery(images, 0),
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 140,
            child: Row(
              children: List.generate(rest.length, (i) {
                final bool isLast = i == rest.length - 1 && extra > 0;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 2),
                    child: isLast
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              _imageItem(
                                rest[i],
                                onTap: () => _openProductGallery(images, i + 1),
                              ),
                              Container(
                                color: appColors.scrimSoft,
                                child: Center(
                                  child: Text(
                                    '+$extra',
                                    style: TextStyle(
                                      color: appColors.heroForeground,
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : _imageItem(
                            rest[i],
                            onTap: () => _openProductGallery(images, i + 1),
                          ),
                  ),
                );
              }),
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        galleryContent,
        const Positioned(top: 12, left: 12, child: AppBackButton()),
      ],
    );
  }

  void _openProductGallery(List<String> images, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageViewerPage(
          imageUrls: images,
          initialIndex: index,
          onSellerTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    SellerProfilePage(profile: defaultSellerProfileData()),
              ),
            );
          },
          onSellerMessageTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatPage()),
            );
          },
          overlay: ImageViewerOverlayData(
            title: widget.product['title'] as String? ?? 'Produit',
            description:
                widget.product['description'] as String? ??
                'Aucune description disponible.',
            sellerName: _sellerName,
            sellerAvatarUrl: _sellerImageUrl,
            sellerBadge: _sellerBadge,
          ),
        ),
      ),
    );
  }

  void _showShareSuggestions() {
    showAppShareSheet(context);
  }

  void _showCommentsSheet() {
    showAppCommentsSheet(
      context,
      currentCommentCount: _commentCount,
      comments: _comments,
      onCommentCountChanged: (value) {
        if (!mounted) return;
        setState(() => _commentCount = value);
      },
    );
  }

  Widget _imageItem(String url, {VoidCallback? onTap}) {
    final appColors = Theme.of(context).appColors;

    return GestureDetector(
      onTap: onTap,
      child: AppNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorChild: Icon(
          Icons.image_not_supported,
          color: appColors.placeholderIcon,
          size: 50,
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    final detailLabelColor =
        theme.textTheme.bodyMedium?.color ?? theme.colorScheme.onSurfaceVariant;
    final detailValueColor =
        theme.textTheme.bodyLarge?.color ?? theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 13, color: detailLabelColor)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: detailValueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _socialActionCard({
    required IconData icon,
    required String label,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final isDark = theme.brightness == Brightness.dark;
    final actionCardColor = isDark
        ? theme.scaffoldBackgroundColor
        : theme.colorScheme.surfaceContainer;
    final actionBorderColor = isDark
        ? appColors.heroBorder
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.55);
    final actionTextColor = isDark
        ? appColors.heroForeground
        : theme.colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          width: 88,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            color: actionCardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: actionBorderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: actionTextColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
