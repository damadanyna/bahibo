import 'package:bahibo/component/theme_menu_button.dart';
import 'package:bahibo/component/app_comments_sheet.dart';
import 'package:bahibo/component/profile_models.dart';
import 'package:bahibo/component/seller_profile_page.dart';
import 'package:bahibo/component/app_page_skeletons.dart';
import 'package:bahibo/component/app_page_refresh.dart';
import 'package:bahibo/component/app_text_input.dart';
import 'package:flutter/material.dart';
import 'package:bahibo/component/app_network_image.dart';
import 'package:bahibo/page/image_viewer_page.dart';
import 'package:bahibo/page/seller_chat_page.dart';

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
  int _currentPage = 0;
  bool _showEntrySkeleton = true;
  int _commentBaseCount = 64;
  int _commentAddedCount = 0;
  final List<dynamic> _comments = [
    const AppCommentData(
      authorName: 'Miora Andrianiaina',
      avatarUrl:
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=600',
      timeLabel: 'il y a 5 min',
      message: 'Très beau produit, il est toujours disponible ?',
    ),
    const AppCommentData(
      authorName: 'Aina Ravelona',
      avatarUrl:
          'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=600',
      timeLabel: 'il y a 19 min',
      message: 'La finition a l’air propre, j’aime beaucoup.',
    ),
    const AppCommentData(
      authorName: 'Toky Rajaonarison',
      avatarUrl:
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=600',
      timeLabel: 'il y a 1 h',
      message: 'Possible d’avoir plus de détails sur la livraison ?',
    ),
  ];

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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
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
                      // ── AppBar transparente qui disparaît au scroll ──
                      SliverAppBar(
                        expandedHeight: 0,
                        floating: true,
                        pinned: true,
                        backgroundColor:
                            theme.appBarTheme.backgroundColor ??
                            theme.primaryColor,
                        foregroundColor:
                            theme.appBarTheme.foregroundColor ??
                            (isDark ? Colors.white : Colors.black),
                        elevation: 0,
                        title: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color:
                                theme.appBarTheme.foregroundColor ??
                                (isDark ? Colors.white : Colors.black),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        actions: [
                          IconButton(
                            icon: Icon(
                              Icons.search,
                              color:
                                  theme.iconTheme.color ??
                                  (isDark ? Colors.white : Colors.black),
                            ),
                            onPressed: () {},
                          ),
                          const ThemeMenuButton(),
                        ],
                      ),

                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                    iconColor: const Color(0xFFFF4D6D),
                                  ),
                                  _socialActionCard(
                                    icon: Icons.chat_bubble,
                                    label:
                                        (_commentBaseCount + _commentAddedCount)
                                            .toString(),
                                    iconColor: Colors.white,
                                    onTap: _showProductCommentsSheet,
                                  ),
                                  _socialActionCard(
                                    icon: Icons.reply_rounded,
                                    label: 'Partager',
                                    iconColor: Colors.white,
                                  ),
                                ],
                              ),
                            ),

                            // ── Carte principale ──
                            Container(
                              margin: const EdgeInsets.all(12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark
                                        ? Colors.black.withOpacity(0.3)
                                        : Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
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
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      widget.product['category'] ?? 'Produit',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Titre
                                  Text(
                                    title,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Prix
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '$priceFormatted',
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Padding(
                                        padding: EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          'MGA',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green,
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
                                        color: isDark
                                            ? Colors.grey.shade200
                                            : Colors.grey.shade500,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Publié il y a plus d\'une semaine · Antananarivo',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.grey.shade300
                                              : Colors.grey.shade500,
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
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark
                                        ? Colors.black.withOpacity(0.3)
                                        : Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Détails du Produit',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
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
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark
                                          ? Colors.black.withOpacity(0.3)
                                          : Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
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
                                                            const SellerChatPage(),
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
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
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
                                          const Text(
                                            _sellerName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
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
                                                  color: Colors.green
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Row(
                                                  children: const [
                                                    Icon(
                                                      Icons.verified,
                                                      size: 12,
                                                      color: Colors.green,
                                                    ),
                                                    SizedBox(width: 3),
                                                    Text(
                                                      'Vendeur Vérifié',
                                                      style: TextStyle(
                                                        color: Colors.green,
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
                                        foregroundColor: Colors.green,
                                        side: const BorderSide(
                                          color: Colors.green,
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
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark
                                        ? Colors.black.withOpacity(0.3)
                                        : Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Description',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.product['description'] ??
                                        'Aucune description disponible.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
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

      // ── Bouton fixe en bas ──
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        decoration: BoxDecoration(
          color: theme.bottomAppBarTheme.color ?? theme.cardColor,
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.5)
                  : Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: AppInputContainer(
                borderRadius: BorderRadius.circular(14),
                child: TextField(
                  controller: _availabilityController,
                  textInputAction: TextInputAction.send,
                  decoration: appInputDecoration(
                    context,
                    hintText: 'Cet article est-il disponible ?',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 10,
                    ),
                  ),
                  style: appInputTextStyle(context),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  final message = _availabilityController.text.trim();
                  if (message.isEmpty) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message envoye')),
                  );
                  _availabilityController.clear();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: const Icon(Icons.rocket_launch, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid(List<String> images) {
    if (images.isEmpty) return const SizedBox.shrink();

    if (images.length == 1) {
      return SizedBox(
        height: 300,
        width: double.infinity,
        child: _imageItem(
          images.first,
          onTap: () => _openProductGallery(images, 0),
        ),
      );
    }

    if (images.length == 2) {
      final [first, second] = images;
      return SizedBox(
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
    }

    final String first = images.first;
    final List<String> rest = images.skip(1).take(3).toList();
    final int extra = images.length - 4;

    return Column(
      children: [
        SizedBox(
          height: 220,
          width: double.infinity,
          child: _imageItem(first, onTap: () => _openProductGallery(images, 0)),
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
                              color: Colors.black54,
                              child: Center(
                                child: Text(
                                  '+$extra',
                                  style: const TextStyle(
                                    color: Colors.white,
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
              MaterialPageRoute(builder: (_) => const SellerChatPage()),
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

  void _showProductCommentsSheet() {
    showAppCommentsSheet(
      context,
      comments: _comments,
      totalCount: _commentBaseCount + _commentAddedCount,
      onAuthorTap: _openCommentAuthorProfile,
      onCountChanged: (nextCount) {
        if (!mounted) return;
        setState(() {
          _commentAddedCount = nextCount - _commentBaseCount;
        });
      },
    );
  }

  void _openCommentAuthorProfile(AppCommentData comment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SellerProfilePage(
          profile: buildProfileFromUser(
            name: comment.authorName,
            avatarUrl: comment.avatarUrl,
            subtitle: 'Membre de la communaute Bahibo',
          ),
        ),
      ),
    );
  }

  Widget _imageItem(String url, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AppNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorChild: const Icon(
          Icons.image_not_supported,
          color: Colors.grey,
          size: 50,
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.green, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
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
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          width: 88,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF121212) : const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
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
