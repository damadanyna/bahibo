import 'package:bahibo/component/app_comments_sheet.dart';
import 'package:bahibo/component/app_likes_sheet.dart';
import 'package:bahibo/component/profile_models.dart';
import 'package:bahibo/component/seller_profile_page.dart';
import 'package:bahibo/component/app_share_sheet.dart';
import 'package:bahibo/component/app_page_skeletons.dart';
import 'package:bahibo/component/app_page_refresh.dart';
import 'package:bahibo/component/app_back_button.dart';
import 'package:bahibo/component/ui/chat_message_input_not_plus.dart';
import 'package:bahibo/component/ui/seller_certified_badge.dart';
import 'package:bahibo/formatter/price_formatter.dart';
import 'package:bahibo/services/app_api_client.dart';
import 'package:bahibo/services/app_auth_service.dart';
import 'package:bahibo/services/catalog_api_service.dart';
import 'package:flutter/material.dart';
import 'package:bahibo/component/app_network_image.dart';
import 'package:bahibo/page/chat_page.dart';
import 'package:bahibo/page/image_viewer_page.dart';
import 'package:bahibo/theme/app_theme_extensions.dart';

enum ProductDetailInitialAction { none, comments, likes }

class ProductDetailPage extends StatefulWidget {
  final Map<String, dynamic> product;
  final bool openedFromChat;
  final ProductDetailInitialAction initialAction;
  final List<AppLikeItem>? initialLikes;
  final List<AppCommentItem>? initialComments;
  final int? initialLikeCount;
  final int? initialCommentCount;

