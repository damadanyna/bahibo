import 'package:bahibo/component/ProductCard.dart';
import 'package:bahibo/component/app_back_button.dart';
import 'package:bahibo/component/app_network_image.dart';
import 'package:bahibo/component/app_page_skeletons.dart';
import 'package:bahibo/component/app_page_refresh.dart';
import 'package:bahibo/component/profile_models.dart';
import 'package:bahibo/component/user_profile_page.dart';
import 'package:bahibo/component/user_list_page.dart';
import 'package:bahibo/page/chat_page.dart';
import 'package:bahibo/page/image_viewer_page.dart';
import 'package:bahibo/services/app_api_client.dart';
import 'package:bahibo/services/app_auth_service.dart';
import 'package:bahibo/services/catalog_api_service.dart';
import 'package:flutter/material.dart';

import 'package:bahibo/theme/app_theme_extensions.dart';

class SellerProfilePage extends StatefulWidget {
  final UserProfileData profile;

  const SellerProfilePage({super.key, required this.profile});

  @override
  State<SellerProfilePage> createState() => _SellerProfilePageState();
}

class _SellerProfilePageState extends State<SellerProfilePage>
    with AppPageRefreshMixin<SellerProfilePage> {
  static const String _defaultAvatarUrl =
      'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=600';
  static const String _defaultCoverImageUrl =
      'https://images.unsplash.com/photo-1520607162513-77705c0f0d4a?w=1600';
  final AppAuthService _authService = AppAuthService();
  final CatalogApiService _catalogApiService = CatalogApiService();
  bool _showEntrySkeleton = true;
  bool _isSubscribed = false;
  bool _isSubscriptionSubmitting = false;
  String? _currentViewerUserId;
  late UserProfileData _currentProfile;

  UserProfileData get profile => _currentProfile;

  String get _profileAvatarUrl {
    final value = profile.avatarUrl.trim();
    return value.isNotEmpty ? value : _defaultAvatarUrl;
  }

  String get _profileCoverImageUrl {
    final value = profile.coverImageUrl.trim();
    if (value.isNotEmpty) {
      return value;
    }
    return _defaultCoverImageUrl;
  }

  bool get _isOwnSellerProfile {
    final currentViewerUserId = _currentViewerUserId?.trim() ?? '';
    final sellerUserId = profile.userId?.trim() ?? '';
    return currentViewerUserId.isNotEmpty &&
        sellerUserId.isNotEmpty &&
        currentViewerUserId == sellerUserId;
  }

  void _openMessageThread() {
    if (_isOwnSellerProfile) {
      return;
    }

    final recipientUserId = profile.userId?.trim() ?? '';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          conversationUserId: recipientUserId.isNotEmpty
              ? recipientUserId
              : null,
          showProductContextCard: false,
          showInlineProductSnapshots: false,
          sellerName: profile.name,
          sellerRole: profile.roleLabel,
          avatarUrl: _profileAvatarUrl,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    initializePageRefresh();
    _currentProfile = widget.profile;
    _isSubscribed = widget.profile.isFollowing;
    _loadCurrentViewerUser();
    _refreshSellerProfile(recordView: true);
    Future.delayed(const Duration(milliseconds: 240), () {
      if (!mounted) return;
      setState(() => _showEntrySkeleton = false);
    });
  }

  @override
  void dispose() {
    disposePageRefresh();
    super.dispose();
  }

  @override
  Future<void> onPageReload() async {
    if (mounted) {
      setState(() => _showEntrySkeleton = true);
    }
    await _refreshSellerProfile();
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() => _showEntrySkeleton = false);
  }

  Future<void> _refreshSellerProfile({bool recordView = false}) async {
    final sellerProfileId = profile.sellerProfileId?.trim() ?? '';
    if (sellerProfileId.isEmpty) {
      return;
    }

    try {
      final data = recordView
          ? await _catalogApiService.recordSellerView(sellerProfileId)
          : await _catalogApiService.fetchSellerProfile(sellerProfileId);
      final nextProfile = buildSellerProfileFromApi(data);
      if (!mounted) {
        return;
      }
      setState(() {
        _currentProfile = nextProfile;
        _isSubscribed = nextProfile.isFollowing;
      });
    } on AppApiException catch (error) {
      if (recordView) {
        try {
          final data = await _catalogApiService.fetchSellerProfile(
            sellerProfileId,
          );
          final nextProfile = buildSellerProfileFromApi(data);
          if (!mounted) {
            return;
          }
          setState(() {
            _currentProfile = nextProfile;
            _isSubscribed = nextProfile.isFollowing;
          });
        } on AppApiException {
          debugPrint('Unable to refresh seller profile: ${error.message}');
        }
      } else {
        debugPrint('Unable to refresh seller profile: ${error.message}');
      }
    }
  }

  Future<void> _loadCurrentViewerUser() async {
    try {
      final user = await _authService.fetchCurrentUser();
      final userId = user['id']?.toString().trim();
      if (!mounted) {
        return;
      }
      setState(() {
        _currentViewerUserId =
            userId != null && userId.isNotEmpty ? userId : null;
      });
    } catch (_) {
      // Keep page usable when current user cannot be resolved.
    }
  }

  Future<void> _toggleSubscription() async {
    final sellerProfileId = profile.sellerProfileId?.trim() ?? '';
    if (sellerProfileId.isEmpty || _isSubscriptionSubmitting) {
      return;
    }

    setState(() => _isSubscriptionSubmitting = true);

    try {
      final data = _isSubscribed
          ? await _catalogApiService.unfollowSeller(sellerProfileId)
          : await _catalogApiService.followSeller(sellerProfileId);
      final nextProfile = buildSellerProfileFromApi(data);
      if (!mounted) {
        return;
      }
      setState(() {
        _currentProfile = nextProfile;
        _isSubscribed = nextProfile.isFollowing;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isSubscribed
                ? 'Vous etes abonne a la chaine de ${profile.name}.'
                : 'Vous etes desabonne de la chaine de ${profile.name}.',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final primaryGreen = theme.colorScheme.primary;
    final surfaceColor = theme.cardColor;
    final elevatedSurfaceColor = theme.colorScheme.surfaceContainer;
    final mutedColor = appColors.mutedText;

    return Scaffold(
      backgroundColor: appColors.backgroundBase,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: refreshPageWithDialog,
            child: _showEntrySkeleton
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [SellerProfileSkeleton()],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      _buildProfileHeader(
                        context,
                        surfaceColor: surfaceColor,
                        elevatedSurfaceColor: elevatedSurfaceColor,
                        mutedColor: mutedColor,
                        primaryGreen: primaryGreen,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildQuickStats(
                              context,
                              surfaceColor,
                              mutedColor,
                              primaryGreen,
                            ),
                            const SizedBox(height: 18),
                            _buildSectionHeader(
                              'Annonces publiees',
                              '${profile.products.length} annonces',
                            ),
                            const SizedBox(height: 10),
                            _buildFilterRow(context),
                            const SizedBox(height: 8),
                            ..._buildProductCards(),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 24,
            child: AppBackButton(onTap: () => _showExitDialog(context)),
          ),
          if (isOffline) const AppOfflineBanner(),
        ],
      ),
    );
  }

  Future<void> _showExitDialog(BuildContext context) async {
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
            'Quitter ce profil ?',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Vous allez revenir a la page precedente.',
            style: TextStyle(color: appColors.mutedText, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Quitter'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAboutDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final locationLabel = profile.headline.trim().isNotEmpty
        ? profile.headline.trim()
        : 'Localisation indisponible';
    final accountCreatedLabel = _buildAccountCreatedLabel();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'A propos',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.about,
                style: TextStyle(color: appColors.mutedText, height: 1.45),
              ),
              const SizedBox(height: 16),
              _dialogInfoRow(
                Icons.location_on_outlined,
                locationLabel,
                context,
              ),
              const SizedBox(height: 10),
              _dialogInfoRow(
                Icons.schedule_outlined,
                profile.responseLabel,
                context,
              ),
              if (accountCreatedLabel != null) ...[
                const SizedBox(height: 10),
                _dialogInfoRow(
                  Icons.verified_user_outlined,
                  accountCreatedLabel,
                  context,
                ),
              ],
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  String? _buildAccountCreatedLabel() {
    final rawValue =
        profile.accountCreatedAt?.trim() ?? profile.profileCreatedAt?.trim();
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }

    final parsedDate = DateTime.tryParse(rawValue)?.toLocal();
    if (parsedDate == null) {
      return null;
    }

    final day = parsedDate.day.toString().padLeft(2, '0');
    final month = parsedDate.month.toString().padLeft(2, '0');
    final year = parsedDate.year.toString();
    return 'Compte cree le $day/$month/$year';
  }

  Future<void> _showSubscribeConfirmation(BuildContext context) async {
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
                : 'S\'abonner a la chaine de ${profile.name} ?',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            _isSubscribed
                ? 'Si vous vous desabonnez, vous risquez de ne plus recevoir de notification sur la prochaine activite de ${profile.name}.'
                : 'Vous recevrez les nouveautes et actualites de la chaine de ${profile.name}.',
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

  Widget _dialogInfoRow(IconData icon, String text, BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: appColors.mutedText),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: appColors.mutedText, height: 1.35),
          ),
        ),
      ],
    );
  }

  void _openProductImageViewer(
    Map<String, dynamic> product, {
    required int productIndex,
    int initialImageIndex = 0,
  }) {
    String? resolveProductText(
      Map<String, dynamic> sourceProduct,
      List<String> keys,
    ) {
      for (final key in keys) {
        final rawValue = sourceProduct[key];
        if (rawValue is String && rawValue.trim().isNotEmpty) {
          return rawValue.trim();
        }
      }
      return null;
    }

    List<String> resolveViewerImages(Map<String, dynamic> sourceProduct) {
      final imageUrls =
          (sourceProduct['images'] as List?)
              ?.whereType<String>()
              .map((imageUrl) => imageUrl.trim())
              .where((imageUrl) => imageUrl.isNotEmpty)
              .toList() ??
          <String>[];
      final thumbnail = (sourceProduct['thumbnail'] as String?)?.trim() ?? '';
      return imageUrls.isNotEmpty
          ? imageUrls
          : (thumbnail.isNotEmpty ? <String>[thumbnail] : <String>[]);
    }

    final viewerEntries = <ImageViewerEntry>[];
    var selectedEntryIndex = 0;
    for (var index = 0; index < profile.products.length; index++) {
      final sellerProduct = profile.products[index];
      final viewerImages = resolveViewerImages(sellerProduct);
      if (viewerImages.isEmpty) {
        continue;
      }

      final title = resolveProductText(sellerProduct, const [
        'title',
        'name',
        'productTitle',
      ]);
      final description = resolveProductText(sellerProduct, const [
        'description',
        'subtitle',
        'content',
        'details',
        'productDescription',
      ]);
      final initialIndex = index == productIndex ? initialImageIndex : 0;
      if (index == productIndex) {
        selectedEntryIndex = viewerEntries.length;
      }
      viewerEntries.add(
        ImageViewerEntry(
          imageUrls: viewerImages,
          initialIndex: initialIndex,
          overlay: ImageViewerOverlayData(
            title: title,
            description: description,
            sellerName: profile.name,
            sellerUserId: profile.userId,
            sellerAvatarUrl: _profileAvatarUrl,
            sellerBadge: profile.roleLabel,
          ),
        ),
      );
    }

    if (viewerEntries.isEmpty) {
      return;
    }

    final safeEntryIndex = selectedEntryIndex.clamp(0, viewerEntries.length - 1);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageViewerPage(
          imageUrls: const <String>[],
          entries: viewerEntries,
          initialEntryIndex: safeEntryIndex,
          onSellerMessageTap: _isOwnSellerProfile ? null : _openMessageThread,
        ),
      ),
    );
  }

  List<Widget> _buildProductCards() {
    final widgets = <Widget>[];
    for (var index = 0; index < profile.products.length; index++) {
      widgets.add(
        ProductCard(
          product: profile.products[index],
          onTap: (initialImageIndex) => _openProductImageViewer(
            profile.products[index],
            productIndex: index,
            initialImageIndex: initialImageIndex,
          ),
        ),
      );
      if (index != profile.products.length - 1) {
        widgets.add(const SizedBox(height: 10));
      }
    }
    return widgets;
  }

  Widget _buildFilterRow(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip(context, 'Madagascar', hasArrow: true),
          const SizedBox(width: 8),
          _filterChip(context, 'Disponible'),
          const SizedBox(width: 8),
          _filterChip(context, 'Recents'),
        ],
      ),
    );
  }

  Widget _filterChip(
    BuildContext context,
    String text, {
    bool hasArrow = false,
  }) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: appColors.inputBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          if (hasArrow) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context, {
    required Color surfaceColor,
    required Color elevatedSurfaceColor,
    required Color mutedColor,
    required Color primaryGreen,
  }) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;

    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: AppNetworkImage(
                imageUrl: _profileCoverImageUrl,
                fit: BoxFit.cover,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [appColors.scrimSoft, appColors.scrimStrong],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [appColors.heroSurface, Colors.transparent],
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ImageViewerPage(
                                  imageUrls: [_profileAvatarUrl],
                                  initialIndex: 0,
                                  heroTag: 'profile-avatar-${profile.name}',
                                  onSellerMessageTap: _isOwnSellerProfile
                                      ? null
                                      : _openMessageThread,
                                  overlay: ImageViewerOverlayData(
                                    title: profile.name,
                                    description: profile.headline,
                                    sellerName: profile.name,
                                    sellerUserId: profile.userId,
                                    sellerAvatarUrl: _profileAvatarUrl,
                                    sellerBadge: profile.roleLabel,
                                    isUserProfileImage: true,
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Hero(
                            tag: 'profile-avatar-${profile.name}',
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: appColors.heroSurface,
                                shape: BoxShape.circle,
                                border: Border.all(color: appColors.heroBorder),
                              ),
                              child: AppCircleNetworkAvatar(
                                radius: 34,
                                imageUrl: _profileAvatarUrl,
                                userId: profile.userId,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      profile.name,
                                      style: TextStyle(
                                        color: appColors.heroForeground,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: appColors.heroSurface,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: appColors.heroBorder,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.circle,
                                          size: 10,
                                          color: appColors.onlineStatus,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'En ligne',
                                          style: TextStyle(
                                            color: appColors.heroForeground,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                profile.headline,
                                style: TextStyle(
                                  color: appColors.heroForegroundMuted,
                                  height: 1.35,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildHeaderPill(
                                    icon: Icons.verified_rounded,
                                    label: profile.roleLabel,
                                  ),
                                  _buildHeaderPill(
                                    icon: Icons.flash_on_rounded,
                                    label: profile.responseLabel,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                      child: InkWell(
                        onTap: () => _showAboutDialog(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Ink(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: elevatedSurfaceColor.withOpacity(
                              theme.brightness == Brightness.dark ? 0.92 : 0.88,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: appColors.overlayBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildFeatureTile(
                                      icon: Icons.location_on_outlined,
                                      label: 'Zone',
                                      value: 'Antananarivo',
                                      valueColor: appColors.heroForeground,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildFeatureTile(
                                      icon: Icons.workspace_premium_outlined,
                                      label: 'Fiabilite',
                                      value: profile.rating,
                                      valueColor: appColors.onlineStatus,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                profile.about,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.brightness == Brightness.dark
                                      ? appColors.heroForegroundMuted
                                      : theme.colorScheme.onSurfaceVariant,
                                  height: 1.45,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!_isOwnSellerProfile)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _openMessageThread,
                              icon: const Icon(Icons.message_outlined, size: 18),
                              label: const Text('Message'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: appColors.heroForeground,
                                foregroundColor: theme.colorScheme.primary,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isSubscriptionSubmitting
                                  ? null
                                  : () => _showSubscribeConfirmation(context),
                              icon: Icon(
                                _isSubscribed
                                    ? Icons.notifications_active_rounded
                                    : Icons.person_add_alt_1_rounded,
                                size: 18,
                              ),
                              label: Text(_isSubscribed ? 'Abonné' : "S'abonner"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
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
      ),
    );
  }

  Widget _buildHeaderPill({required IconData icon, required String label}) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: appColors.heroSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: appColors.heroBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: appColors.heroForeground),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: appColors.heroForeground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final isDark = theme.brightness == Brightness.dark;
    final tileColor = isDark
        ? appColors.heroSurface
        : theme.colorScheme.surface.withOpacity(0.72);
    final iconBoxColor = isDark
        ? appColors.heroBorder
        : theme.colorScheme.surfaceContainerHighest.withOpacity(0.9);
    final iconColor = isDark
        ? appColors.heroForeground
        : theme.colorScheme.onSurfaceVariant;
    final labelColor = isDark
        ? appColors.heroForegroundMuted
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBoxColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(
    BuildContext context,
    Color surfaceColor,
    Color mutedColor,
    Color primaryGreen,
  ) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            context: context,
            surfaceColor: surfaceColor,
            label: 'Abonnes',
            value: profile.followerCount,
            icon: Icons.groups_2_outlined,
            accent: primaryGreen,
            mutedColor: mutedColor,
            pageTitle: 'Abonnes',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            context: context,
            surfaceColor: surfaceColor,
            label: 'Vues profil',
            value: profile.visitorCount,
            icon: Icons.visibility_outlined,
            accent: Theme.of(context).appColors.success,
            mutedColor: mutedColor,
            pageTitle: 'Vues profil',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            context: context,
            surfaceColor: surfaceColor,
            label: 'Likes total',
            value: profile.totalLikesCount,
            icon: Icons.favorite_outline,
            accent: Theme.of(context).colorScheme.tertiary,
            mutedColor: mutedColor,
            pageTitle: 'Likes total',
          ),
        ),
      ],
    );
  }

  int _metricValueByLabel(String metricLabel) {
    return switch (metricLabel) {
      'Abonnes' => _metricCountValue(profile.followerCount),
      'Vues profil' => _metricCountValue(profile.visitorCount),
      'Likes total' => _metricCountValue(profile.totalLikesCount),
      _ => 0,
    };
  }

  UserListItemData _mapMetricUserItem(Map<String, dynamic> rawUser) {
    final sellerProfileId = rawUser['sellerProfileId']?.toString().trim();
    final userId = rawUser['userId']?.toString().trim();
    final role = rawUser['role']?.toString().trim().toUpperCase() ?? 'CUSTOMER';
    final name = rawUser['displayName']?.toString().trim();
    final avatarUrl = rawUser['avatarUrl']?.toString().trim() ?? '';
    final subtitle = rawUser['subtitle']?.toString().trim();
    final trailingText = rawUser['trailingText']?.toString().trim() ?? '';
    final count = rawUser['count'] is num
        ? (rawUser['count'] as num).toInt()
        : int.tryParse(rawUser['count']?.toString() ?? '');
    final metricLabel = rawUser['metricLabel']?.toString().trim();

    final previewProfile = buildProfileFromUser(
      userId: userId != null && userId.isNotEmpty ? userId : null,
      name: name != null && name.isNotEmpty ? name : 'Membre Bahibo',
      avatarUrl: avatarUrl,
      subtitle: metricLabel == 'Likes total' && count != null && count > 0
          ? count > 1
                ? 'A laisse $count likes sur vos produits'
                : 'A laisse 1 like sur votre produit'
          : subtitle != null && subtitle.isNotEmpty
          ? subtitle
          : 'Membre de la communaute Bahibo',
    );

    return UserListItemData(
      name: previewProfile.name,
      subtitle: previewProfile.headline,
      imageUrl: previewProfile.avatarUrl,
      trailingText: metricLabel == 'Likes total' && count != null && count > 0
          ? count > 1
                ? '$count likes'
                : '1 like'
          : trailingText,
      userId: previewProfile.userId,
      profileData: previewProfile,
      destinationBuilder:
          role == 'SELLER' &&
              sellerProfileId != null &&
              sellerProfileId.isNotEmpty
          ? (_) => FutureBuilder<Map<String, dynamic>>(
              future: _catalogApiService.fetchSellerProfile(sellerProfileId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Scaffold(
                    backgroundColor: Theme.of(context).appColors.backgroundBase,
                    body: const Center(child: CircularProgressIndicator()),
                  );
                }

                return SellerProfilePage(
                  profile: buildSellerProfileFromApi(snapshot.data!),
                );
              },
            )
          : userId != null && userId.isNotEmpty
          ? (_) => FutureBuilder<Map<String, dynamic>>(
              future: _catalogApiService.fetchUserProfile(userId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Scaffold(
                    backgroundColor: Theme.of(context).appColors.backgroundBase,
                    body: const Center(child: CircularProgressIndicator()),
                  );
                }

                return UserProfilePage(
                  profile: buildPublicUserProfileFromApi(snapshot.data!),
                );
              },
            )
          : (_) => UserProfilePage(profile: previewProfile),
    );
  }

  Future<List<UserListItemData>> _fetchMetricUsers({
    required String metricLabel,
  }) async {
    final sellerProfileId = profile.sellerProfileId?.trim() ?? '';
    if (sellerProfileId.isEmpty || _metricValueByLabel(metricLabel) <= 0) {
      return const <UserListItemData>[];
    }

    final rawUsers = switch (metricLabel) {
      'Abonnes' => await _catalogApiService.fetchSellerFollowers(
        sellerProfileId,
      ),
      'Vues profil' => await _catalogApiService.fetchSellerProfileViews(
        sellerProfileId,
      ),
      'Likes total' => await _catalogApiService.fetchSellerLikeUsers(
        sellerProfileId,
      ),
      _ => const <Map<String, dynamic>>[],
    };

    return rawUsers
        .map(
          (user) => _mapMetricUserItem({...user, 'metricLabel': metricLabel}),
        )
        .toList();
  }

  Future<void> _openMetricUsers(String metricLabel) async {
    try {
      final users = await _fetchMetricUsers(metricLabel: metricLabel);

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserListPage(
            title: metricLabel,
            totalCount: _metricValueByLabel(metricLabel),
            users: users,
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

  int _metricCountValue(String value) {
    final normalizedValue = value.trim().toLowerCase();
    if (normalizedValue.isEmpty) {
      return 0;
    }

    final multiplier = normalizedValue.endsWith('k')
        ? 1000
        : normalizedValue.endsWith('m')
        ? 1000000
        : 1;
    final numericPart = normalizedValue.replaceAll(RegExp(r'[^0-9\.]'), '');
    final parsedValue = double.tryParse(numericPart);
    if (parsedValue == null) {
      return 0;
    }

    return (parsedValue * multiplier).round();
  }

  Widget _statCard({
    required BuildContext context,
    required Color surfaceColor,
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
    required Color mutedColor,
    required String pageTitle,
  }) {
    return GestureDetector(
      onTap: () => _openMetricUsers(pageTitle),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: mutedColor, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String meta) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const Spacer(),
        Text(
          meta,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