  const ProductDetailPage({
    super.key,
    required this.product,
    this.openedFromChat = false,
    this.initialAction = ProductDetailInitialAction.none,
    this.initialLikes,
    this.initialComments,
    this.initialLikeCount,
    this.initialCommentCount,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage>
    with AppPageRefreshMixin<ProductDetailPage> {
  static const String _defaultAvailabilityMessage =
      'Cet article est toujours disponible ?';
  static const String _defaultSellerAvatarUrl =
      'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=600';
  final AppAuthService _authService = AppAuthService();
  final CatalogApiService _catalogApiService = CatalogApiService();

  late PageController _pageController;
  late Map<String, dynamic> _productData;
  final TextEditingController _availabilityController = TextEditingController();
  late final List<AppLikeItem> _likes;
  int _likeCount = 0;
  int _commentCount = 0;
  int _shareCount = 0;
  bool _showEntrySkeleton = true;
  bool _isLiked = false;
  bool _isLikeSubmitting = false;
  bool _isShareSubmitting = false;
  bool _isSubscribed = false;
  bool _isSubscriptionSubmitting = false;
  late final List<AppCommentItem> _comments;
  bool _didOpenInitialAction = false;
  String? _currentViewerUserId;
  UserProfileData? _sellerProfileData;

  Map<String, dynamic> get product => _productData;

  Map<String, dynamic> get _sellerMap {
    final rawSeller = product['seller'];
    if (rawSeller is Map) {
      return Map<String, dynamic>.from(rawSeller);
    }
    return const <String, dynamic>{};
  }

  String get _sellerProfileIdValue {
    final rawId = _sellerMap['id'];
    if (rawId == null) {
      return '';
    }
    return rawId.toString().trim();
  }

  String get _sellerUserIdValue {
    final rawUserId = _sellerMap['userId'];
    if (rawUserId == null) {
      return '';
    }
    return rawUserId.toString().trim();
  }

  String get _sellerNameValue {
    final sellerName = _sellerMap['name'];
    if (sellerName is String && sellerName.trim().isNotEmpty) {
      return sellerName.trim();
    }

    return _resolveStringField(['sellerName', 'vendorName'], 'Vendeur Bahibo');
  }

  String get _sellerAvatarUrlValue {
    final sellerAvatarUrl = _sellerMap['avatarUrl'];
    if (sellerAvatarUrl is String && sellerAvatarUrl.trim().isNotEmpty) {
      return sellerAvatarUrl.trim();
    }

    return _resolveStringField([
      'sellerAvatarUrl',
      'sellerImageUrl',
      'avatarUrl',
    ], _defaultSellerAvatarUrl);
  }

  String get _sellerBadgeValue {
    final isSellerCertified = _sellerMap['isSellerCertified'] == true;
    if (isSellerCertified) {
      return 'Vendeur certifie';
    }
    return _resolveStringField(['sellerRole', 'sellerBadge'], 'Vendeur');
  }

  String get _resolvedSellerBadge {
    final sellerBadge = _sellerProfileData?.roleLabel.trim() ?? '';
    if (sellerBadge.isNotEmpty) {
      return sellerBadge;
    }
    return _sellerBadgeValue;
  }

  bool get _isOwnSeller {
    final currentViewerUserId = _currentViewerUserId?.trim() ?? '';
    final sellerUserId = _sellerUserIdValue;
    return currentViewerUserId.isNotEmpty &&
        sellerUserId.isNotEmpty &&
        currentViewerUserId == sellerUserId;
  }

  @override
  void initState() {
    super.initState();
    initializePageRefresh();
    _pageController = PageController();
    _productData = Map<String, dynamic>.from(widget.product);
    _likes = List<AppLikeItem>.from(widget.initialLikes ?? defaultAppLikes());
    _comments = List<AppCommentItem>.from(
      widget.initialComments ?? const <AppCommentItem>[],
    );
    _likeCount = widget.initialLikeCount ?? _resolveLikeCount(_productData);
    _commentCount =
        widget.initialCommentCount ??
        _resolveCount(_productData, 'commentsCount');
    _shareCount = _resolveCount(_productData, 'sharesCount');
    _isSubscribed =
        (_sellerMap['isFollowing'] as bool?) ??
        (widget.product['isFollowing'] as bool?) ??
        false;
    _loadLikeStatus();
    _loadSellerContext();
    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      setState(() => _showEntrySkeleton = false);
      _openInitialActionIfNeeded();
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
    final productId = product['id']?.toString().trim() ?? '';
    if (productId.isNotEmpty) {
      try {
        final refreshedProduct = await _catalogApiService.fetchProductById(
          productId,
        );
        if (mounted) {
          setState(() {
            _productData = Map<String, dynamic>.from(refreshedProduct);
            _likeCount = _resolveLikeCount(_productData);
            _commentCount = _resolveCount(_productData, 'commentsCount');
            _shareCount = _resolveCount(_productData, 'sharesCount');
          });
        }
        await _loadLikeStatus();
        await _refreshSellerProfileState();
      } on AppApiException {
        await Future.delayed(const Duration(milliseconds: 450));
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 450));
    }
    if (!mounted) return;
    setState(() => _showEntrySkeleton = false);
  }

  void _openInitialActionIfNeeded() {
    if (_didOpenInitialAction || !mounted) {
      return;
    }

    _didOpenInitialAction = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      switch (widget.initialAction) {
        case ProductDetailInitialAction.comments:
          _showCommentsSheet();
          break;
        case ProductDetailInitialAction.likes:
          _showLikesSheet();
          break;
        case ProductDetailInitialAction.none:
          break;
      }
    });
  }

  String _resolveStringField(List<String> keys, String fallback) {
    for (final key in keys) {
      final value = product[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return fallback;
  }

  String _buildProductPriceLabel() {
    final price = (product['price'] as num?)?.toDouble() ?? 0.0;
    final currency = resolveProductCurrency(product);
    return '${formatPriceAmount(price)} $currency';
  }

  String _buildProductSubtitle() {
    final category = _resolveStringField(['category'], 'Produit verifie');
    final status = _resolveStringField([
      'availability',
      'status',
      'sellerBadge',
    ], 'Disponible');
    return '$category • $status';
  }

  String _buildPublicationLabel() {
    final rawCreatedAt = product['createdAt'];
    if (rawCreatedAt is! String || rawCreatedAt.trim().isEmpty) {
      return 'Date de publication indisponible';
    }

    final createdAt = DateTime.tryParse(rawCreatedAt)?.toLocal();
    if (createdAt == null) {
      return 'Date de publication indisponible';
    }

    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'Publie il y a quelques secondes';
    }

    if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return 'Publie il y a $minutes min';
    }

    if (difference.inHours < 24) {
      final hours = difference.inHours;
      return 'Publie il y a $hours h';
    }

    if (difference.inDays < 7) {
      final days = difference.inDays;
      return 'Publie il y a $days j';
    }

    if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'Publie il y a $weeks sem';
    }

    if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return 'Publie il y a $months mois';
    }

    final years = (difference.inDays / 365).floor();
    return 'Publie il y a $years an${years > 1 ? 's' : ''}';
  }

  Future<void> _loadSellerContext() async {
    try {
      final user = await _authService.fetchCurrentUser();
      final sellerProfileId = _sellerProfileIdValue;
      UserProfileData? nextSellerProfile;

      if (sellerProfileId.isNotEmpty) {
        final sellerProfile = await _catalogApiService.fetchSellerProfile(
          sellerProfileId,
        );
        nextSellerProfile = buildSellerProfileFromApi(sellerProfile);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _currentViewerUserId = user['id']?.toString().trim();
        _sellerProfileData = nextSellerProfile;
        if (nextSellerProfile != null) {
          _isSubscribed = nextSellerProfile.isFollowing;
        }
      });
    } on AppApiException {
      // Keep product detail usable even when seller profile refresh fails.
    }
  }

  Future<void> _refreshSellerProfileState() async {
    final sellerProfileId = _sellerProfileIdValue;
    if (sellerProfileId.isEmpty) {
      return;
    }

    try {
      final sellerProfile = await _catalogApiService.fetchSellerProfile(
        sellerProfileId,
      );
      final nextSellerProfile = buildSellerProfileFromApi(sellerProfile);
      if (!mounted) {
        return;
      }
      setState(() {
        _sellerProfileData = nextSellerProfile;
        _isSubscribed = nextSellerProfile.isFollowing;
      });
    } on AppApiException {
      // Ignore silent seller follow-state refresh errors here.
    }
  }

  Future<void> _toggleSubscription() async {
    final sellerProfileId = _sellerProfileIdValue;
    if (sellerProfileId.isEmpty || _isSubscriptionSubmitting) {
      return;
    }

    if (_isOwnSeller) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vous ne pouvez pas vous abonner a votre propre boutique.',
          ),
        ),
      );
      return;
    }

    final wasSubscribed = _isSubscribed;
    setState(() => _isSubscriptionSubmitting = true);

    try {
      final data = wasSubscribed
          ? await _catalogApiService.unfollowSeller(sellerProfileId)
          : await _catalogApiService.followSeller(sellerProfileId);
      final nextProfile = buildSellerProfileFromApi(data);
      if (!mounted) {
        return;
      }
      setState(() {
        _sellerProfileData = nextProfile;
        _isSubscribed = nextProfile.isFollowing;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasSubscribed
                ? 'Vous etes desabonne de la chaine de ${nextProfile.name}.'
                : 'Vous etes abonne a la chaine de ${nextProfile.name}.',
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
    } finally {
      if (mounted) {
        setState(() => _isSubscriptionSubmitting = false);
      }
    }
  }

  Future<void> _showSubscribeConfirmation() async {
    final theme = Theme.of(context);
    final appColors = theme.appColors;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            _isSubscribed
                ? 'Se desabonner de cette chaine ?'
                : 'S\'abonner a la chaine de $_sellerNameValue ?',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            _isSubscribed
                ? 'Si vous vous desabonnez, vous risquez de ne plus recevoir de notification sur la prochaine activite de $_sellerNameValue.'
                : 'Vous recevrez les nouveautes et actualites de la chaine de $_sellerNameValue.',
            style: TextStyle(color: appColors.mutedText, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _toggleSubscription();
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(_isSubscribed ? 'Confirmer' : 'S\'abonner'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openSellerProfile() async {
    final sellerProfileId = _sellerProfileIdValue;
    if (sellerProfileId.isEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SellerProfilePage(
            profile: buildProfileFromUser(
              userId: null,
              name: _sellerNameValue,
              avatarUrl: _sellerAvatarUrlValue,
              subtitle: _sellerBadgeValue,
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

  ChatPage _buildSellerChatPage({String? initialMessage}) {
    final images =
        (product['images'] as List?)?.whereType<String>().toList() ??
        const <String>[];
    final shouldShowProductContextCard = initialMessage != null;

    return ChatPage(
      conversationProductId: product['id']?.toString(),
      conversationUserId: _sellerUserIdValue.isNotEmpty
          ? _sellerUserIdValue
          : null,
      showProductContextCard: shouldShowProductContextCard,
      sellerName: _sellerNameValue,
      sellerRole: _resolvedSellerBadge,
      avatarUrl: _sellerAvatarUrlValue,
      product: Map<String, dynamic>.from(product),
      productPageBuilder: (product, {openedFromChat = false}) =>
          ProductDetailPage(product: product, openedFromChat: openedFromChat),
      productTitle: _resolveStringField(['title', 'name'], 'Produit'),
      productDescription: _resolveStringField([
        'description',
      ], 'Aucune description disponible.'),
      productSubtitle: _buildProductSubtitle(),
      productPriceLabel: _buildProductPriceLabel(),
      productImageUrl: images.isNotEmpty
          ? images.first
          : _resolveStringField([
              'thumbnail',
              'imageUrl',
            ], _defaultSellerAvatarUrl),
      initialMessage: initialMessage,
      embedProductContextInInitialMessage: initialMessage != null,
    );
  }

  Future<void> _ensureSellerUserIdLoaded() async {
    if (_sellerUserIdValue.isNotEmpty) {
      return;
    }

    final productId = product['id']?.toString().trim() ?? '';
    if (productId.isEmpty) {
      return;
    }

    final refreshedProduct = await _catalogApiService.fetchProductById(
      productId,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _productData = Map<String, dynamic>.from(refreshedProduct);
      _likeCount = _resolveLikeCount(_productData);
      _commentCount = _resolveCount(_productData, 'commentsCount');
      _shareCount = _resolveCount(_productData, 'sharesCount');
    });
    await _loadLikeStatus();
  }

  Future<void> _loadLikeStatus() async {
    final productId = product['id']?.toString().trim() ?? '';
    if (productId.isEmpty) {
      return;
    }

    try {
      final isLiked = await _catalogApiService.hasLikedProduct(productId);
      if (!mounted) {
        return;
      }
      setState(() => _isLiked = isLiked);
    } on AppApiException {
      if (!mounted) {
        return;
      }
      setState(() => _isLiked = false);
    }
  }

  Future<void> _openSellerChat({String? initialMessage}) async {
    try {
      await _ensureSellerUserIdLoaded();
    } on AppApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }

    if (_sellerUserIdValue.isEmpty) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'ouvrir cette conversation.'),
        ),
      );
      return;
    }

    final route = MaterialPageRoute(
      builder: (_) => _buildSellerChatPage(initialMessage: initialMessage),
    );

    if (widget.openedFromChat) {
      Navigator.pushReplacement(context, route);
      return;
    }

    Navigator.push(context, route);
  }

  int _resolveLikeCount(Map<String, dynamic> currentProduct) {
    return _resolveCount(currentProduct, 'likesCount');
  }

  String _formatActionCount(int value) {
    return value <= 0 ? '' : value.toString();
  }

  int _resolveCount(Map<String, dynamic> currentProduct, String key) {
    final rawValue = currentProduct[key];
    if (rawValue is int) {
      return rawValue;
    }
    if (rawValue is num) {
      return rawValue.toInt();
    }
    return 0;
  }

  String _formatRelativeTime(DateTime value) {
    final difference = DateTime.now().difference(value.toLocal());
    if (difference.inMinutes < 1) {
      return 'maintenant';
    }
    if (difference.inMinutes < 60) {
      return 'il y a ${difference.inMinutes} min';
    }
    if (difference.inHours < 24) {
      return 'il y a ${difference.inHours} h';
    }
    if (difference.inDays < 7) {
      return 'il y a ${difference.inDays} j';
    }
    if (difference.inDays < 30) {
      return 'il y a ${(difference.inDays / 7).floor()} sem';
    }
    if (difference.inDays < 365) {
      return 'il y a ${(difference.inDays / 30).floor()} mois';
    }
    final years = (difference.inDays / 365).floor();
    return 'il y a $years an${years > 1 ? 's' : ''}';
  }

  AppCommentItem _mapCommentItem(Map<String, dynamic> rawComment) {
    final rawAuthor = rawComment['author'];
    final author = rawAuthor is Map<String, dynamic>
        ? rawAuthor
        : rawAuthor is Map
        ? Map<String, dynamic>.from(rawAuthor)
        : const <String, dynamic>{};
    final createdAt = DateTime.tryParse(
      rawComment['createdAt']?.toString() ?? '',
    );

    return AppCommentItem(
      authorId: author['id']?.toString(),
      authorName: (author['displayName']?.toString().trim().isNotEmpty ?? false)
          ? author['displayName'].toString().trim()
          : 'Membre Bahibo',
      avatarUrl: (author['avatarUrl']?.toString().trim().isNotEmpty ?? false)
          ? author['avatarUrl'].toString().trim()
          : _defaultSellerAvatarUrl,
      timeLabel: createdAt == null
          ? 'maintenant'
          : _formatRelativeTime(createdAt),
      message: rawComment['content']?.toString().trim() ?? '',
    );
  }

  Future<void> _loadComments() async {
    final productId = product['id']?.toString().trim() ?? '';
    if (productId.isEmpty) {
      return;
    }

    final rawComments = await _catalogApiService.fetchProductComments(
      productId,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _comments
        ..clear()
        ..addAll(rawComments.map(_mapCommentItem));
      _commentCount = _comments.length;
    });
  }

  Future<AppCommentItem?> _submitComment(String message) async {
    final productId = product['id']?.toString().trim() ?? '';
    if (productId.isEmpty) {
      return null;
    }

    final response = await _catalogApiService.addProductComment(
      productId: productId,
      content: message,
    );
    final updatedProduct = response['product'];
    final createdComment = response['comment'];

    if (updatedProduct is Map && mounted) {
      setState(() {
        _productData = Map<String, dynamic>.from(updatedProduct);
        _likeCount = _resolveLikeCount(_productData);
        _commentCount = _resolveCount(_productData, 'commentsCount');
        _shareCount = _resolveCount(_productData, 'sharesCount');
      });
    }

    if (createdComment is Map) {
      return _mapCommentItem(Map<String, dynamic>.from(createdComment));
    }

    return null;
  }

  Future<void> _toggleLike() async {
    final productId = product['id']?.toString().trim() ?? '';
    if (productId.isEmpty || _isLikeSubmitting) {
      return;
    }

    setState(() => _isLikeSubmitting = true);

    try {
      final updatedProduct = _isLiked
          ? await _catalogApiService.unlikeProduct(productId)
          : await _catalogApiService.likeProduct(productId);
      if (!mounted) {
        return;
      }
      setState(() {
        _productData = updatedProduct;
        _likeCount = _resolveLikeCount(updatedProduct);
        _commentCount = _resolveCount(updatedProduct, 'commentsCount');
        _shareCount = _resolveCount(updatedProduct, 'sharesCount');
        _isLiked = !_isLiked;
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
        setState(() => _isLikeSubmitting = false);
      }
    }
  }

  void _showLikesSheet() {
    showAppLikesSheet(context, currentLikeCount: _likeCount, likes: _likes);
  }

  @override
  Widget build(BuildContext context) {
    final List<String> images =
        (product['images'] as List?)?.whereType<String>().toList() ??
        [product['thumbnail'] ?? 'https://via.placeholder.com/150'];

    final String title = product['title'] ?? 'Produit';
    final double price = (product['price'] as num?)?.toDouble() ?? 0.0;
    final String priceFormatted = formatPriceAmount(price);
    final String currency = resolveProductCurrency(product);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appColors = theme.appColors;
    final pageBackgroundColor = appColors.backgroundBase;
    final topBarColor = appColors.panelMuted;
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
                                  horizontal: 0,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _socialActionCard(
                                      icon: _isLiked
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      label: _formatActionCount(_likeCount),
                                      iconColor: appColors.favoriteAccent,
                                      onTap: _toggleLike,
                                    ),
                                    _socialActionCard(
                                      icon: Icons.chat,
                                      label: _formatActionCount(_commentCount),
                                      iconColor: actionIconColor,
                                      onTap: _showCommentsSheet,
                                    ),
                                    _socialActionCard(
                                      icon: Icons.reply_rounded,
                                      label: _formatActionCount(_shareCount),
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
                                        product['category'] ?? 'Produit',
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
                                            currency,
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
                                          _buildPublicationLabel(),
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
                                onTap: _openSellerProfile,
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
                                                    imageUrls: [
                                                      _sellerAvatarUrlValue,
                                                    ],
                                                    initialIndex: 0,
                                                    heroTag:
                                                        'seller-avatar-detail',
                                                    onSellerTap:
                                                        _openSellerProfile,
                                                    onSellerMessageTap: () {
                                                      _openSellerChat();
                                                    },
                                                    overlay: ImageViewerOverlayData(
                                                      title: 'Profil vendeur',
                                                      description:
                                                          'Vendeur actif sur Bahibo, disponible pour des photos et details supplementaires.',
                                                      sellerName:
                                                          _sellerNameValue,
                                                      sellerAvatarUrl:
                                                          _sellerAvatarUrlValue,
                                                      sellerBadge:
                                                          _resolvedSellerBadge,
                                                      isUserProfileImage: true,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Hero(
                                              tag: 'seller-avatar-detail',
                                              child: AppCircleNetworkAvatar(
                                                radius: 28,
                                                imageUrl: _sellerAvatarUrlValue,
                                                userId: _sellerUserIdValue,
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
                                              _sellerNameValue,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: detailPrimaryTextColor,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                _resolvedSellerBadge
                                                        .toLowerCase()
                                                        .contains('certifie')
                                                    ? SellerCertifiedMiniBadge(
                                                        label:
                                                            _resolvedSellerBadge,
                                                      )
                                                    : Container(
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
                                                              Icons
                                                                  .storefront_rounded,
                                                              size: 12,
                                                              color: theme
                                                                  .colorScheme
                                                                  .primary,
                                                            ),
                                                            const SizedBox(
                                                              width: 3,
                                                            ),
                                                            Text(
                                                              _resolvedSellerBadge,
                                                              style: TextStyle(
                                                                color: theme
                                                                    .colorScheme
                                                                    .primary,
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
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
                                      OutlinedButton.icon(
                                        onPressed: _isSubscriptionSubmitting
                                            ? null
                                            : _showSubscribeConfirmation,
                                        icon: Icon(
                                          _isSubscribed
                                              ? Icons
                                                    .notifications_active_rounded
                                              : Icons.person_add_alt_1,
                                          size: 18,
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              theme.colorScheme.primary,
                                          side: BorderSide(
                                            color: theme.colorScheme.primary,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 14,
                                          ),
                                        ),
                                        label: Text(
                                          _isSubscriptionSubmitting
                                              ? '...'
                                              : (_isSubscribed
                                                    ? 'Abonné'
                                                    : "S'abonner"),
                                          style: const TextStyle(fontSize: 12),
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
                                      product['description'] ??
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
          allowEmptySend: true,
          onSend: (text) {
            final message = text.trim();
            _openSellerChat(
              initialMessage: message.isEmpty
                  ? _defaultAvailabilityMessage
                  : message,
            );
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
            _openSellerChat();
          },
          overlay: ImageViewerOverlayData(
            title: product['title'] as String? ?? 'Produit',
            description:
                product['description'] as String? ??
                'Aucune description disponible.',
            sellerName: _sellerNameValue,
            sellerUserId: _sellerUserIdValue,
            sellerAvatarUrl: _sellerAvatarUrlValue,
            sellerBadge: _resolvedSellerBadge,
          ),
        ),
      ),
    );
  }

  Future<void> _showShareSuggestions() async {
    final productId = product['id']?.toString().trim() ?? '';
    if (productId.isEmpty || _isShareSubmitting) {
      showAppShareSheet(context);
      return;
    }

    setState(() => _isShareSubmitting = true);
    try {
      final updatedProduct = await _catalogApiService.shareProduct(productId);
      if (!mounted) {
        return;
      }
      setState(() {
        _productData = updatedProduct;
        _likeCount = _resolveLikeCount(updatedProduct);
        _commentCount = _resolveCount(updatedProduct, 'commentsCount');
        _shareCount = _resolveCount(updatedProduct, 'sharesCount');
      });
      showAppShareSheet(context);
    } on AppApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _isShareSubmitting = false);
      }
    }
  }

  Future<void> _showCommentsSheet() async {
    try {
      await _loadComments();
      if (!mounted) {
        return;
      }
      await showAppCommentsSheet(
        context,
        currentCommentCount: _commentCount,
        comments: _comments,
        onCommentCountChanged: (value) {
          if (!mounted) return;
          setState(() => _commentCount = value);
        },
        onSubmitComment: _submitComment,
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
    final hasLabel = label.trim().isNotEmpty;
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
          width: 108,
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 7),
          decoration: BoxDecoration(
            color: actionCardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: actionBorderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: iconColor),
              if (hasLabel) ...[
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: actionTextColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
