import 'dart:io';
import 'dart:async';

import 'package:bahibo/component/ProductCard.dart';
import 'package:bahibo/component/app_network_image.dart';
import 'package:bahibo/component/app_page_refresh.dart';
import 'package:bahibo/component/app_page_skeletons.dart';
import 'package:bahibo/component/product_list_page.dart';
import 'package:bahibo/component/profile_models.dart';
import 'package:bahibo/component/seller_profile_page.dart';
import 'package:bahibo/component/user_profile_page.dart';
import 'package:bahibo/component/ui/dinamic_icon_button.dart';
import 'package:bahibo/component/ui/dinamic_icon_combobox.dart';
import 'package:bahibo/component/ui/dinamic_icon_input.dart';
import 'package:bahibo/component/ui/dinamic_icon_textarea.dart';
import 'package:bahibo/component/user_list_page.dart';
import 'package:bahibo/page/dashboard_page.dart';
import 'package:bahibo/page/live/live_preview_page.dart';
import 'package:bahibo/page/productDetailSeller.dart' as seller_detail;
import 'package:bahibo/services/app_api_client.dart';
import 'package:bahibo/services/app_auth_service.dart';
import 'package:bahibo/services/catalog_api_service.dart';
import 'package:bahibo/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

enum _EditableProfileImageTarget { avatar, cover }

class _SelectedProductImage {
  const _SelectedProductImage.local(this.file) : url = null;
  const _SelectedProductImage.remote(this.url) : file = null;

  final File? file;
  final String? url;
}

class MainNavigationAccountPanel extends StatefulWidget {
  final UserProfileData? profile;

  const MainNavigationAccountPanel({super.key, this.profile});

  @override
  State<MainNavigationAccountPanel> createState() =>
      _MainNavigationAccountPanelState();
}

class _MainNavigationAccountPanelState extends State<MainNavigationAccountPanel>
    with AppPageRefreshMixin<MainNavigationAccountPanel> {
  bool _showEntrySkeleton = true;
  final AppAuthService _authService = AppAuthService();
  final CatalogApiService _catalogApiService = CatalogApiService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _searchController = TextEditingController();
  File? _avatarImageFile;
  File? _coverImageFile;
  final List<Map<String, dynamic>> _customStudioProducts = [];
  final Map<String, Map<String, dynamic>> _productOverrides = {};
  String _searchQuery = '';
  String _studioName = '';
  String _studioAddress = 'Antananarivo, Madagascar';
  String _studioDescription = '';
  bool _isSellerCertified = false;
  bool _isSubmittingSellerCertificationRequest = false;
  String _sellerVerificationRequestStatus = 'NONE';

  UserProfileData get profile => widget.profile ?? defaultSellerProfileData();

  List<Map<String, dynamic>> get _catalogProducts => [
    ...profile.products.map((product) {
      final baseProduct = Map<String, dynamic>.from(product);
      final productId = (baseProduct['id'] ?? '').toString();
      final override = _productOverrides[productId];
      if (override == null) {
        return baseProduct;
      }

      return Map<String, dynamic>.from(override);
    }),
    ..._customStudioProducts,
  ];

  List<Map<String, dynamic>> get _filteredProducts {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return _catalogProducts;
    }

    return _catalogProducts.where((product) {
      final title = (product['title'] ?? '').toString().toLowerCase();
      final category = (product['category'] ?? '').toString().toLowerCase();
      return title.contains(query) || category.contains(query);
    }).toList();
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

  int _metricValueByLabel(String metricLabel) {
    return switch (metricLabel) {
      'Abonnes' => _metricCountValue(profile.followerCount),
      'Vues profil' => _metricCountValue(profile.visitorCount),
      'Likes total' => _metricCountValue(profile.totalLikesCount),
      'Produits' => _metricCountValue(profile.productCount),
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
    if (metricLabel == 'Produits') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductListPage(
            title: 'Produits',
            products: _catalogProducts,
            detailPageBuilder: (product) =>
                seller_detail.ProductDetailPage(product: product),
          ),
        ),
      );
      return;
    }

    final title = switch (metricLabel) {
      'Abonnes' => 'Abonnes',
      'Vues profil' => 'Vues profil',
      'Likes total' => 'Likes total',
      _ => metricLabel,
    };

    try {
      final users = await _fetchMetricUsers(metricLabel: metricLabel);

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserListPage(
            title: title,
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

  Future<void> _openFullDashboard() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudioDashboardPage(
          studioName: _resolvedStudioName,
          products: _catalogProducts,
          followerCount: profile.followerCount,
          visitorCount: profile.visitorCount,
          totalLikesCount: profile.totalLikesCount,
        ),
      ),
    );
  }

  Future<void> _showMissingProductFieldsDialog(BuildContext dialogContext) {
    final theme = Theme.of(dialogContext);

    return showDialog<void>(
      context: dialogContext,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  color: theme.colorScheme.onErrorContainer,
                  size: 30,
                ),
              ),
              const SizedBox(height: 14),
              const Text('Champs incomplets', textAlign: TextAlign.center),
            ],
          ),
          content: const Text(
            'Tous les champs doivent etre remplis et le prix doit etre superieur a 0 avant de publier le produit.',
            textAlign: TextAlign.center,
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: DynamicIconButton(
                text: 'Compris',
                icon: const Icon(Icons.check_rounded, size: 18),
                onPressed: () => Navigator.of(context).pop(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _showPublishProductConfirmationDialog(
    BuildContext dialogContext, {
    required String productName,
  }) async {
    final theme = Theme.of(dialogContext);

    final confirmed = await showDialog<bool>(
      context: dialogContext,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.inventory_2_rounded,
                  color: theme.colorScheme.primary,
                  size: 30,
                ),
              ),
              const SizedBox(height: 14),
              const Text('Publier ce produit ?', textAlign: TextAlign.center),
            ],
          ),
          content: Text(
            'Le produit "$productName" sera ajoute au catalogue.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Publier'),
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }

  int? _parseProductPrice(String rawValue) {
    final digits = rawValue.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return null;
    }

    return int.tryParse(digits);
  }

  String _formatPriceDigits(String digits) {
    if (digits.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      buffer.write(digits[index]);
      final remaining = digits.length - index - 1;
      if (remaining > 0 && remaining % 3 == 0) {
        buffer.write(' ');
      }
    }

    return buffer.toString();
  }

  String get _resolvedStudioName {
    final sanitizedStudioName = _sanitizeDisplayText(_studioName);
    if (sanitizedStudioName.isNotEmpty) {
      return sanitizedStudioName;
    }

    final sanitizedProfileName = _sanitizeDisplayText(profile.name);
    return sanitizedProfileName.isEmpty ? 'Boutique' : sanitizedProfileName;
  }

  String _sanitizeDisplayText(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '""' || trimmed == "''") {
      return '';
    }

    final withoutDoubleQuotes = trimmed.replaceAll('"', '');
    final withoutQuotes = withoutDoubleQuotes.replaceAll("'", '');
    return withoutQuotes.trim();
  }

  @override
  void initState() {
    super.initState();
    initializePageRefresh();
    _hydrateStudioFields();
    _syncSellerVerificationState();
    _searchController.addListener(_handleSearchChanged);
    Future.delayed(const Duration(milliseconds: 240), () {
      if (!mounted) return;
      setState(() => _showEntrySkeleton = false);
    });
  }

  @override
  void didUpdateWidget(covariant MainNavigationAccountPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.profile != widget.profile && widget.profile != null) {
      _hydrateStudioFields(forceFromProfile: true);
      _syncSellerVerificationState();
    }
  }

  void _syncSellerVerificationState() {
    _isSellerCertified = profile.isSellerCertified;
    _sellerVerificationRequestStatus = profile.sellerVerificationRequestStatus;
  }

  void _handleSearchChanged() {
    final nextQuery = _searchController.text;
    if (nextQuery == _searchQuery) return;
    setState(() => _searchQuery = nextQuery);
  }

  void _hydrateStudioFields({bool forceFromProfile = false}) {
    final sanitizedProfileName = _sanitizeDisplayText(profile.name);
    final sanitizedProfileHeadline = _sanitizeDisplayText(profile.headline);
    final sanitizedProfileDescription = profile.about.trim();

    _studioName = _sanitizeDisplayText(_studioName);
    if (forceFromProfile || _studioName.isEmpty) {
      _studioName = sanitizedProfileName;
    }
    if (forceFromProfile || _studioAddress.trim().isEmpty) {
      _studioAddress = sanitizedProfileHeadline.isNotEmpty
          ? sanitizedProfileHeadline
          : _studioAddress;
    }
    if (forceFromProfile || _studioDescription.isEmpty) {
      _studioDescription = sanitizedProfileDescription.isNotEmpty
          ? sanitizedProfileDescription
          : _studioDescription;
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    disposePageRefresh();
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

  Future<void> _submitSellerCertificationRequest() async {
    if (_isSubmittingSellerCertificationRequest || _isSellerCertified) {
      return;
    }

    if (_sellerVerificationRequestStatus == 'PENDING') {
      return;
    }

    final dialogTheme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Demander la certification'),
          content: const Text(
            'Envoyer une demande pour que l\'administrateur verifie et valide la certification de votre boutique ?',
          ),
          actions: [
            DynamicIconButton(
              text: 'Annuler',
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              expanded: false,
              backgroundColor: dialogTheme.colorScheme.surfaceContainerHighest,
              foregroundColor: dialogTheme.colorScheme.onSurface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              borderRadius: 18,
            ),
            DynamicIconButton(
              text: 'Envoyer',
              icon: const Icon(Icons.workspace_premium_outlined, size: 18),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              expanded: false,
              backgroundColor: dialogTheme.colorScheme.primary,
              foregroundColor: dialogTheme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              borderRadius: 18,
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isSubmittingSellerCertificationRequest = true;
    });

    try {
      final updatedProfile = await _authService
          .submitSellerVerificationRequest();

      if (!mounted) {
        return;
      }

      setState(() {
        _isSellerCertified =
            updatedProfile['isSellerCertified'] as bool? ?? _isSellerCertified;
        _sellerVerificationRequestStatus =
            (updatedProfile['sellerVerificationRequestStatus'] as String?)
                ?.trim() ??
            'PENDING';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Demande de certification envoyee. Un administrateur doit maintenant la valider.',
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
        setState(() {
          _isSubmittingSellerCertificationRequest = false;
        });
      }
    }
  }

  Widget _buildSellerCertificationCard(
    ThemeData theme,
    Color panelColor,
    Color mutedColor,
  ) {
    final isPending = _sellerVerificationRequestStatus == 'PENDING';
    final isRejected = _sellerVerificationRequestStatus == 'REJECTED';

    final title = _isSellerCertified
        ? 'Boutique certifiee'
        : isPending
        ? 'Certification en attente'
        : isRejected
        ? 'Demande a renvoyer'
        : 'Certification vendeur';

    final description = _isSellerCertified
        ? 'Votre boutique a deja ete validee par l\'administration et le badge vendeur certifie est actif.'
        : isPending
        ? 'Votre demande est en attente. L\'administrateur doit verifier votre boutique avant d\'activer le badge vendeur certifie.'
        : isRejected
        ? 'Votre precedente demande n\'a pas encore ete retenue. Vous pouvez renvoyer une nouvelle demande de certification.'
        : 'Par defaut, une boutique n\'est pas certifiee. Envoyez une demande pour que l\'administrateur valide votre certification.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: mutedColor,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: DynamicIconButton(
              text: _isSellerCertified
                  ? 'Certification active'
                  : isPending
                  ? 'Demande en attente'
                  : isRejected
                  ? 'Renvoyer la demande'
                  : 'Demander la certification',
              icon: _isSubmittingSellerCertificationRequest
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.1,
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : Icon(
                      _isSellerCertified
                          ? Icons.verified_rounded
                          : isRejected
                          ? Icons.refresh_rounded
                          : Icons.workspace_premium_outlined,
                      size: 18,
                    ),
              onPressed:
                  (_isSellerCertified ||
                      isPending ||
                      _isSubmittingSellerCertificationRequest)
                  ? null
                  : _submitSellerCertificationRequest,
              backgroundColor: (_isSellerCertified || isPending)
                  ? theme.colorScheme.primary.withValues(alpha: 0.72)
                  : theme.colorScheme.primary,
              foregroundColor: Colors.white,
              borderRadius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickProfileImage(
    _EditableProfileImageTarget target,
    ImageSource source,
  ) async {
    final file = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1800,
    );
    if (file == null || !mounted) return;

    setState(() {
      if (target == _EditableProfileImageTarget.avatar) {
        _avatarImageFile = File(file.path);
      } else {
        _coverImageFile = File(file.path);
      }
    });
  }

  Future<void> _showImageSourceSheet(_EditableProfileImageTarget target) async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Prendre une photo'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _pickProfileImage(target, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choisir dans la galerie'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _pickProfileImage(target, ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showIdentityEditor() async {
    final nameController = TextEditingController(text: _studioName);
    final addressController = TextEditingController(text: _studioAddress);
    final descriptionController = TextEditingController(
      text: _studioDescription,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final accentColor = _accentColor(theme);
        final inputPanelColor = _backgroundColor(theme);
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: Container(
            decoration: _surfaceDecoration(theme, radius: 28, tinted: true),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Modifier la boutique',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                DynamicIconInput(
                  controller: nameController,
                  primary: accentColor,
                  panelColor: inputPanelColor,
                  borderColor: accentColor.withOpacity(0.12),
                  hintText: 'Nom boutique',
                  leadingIcon: Icon(
                    Icons.storefront_outlined,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 12),
                DynamicIconInput(
                  controller: addressController,
                  primary: accentColor,
                  panelColor: inputPanelColor,
                  borderColor: accentColor.withOpacity(0.12),
                  hintText: 'Adresse',
                  leadingIcon: Icon(
                    Icons.location_on_outlined,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 12),
                DynamicIconTextArea(
                  controller: descriptionController,
                  primary: accentColor,
                  panelColor: inputPanelColor,
                  borderColor: accentColor.withValues(alpha: 0.12),
                  labelText: 'Description',
                  hintText: 'Description de la boutique',
                  leadingIcon: Icon(Icons.notes_rounded, color: accentColor),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        final sanitizedStudioName = _sanitizeDisplayText(
                          nameController.text,
                        );
                        if (sanitizedStudioName.isNotEmpty) {
                          _studioName = sanitizedStudioName;
                        }
                        if (addressController.text.trim().isNotEmpty) {
                          _studioAddress = addressController.text.trim();
                        }
                        if (descriptionController.text.trim().isNotEmpty) {
                          _studioDescription = descriptionController.text
                              .trim();
                        }
                      });
                      Navigator.of(sheetContext).pop();
                    },
                    child: const Text('Enregistrer'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCreateProductSheet({
    Map<String, dynamic>? initialProduct,
  }) async {
    final isEditingProduct = initialProduct != null;
    final initialImageUrls =
        ((initialProduct?['images'] as List?)
            ?.whereType<String>()
            .where((imageUrl) => imageUrl.trim().isNotEmpty)
            .toList() ??
        <String>[]);
    if (initialImageUrls.isEmpty) {
      final fallbackThumbnail = (initialProduct?['thumbnail'] ?? '').toString();
      if (fallbackThumbnail.trim().isNotEmpty) {
        initialImageUrls.add(fallbackThumbnail);
      }
    }
    final nameController = TextEditingController(
      text: (initialProduct?['title'] ?? '').toString(),
    );
    final categoryController = TextEditingController(
      text: (initialProduct?['category'] ?? '').toString(),
    );
    final priceController = TextEditingController(
      text: initialProduct?['price'] == null
          ? ''
          : _formatPriceDigits(
              ((initialProduct?['price'] as num?)?.round() ?? 0).toString(),
            ),
    );
    final descriptionController = TextEditingController(
      text: (initialProduct?['description'] ?? '').toString(),
    );
    String availability = (initialProduct?['isAvailable'] as bool? ?? true)
        ? 'Disponible'
        : 'Rupture';
    String productCondition = 'Neuf';
    var isPublishingProduct = false;
    var isUploadDialogVisible = false;
    BuildContext? uploadDialogContext;
    Completer<void>? uploadDialogClosedCompleter;
    final productImages = initialImageUrls
        .map(_SelectedProductImage.remote)
        .toList();
    var isFormattingPrice = false;

    void formatPriceInput() {
      if (isFormattingPrice) {
        return;
      }

      final digits = priceController.text.replaceAll(RegExp(r'\D'), '');
      final formatted = _formatPriceDigits(digits);
      if (formatted == priceController.text) {
        return;
      }

      isFormattingPrice = true;
      priceController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
      isFormattingPrice = false;
    }

    priceController.addListener(formatPriceInput);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final accentColor = _accentColor(theme);
        final panelColor = _backgroundColor(theme);

        void showUploadProgressDialog() {
          if (isUploadDialogVisible || !sheetContext.mounted) {
            return;
          }

          isUploadDialogVisible = true;
          uploadDialogClosedCompleter = Completer<void>();
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            useRootNavigator: true,
            builder: (dialogContext) {
              uploadDialogContext = dialogContext;
              return PopScope(
                canPop: false,
                child: AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: accentColor),
                      const SizedBox(height: 18),
                      Text(
                        isEditingProduct
                            ? 'Mise a jour du produit en cours'
                            : 'Upload du produit en cours',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Les images sont en cours d\'envoi. Veuillez patienter.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.appColors.mutedText),
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        borderRadius: BorderRadius.circular(999),
                        color: accentColor,
                        minHeight: 7,
                      ),
                    ],
                  ),
                ),
              );
            },
          ).whenComplete(() {
            isUploadDialogVisible = false;
            uploadDialogContext = null;
            if (uploadDialogClosedCompleter?.isCompleted == false) {
              uploadDialogClosedCompleter?.complete();
            }
            uploadDialogClosedCompleter = null;
          });
        }

        Future<void> closeUploadProgressDialog() async {
          if (!isUploadDialogVisible) {
            return;
          }

          final dialogContext = uploadDialogContext;
          final closedCompleter = uploadDialogClosedCompleter;
          if (dialogContext == null || closedCompleter == null) {
            return;
          }

          Navigator.of(dialogContext, rootNavigator: true).pop();
          await closedCompleter.future;
        }

        Future<void> pickCameraProductImage() async {
          final file = await _imagePicker.pickImage(
            source: ImageSource.camera,
            imageQuality: 85,
            maxWidth: 1800,
          );
          if (file == null) {
            return;
          }

          productImages.add(_SelectedProductImage.local(File(file.path)));
        }

        Future<void> pickGalleryProductImages() async {
          final files = await _imagePicker.pickMultiImage(
            imageQuality: 85,
            maxWidth: 1800,
          );
          if (files.isEmpty) {
            return;
          }

          productImages.addAll(
            files.map((file) => _SelectedProductImage.local(File(file.path))),
          );
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> chooseProductImage() async {
              if (isPublishingProduct) {
                return;
              }

              await showModalBottomSheet<void>(
                context: context,
                builder: (imageContext) {
                  return SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.photo_camera_outlined),
                          title: const Text('Prendre une photo'),
                          onTap: () async {
                            Navigator.of(imageContext).pop();
                            await pickCameraProductImage();
                            setModalState(() {});
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.photo_library_outlined),
                          title: const Text('Choisir plusieurs photos'),
                          onTap: () async {
                            Navigator.of(imageContext).pop();
                            await pickGalleryProductImages();
                            setModalState(() {});
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            }

            Future<void> replaceProductImage(int index) async {
              if (isPublishingProduct) {
                return;
              }

              final file = await _imagePicker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 85,
                maxWidth: 1800,
              );
              if (file == null) {
                return;
              }

              setModalState(() {
                productImages[index] = _SelectedProductImage.local(
                  File(file.path),
                );
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Container(
                decoration: _surfaceDecoration(theme, radius: 28, tinted: true),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.92,
                ),
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
                child: AbsorbPointer(
                  absorbing: isPublishingProduct,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 5,
                            decoration: BoxDecoration(
                              color: theme.dividerColor,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          isEditingProduct
                              ? 'Modifier le produit'
                              : 'Creer un produit',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isEditingProduct
                              ? 'Mets a jour les informations principales du produit avant validation.'
                              : 'Renseigne les informations principales du produit avant publication.',
                          style: TextStyle(color: theme.appColors.mutedText),
                        ),
                        if (isPublishingProduct) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.16),
                              ),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.1,
                                    color: accentColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Publication du produit en cours. L\'image est en cours d\'upload.',
                                    style: TextStyle(
                                      color: accentColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        DynamicIconInput(
                          controller: nameController,
                          primary: accentColor,
                          panelColor: panelColor,
                          borderColor: accentColor.withValues(alpha: 0.12),
                          hintText: 'Nom produit',
                          leadingIcon: Icon(
                            Icons.inventory_2_outlined,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DynamicIconInput(
                          controller: categoryController,
                          primary: accentColor,
                          panelColor: panelColor,
                          borderColor: accentColor.withValues(alpha: 0.12),
                          hintText: 'Categorie',
                          leadingIcon: Icon(
                            Icons.category_outlined,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DynamicIconInput(
                          controller: priceController,
                          primary: accentColor,
                          panelColor: panelColor,
                          borderColor: accentColor.withValues(alpha: 0.12),
                          hintText: 'Prix',
                          keyboardType: const TextInputType.numberWithOptions(),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          leadingIcon: Icon(
                            Icons.payments_outlined,
                            color: accentColor,
                          ),
                          trailingIcon: Text(
                            'MGA',
                            style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          trailingSize: 34,
                        ),
                        const SizedBox(height: 12),
                        DynamicIconComboBox<String>(
                          value: availability,
                          items: const [
                            DropdownMenuItem(
                              value: 'Disponible',
                              child: Text('Disponible'),
                            ),
                            DropdownMenuItem(
                              value: 'Rupture',
                              child: Text('Rupture'),
                            ),
                            DropdownMenuItem(
                              value: 'Precommande',
                              child: Text('Precommande'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setModalState(() {
                              availability = value;
                            });
                          },
                          primary: accentColor,
                          panelColor: panelColor,
                          borderColor: accentColor.withValues(alpha: 0.12),
                          hintText: 'Etat',
                          leadingIcon: Icon(
                            Icons.sell_outlined,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DynamicIconComboBox<String>(
                          value: productCondition,
                          items: const [
                            DropdownMenuItem(
                              value: 'Neuf',
                              child: Text('Neuf'),
                            ),
                            DropdownMenuItem(
                              value: 'Occasion',
                              child: Text('Occasion'),
                            ),
                            DropdownMenuItem(
                              value: 'Reconditionne',
                              child: Text('Reconditionne'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setModalState(() {
                              productCondition = value;
                            });
                          },
                          primary: accentColor,
                          panelColor: panelColor,
                          borderColor: accentColor.withValues(alpha: 0.12),
                          hintText: 'Etat du produit',
                          leadingIcon: Icon(
                            Icons.verified_outlined,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DynamicIconTextArea(
                          controller: descriptionController,
                          primary: accentColor,
                          panelColor: panelColor,
                          borderColor: accentColor.withValues(alpha: 0.12),
                          labelText: 'Description',
                          hintText: 'Description du produit',
                          leadingIcon: Icon(
                            Icons.notes_rounded,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Photo du produit',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Selection multiple depuis la galerie ou ajout progressif photo par photo.',
                          style: TextStyle(color: theme.appColors.mutedText),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: panelColor,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: theme.appColors.inputBorder,
                            ),
                          ),
                          child: productImages.isEmpty
                              ? Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: chooseProductImage,
                                    borderRadius: BorderRadius.circular(18),
                                    child: SizedBox(
                                      height: 144,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_photo_alternate_outlined,
                                            color: accentColor,
                                            size: 34,
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            'Ajouter des photos produit',
                                            style: TextStyle(
                                              color: accentColor,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Mode multi-selection',
                                            style: TextStyle(
                                              color: theme.appColors.mutedText,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: accentColor.withValues(
                                              alpha: 0.14,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            '${productImages.length} photo${productImages.length > 1 ? 's' : ''}',
                                            style: TextStyle(
                                              color: accentColor,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        TextButton.icon(
                                          onPressed: isPublishingProduct
                                              ? null
                                              : chooseProductImage,
                                          icon: const Icon(
                                            Icons.add_photo_alternate_outlined,
                                          ),
                                          label: const Text('Ajouter'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final itemWidth =
                                            (constraints.maxWidth - 20) / 3;

                                        return Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: List.generate(productImages.length, (
                                            index,
                                          ) {
                                            final image = productImages[index];

                                            return SizedBox(
                                              width: itemWidth.clamp(
                                                92.0,
                                                140.0,
                                              ),
                                              height: itemWidth.clamp(
                                                92.0,
                                                140.0,
                                              ),
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                    child: image.file != null
                                                        ? Image.file(
                                                            image.file!,
                                                            fit: BoxFit.cover,
                                                          )
                                                        : AppNetworkImage(
                                                            imageUrl:
                                                                image.url ?? '',
                                                            fit: BoxFit.cover,
                                                          ),
                                                  ),
                                                  Positioned(
                                                    top: 8,
                                                    left: 8,
                                                    child: Row(
                                                      children: [
                                                        _buildProductImageAction(
                                                          icon: Icons
                                                              .edit_rounded,
                                                          onTap:
                                                              isPublishingProduct
                                                              ? () {}
                                                              : () =>
                                                                    replaceProductImage(
                                                                      index,
                                                                    ),
                                                        ),
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        _buildProductImageAction(
                                                          icon: Icons
                                                              .delete_outline_rounded,
                                                          onTap:
                                                              isPublishingProduct
                                                              ? () {}
                                                              : () {
                                                                  setModalState(() {
                                                                    productImages
                                                                        .removeAt(
                                                                          index,
                                                                        );
                                                                  });
                                                                },
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: DynamicIconButton(
                            text: isPublishingProduct
                                ? (isEditingProduct
                                      ? 'Mise a jour en cours...'
                                      : 'Publication en cours...')
                                : (isEditingProduct
                                      ? 'Mettre a jour le produit'
                                      : 'Publier le produit'),
                            icon: isPublishingProduct
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: theme.colorScheme.onPrimary,
                                    ),
                                  )
                                : const Icon(
                                    Icons.check_circle_outline,
                                    color: Colors.white,
                                  ),
                            onPressed: isPublishingProduct
                                ? null
                                : () async {
                                    final productName = nameController.text
                                        .trim();
                                    final productCategory = categoryController
                                        .text
                                        .trim();
                                    final productDescription =
                                        descriptionController.text.trim();
                                    final parsedPrice = _parseProductPrice(
                                      priceController.text,
                                    );

                                    if (productName.isEmpty ||
                                        productCategory.isEmpty ||
                                        parsedPrice == null ||
                                        parsedPrice <= 0 ||
                                        productDescription.isEmpty ||
                                        productImages.isEmpty) {
                                      await _showMissingProductFieldsDialog(
                                        sheetContext,
                                      );
                                      return;
                                    }

                                    final shouldPublish = isEditingProduct
                                        ? true
                                        : await _showPublishProductConfirmationDialog(
                                            sheetContext,
                                            productName: productName,
                                          );

                                    if (!shouldPublish ||
                                        !mounted ||
                                        !sheetContext.mounted) {
                                      return;
                                    }

                                    String? successMessage;
                                    String? errorMessage;
                                    var shouldCloseSheetAfterSuccess = false;

                                    try {
                                      setModalState(() {
                                        isPublishingProduct = true;
                                      });
                                      showUploadProgressDialog();

                                      final localImageFiles = <File>[];
                                      final imageOrder = productImages.map((
                                        image,
                                      ) {
                                        if (image.file != null) {
                                          final uploadIndex =
                                              localImageFiles.length;
                                          localImageFiles.add(image.file!);
                                          return '__upload__$uploadIndex';
                                        }

                                        return image.url ?? '';
                                      }).toList();

                                      final createdProduct = isEditingProduct
                                          ? await _catalogApiService
                                                .updateProduct(
                                                  productId:
                                                      (initialProduct['id'] ??
                                                              '')
                                                          .toString(),
                                                  title: productName,
                                                  description:
                                                      productDescription,
                                                  priceAmount: parsedPrice,
                                                  categoryName: productCategory,
                                                  imageFiles: localImageFiles,
                                                  imageOrder: imageOrder,
                                                  isAvailable:
                                                      availability ==
                                                      'Disponible',
                                                )
                                          : await _catalogApiService
                                                .createProduct(
                                                  title: productName,
                                                  description:
                                                      productDescription,
                                                  priceAmount: parsedPrice,
                                                  categoryName: productCategory,
                                                  imageFiles: localImageFiles,
                                                  imageOrder: imageOrder,
                                                );

                                      if (!mounted || !sheetContext.mounted) {
                                        return;
                                      }

                                      setState(() {
                                        _upsertProductInState({
                                          ...createdProduct,
                                          'description': productDescription,
                                          'status': availability,
                                          'condition': productCondition,
                                          'likesCount':
                                              (initialProduct?['likesCount']
                                                      as num?)
                                                  ?.toInt() ??
                                              0,
                                          'isLocalFile': false,
                                        });
                                      });

                                      successMessage = isEditingProduct
                                          ? '$productName mis a jour dans votre catalogue.'
                                          : '$productName ajoute au catalogue.';
                                      shouldCloseSheetAfterSuccess = true;
                                    } on AppApiException catch (error) {
                                      if (!mounted || !sheetContext.mounted) {
                                        return;
                                      }

                                      errorMessage = error.message;
                                    } finally {
                                      await closeUploadProgressDialog();
                                      if (sheetContext.mounted) {
                                        setModalState(() {
                                          isPublishingProduct = false;
                                        });
                                      }

                                      if (shouldCloseSheetAfterSuccess &&
                                          sheetContext.mounted) {
                                        Navigator.of(sheetContext).pop();
                                      }

                                      if (mounted && successMessage != null) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(successMessage),
                                          ),
                                        );
                                      } else if (mounted &&
                                          errorMessage != null) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text(errorMessage)),
                                        );
                                      }
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    priceController.removeListener(formatPriceInput);
  }

  Future<void> _openLivePreview(String title, String category) async {
    Map<String, dynamic>? liveInfo;
    var liveStarted = false;

    try {
      liveInfo = await _catalogApiService.startCurrentUserLive(
        title: title,
        category: category,
      );
      liveStarted = true;

      final liveUrl = liveInfo['url']?.toString().trim() ?? '';
      final liveToken = liveInfo['token']?.toString().trim() ?? '';
      final roomName = liveInfo['roomName']?.toString().trim() ?? '';

      if (liveUrl.isEmpty || liveToken.isEmpty || roomName.isEmpty) {
        throw AppApiException(
          'La configuration LiveKit du serveur est incomplete.',
        );
      }

      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => LivePreviewPage(
            title: liveInfo?['title']?.toString() ?? title,
            category: liveInfo?['category']?.toString() ?? category,
            liveUrl: liveUrl,
            liveToken: liveToken,
            roomName: roomName,
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
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de demarrer le live pour le moment.'),
        ),
      );
    } finally {
      if (liveStarted) {
        try {
          await _catalogApiService.stopCurrentUserLive();
        } catch (_) {}
      }
    }

    if (!mounted) {
      return;
    }
  }

  Widget _buildProductImageAction({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Theme.of(context).appColors.overlaySurface,
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).appColors.overlayBorder,
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: Theme.of(context).appColors.heroForeground,
          ),
        ),
      ),
    );
  }

  Future<void> _showLaunchLiveSheet() async {
    final titleController = TextEditingController(
      text: '$_resolvedStudioName en direct',
    );
    final categoryController = TextEditingController(
      text: 'Presentation produit',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final accentColor = _accentColor(theme);
        final panelColor = _backgroundColor(theme);
        final liveColor = theme.colorScheme.secondary;

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: Container(
            decoration: _surfaceDecoration(theme, radius: 28, tinted: true),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: liveColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.live_tv_rounded, color: liveColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Creer un live',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Prepare ton direct et rends-le visible tout de suite.',
                            style: TextStyle(color: theme.appColors.mutedText),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                DynamicIconInput(
                  controller: titleController,
                  primary: accentColor,
                  panelColor: panelColor,
                  borderColor: accentColor.withOpacity(0.12),
                  hintText: 'Titre du live',
                  leadingIcon: Icon(
                    Icons.mic_external_on_outlined,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 12),
                DynamicIconInput(
                  controller: categoryController,
                  primary: accentColor,
                  panelColor: panelColor,
                  borderColor: accentColor.withOpacity(0.12),
                  hintText: 'Theme ou categorie',
                  leadingIcon: Icon(Icons.sell_outlined, color: accentColor),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: liveColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: liveColor.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: liveColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Le live sera lance immediatement apres validation.',
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final liveTitle = titleController.text.trim();
                      final liveCategory = categoryController.text.trim();

                      if (liveTitle.isEmpty) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Ajoute un titre pour lancer le live.',
                            ),
                          ),
                        );
                        return;
                      }

                      final resolvedCategory = liveCategory.isEmpty
                          ? 'Live boutique'
                          : liveCategory;

                      Navigator.of(sheetContext).pop();
                      _openLivePreview(liveTitle, resolvedCategory);
                    },
                    icon: const Icon(Icons.wifi_tethering_rounded),
                    label: const Text('Demarrer le live'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _upsertProductInState(Map<String, dynamic> product) {
    final productId = (product['id'] ?? '').toString();
    final normalizedProduct = Map<String, dynamic>.from(product);

    final existingCustomIndex = _customStudioProducts.indexWhere(
      (item) => (item['id'] ?? '').toString() == productId,
    );
    if (existingCustomIndex >= 0) {
      _customStudioProducts[existingCustomIndex] = normalizedProduct;
      return;
    }

    final isProfileProduct = profile.products.any(
      (item) => (item['id'] ?? '').toString() == productId,
    );

    if (isProfileProduct) {
      _productOverrides[productId] = normalizedProduct;
      return;
    }

    _customStudioProducts.insert(0, normalizedProduct);
  }

  Color _backgroundColor(ThemeData theme) {
    return theme.appColors.backgroundBase;
  }

  Color _panelColor(ThemeData theme) {
    return theme.appColors.panelBackground;
  }

  Color _mutedColor(ThemeData theme) {
    return theme.appColors.mutedText;
  }

  Color _accentColor(ThemeData theme) {
    return theme.colorScheme.primary;
  }

  Color _accentSurfaceColor(ThemeData theme) {
    if (theme.brightness == Brightness.dark) {
      return theme.colorScheme.primary.withValues(alpha: 0.14);
    }

    return theme.appColors.panelMuted;
  }

  Color _supportAccentColor(ThemeData theme) {
    return theme.colorScheme.secondary;
  }

  Color _panelBorderColor(ThemeData theme) {
    final base = theme.appColors.borderColor;
    return theme.brightness == Brightness.dark
        ? base.withValues(alpha: 0.74)
        : base.withValues(alpha: 0.9);
  }

  List<BoxShadow> _panelShadow(ThemeData theme) {
    if (theme.brightness == Brightness.dark) {
      return [
        BoxShadow(
          color: theme.appColors.scrimStrong.withValues(alpha: 0.24),
          blurRadius: 26,
          offset: const Offset(0, 14),
        ),
      ];
    }

    return [
      BoxShadow(
        color: theme.appColors.scrimSoft.withValues(alpha: 0.08),
        blurRadius: 18,
        offset: const Offset(0, 10),
      ),
    ];
  }

  BoxDecoration _surfaceDecoration(
    ThemeData theme, {
    double radius = 24,
    bool tinted = false,
  }) {
    final panelColor = _panelColor(theme);
    final backgroundColor = _backgroundColor(theme);
    final accentColor = _accentColor(theme);
    final topColor = tinted
        ? Color.lerp(
            panelColor,
            accentColor,
            theme.brightness == Brightness.dark ? 0.08 : 0.05,
          )!
        : Color.lerp(panelColor, backgroundColor, 0.18)!;

    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [topColor, panelColor],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _panelBorderColor(theme)),
      boxShadow: _panelShadow(theme),
    );
  }

  Widget _buildBackgroundAccent({
    required Alignment alignment,
    required List<Color> colors,
    required double size,
  }) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: colors),
          ),
        ),
      ),
    );
  }

  List<_RankedProductEntry> _buildTopProducts() {
    final result = <_RankedProductEntry>[];
    final products = [..._catalogProducts];
    products.sort((left, right) {
      final leftLikes = (left['likesCount'] as num?)?.toInt() ?? 0;
      final rightLikes = (right['likesCount'] as num?)?.toInt() ?? 0;
      return rightLikes.compareTo(leftLikes);
    });

    for (var index = 0; index < products.length; index++) {
      final product = products[index];
      final likes = (product['likesCount'] as num?)?.toInt() ?? 0;
      result.add(
        _RankedProductEntry(
          rank: index + 1,
          title: (product['title'] ?? 'Produit').toString(),
          category: (product['category'] ?? 'Catalogue').toString(),
          imageUrl: (product['thumbnail'] ?? '').toString(),
          price: (product['price'] ?? 0).toString(),
          likes: likes,
          growth: likes > 0 ? '+0%' : '--',
        ),
      );
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = _backgroundColor(theme);
    final panelColor = _panelColor(theme);
    final mutedColor = _mutedColor(theme);
    final accentColor = _accentColor(theme);
    final supportAccentColor = _supportAccentColor(theme);
    final filteredProducts = _filteredProducts;
    final topProducts = _buildTopProducts();

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          _buildBackgroundAccent(
            alignment: const Alignment(-1.1, -0.92),
            size: 240,
            colors: [
              accentColor.withValues(alpha: isDark ? 0.12 : 0.1),
              Colors.transparent,
            ],
          ),
          _buildBackgroundAccent(
            alignment: const Alignment(1.05, -0.2),
            size: 220,
            colors: [
              supportAccentColor.withValues(alpha: isDark ? 0.08 : 0.06),
              Colors.transparent,
            ],
          ),
          RefreshIndicator(
            onRefresh: refreshPageWithDialog,
            child: _showEntrySkeleton
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [SellerProfileSkeleton()],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 120),
                    children: [
                      _buildStudioHero(theme),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildSellerCertificationCard(
                          theme,
                          panelColor,
                          mutedColor,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildMetricsGrid(
                          theme,
                          panelColor,
                          mutedColor,
                          accentColor,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildLaunchLiveButton(
                          theme,
                          accentColor,
                          supportAccentColor,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildDashboardCard(
                          theme,
                          panelColor,
                          mutedColor,
                          accentColor,
                          supportAccentColor,
                        ),
                      ),

                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildTopProductsSection(
                          theme,
                          panelColor,
                          mutedColor,
                          accentColor,
                          topProducts,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildCatalogSection(
                          theme,
                          panelColor,
                          mutedColor,
                          filteredProducts,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildAccountInfoSection(
                          theme,
                          panelColor,
                          mutedColor,
                        ),
                      ),
                    ],
                  ),
          ),
          if (isOffline) const AppOfflineBanner(),
        ],
      ),
    );
  }

  Widget _buildStudioHero(ThemeData theme) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    final heroMinHeight = compact ? 372.0 : 344.0;
    final accentColor = _accentColor(theme);
    final accentSurfaceColor = _accentSurfaceColor(theme);
    final supportAccentColor = _supportAccentColor(theme);

    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(28)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: heroMinHeight),
              child: SizedBox(
                width: double.infinity,
                child: _buildEditableCoverImage(),
              ),
            ),
            Container(
              constraints: BoxConstraints(minHeight: heroMinHeight),
              padding: EdgeInsets.fromLTRB(
                20,
                compact ? 16 : 20,
                20,
                compact ? 16 : 20,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.appColors.scrimSoft,
                    theme.appColors.scrimStrong,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 10 : 12,
                      vertical: compact ? 6 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.appColors.heroSurface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: theme.appColors.heroBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 16,
                          color: theme.appColors.heroForeground,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Account Studio',
                          style: TextStyle(
                            color: theme.appColors.heroForeground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: compact ? 18 : 26),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: theme.appColors.heroSurface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.appColors.heroBorder,
                              ),
                            ),
                            child: _buildEditableAvatar(),
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: _buildImageEditButton(
                              onTap: () => _showImageSourceSheet(
                                _EditableProfileImageTarget.avatar,
                              ),
                              compact: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _studioName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.appColors.heroForeground,
                                fontSize: compact ? 22 : 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: compact ? 4 : 6),
                            Text(
                              _studioAddress,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.appColors.heroForegroundMuted,
                                fontWeight: FontWeight.w500,
                                fontSize: compact ? 13 : 14,
                              ),
                            ),
                            SizedBox(height: compact ? 8 : 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildHeroPill(
                                  icon: _isSellerCertified
                                      ? Icons.verified_rounded
                                      : Icons.storefront_rounded,
                                  label: profile.roleLabel,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 12 : 18),
                  Text(
                    _studioDescription,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.appColors.heroForegroundMuted,
                      height: 1.35,
                      fontSize: compact ? 13 : 14,
                    ),
                  ),
                  SizedBox(height: compact ? 12 : 18),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _showIdentityEditor,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text(
                            'Modifier profil',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.appColors.heroForeground,
                            foregroundColor: theme.colorScheme.onSurface,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                            padding: EdgeInsets.symmetric(
                              vertical: compact ? 10 : 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showCreateProductSheet,
                          icon: const Icon(Icons.add_box_outlined, size: 18),
                          label: const Text(
                            'Creer produit',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.appColors.heroForeground,
                            backgroundColor: supportAccentColor.withValues(
                              alpha: theme.brightness == Brightness.dark
                                  ? 0.22
                                  : 0.14,
                            ),
                            side: BorderSide(
                              color: supportAccentColor.withValues(
                                alpha: theme.brightness == Brightness.dark
                                    ? 0.42
                                    : 0.24,
                              ),
                            ),
                            padding: EdgeInsets.symmetric(
                              vertical: compact ? 10 : 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: _buildImageEditButton(
                onTap: () =>
                    _showImageSourceSheet(_EditableProfileImageTarget.cover),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(
    ThemeData theme,
    Color panelColor,
    Color mutedColor,
    Color accentColor,
  ) {
    final supportAccentColor = _supportAccentColor(theme);
    final metrics = [
      _StudioMetric('Abonnes', profile.followerCount, Icons.groups_2_outlined),
      _StudioMetric(
        'Vues profil',
        profile.visitorCount,
        Icons.visibility_outlined,
      ),
      _StudioMetric('Produits', profile.productCount, Icons.storefront),
      _StudioMetric(
        'Likes total',
        profile.totalLikesCount,
        Icons.favorite_outline,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 138,
      ),
      itemBuilder: (context, index) {
        final metric = metrics[index];
        final iconBackground = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.22),
            supportAccentColor.withValues(alpha: 0.12),
          ],
        );
        final isOpenable =
            metric.label == 'Abonnes' ||
            metric.label == 'Vues profil' ||
            metric.label == 'Produits' ||
            metric.label == 'Likes total';

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isOpenable ? () => _openMetricUsers(metric.label) : null,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: _surfaceDecoration(
                theme,
                radius: 22,
                tinted: index.isEven,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: accentColor.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: iconBackground,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(metric.icon, color: accentColor),
                  ),
                  const Spacer(),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      metric.value,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    metric.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: mutedColor,
                      fontWeight: FontWeight.w600,
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

  Widget _buildDashboardCard(
    ThemeData theme,
    Color panelColor,
    Color mutedColor,
    Color accentColor,
    Color supportAccentColor,
  ) {
    final bars = const [0.35, 0.58, 0.47, 0.74, 0.62, 0.85, 0.68];

    final accentSurfaceColor = _accentSurfaceColor(theme);
    final chartBaseColor = theme.brightness == Brightness.dark
        ? supportAccentColor.withValues(alpha: 0.34)
        : accentColor.withValues(alpha: 0.24);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openFullDashboard,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: _surfaceDecoration(theme, tinted: true),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tableau de bord',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cette semaine, la boutique est en hausse de 18%.',
                          style: TextStyle(color: mutedColor),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentSurfaceColor,
                          supportAccentColor.withValues(alpha: 0.18),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '+18%',
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 128,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(bars.length, (index) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  height: 104 * bars[index],
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        accentColor.withValues(alpha: 0.92),
                                        chartBaseColor,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              ['L', 'M', 'M', 'J', 'V', 'S', 'D'][index],
                              style: TextStyle(
                                color: mutedColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLaunchLiveButton(
    ThemeData theme,
    Color accentColor,
    Color supportAccentColor,
  ) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: _surfaceDecoration(theme, radius: 22, tinted: true),
      child: ElevatedButton.icon(
        onPressed: _showLaunchLiveSheet,
        icon: const Icon(Icons.live_tv_rounded, size: 20),
        label: const Text(
          'Lancer un live',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          foregroundColor: theme.colorScheme.onPrimary,
          backgroundColor: accentColor,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          minimumSize: const Size(double.infinity, 58),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: supportAccentColor.withValues(alpha: isDark ? 0.4 : 0.22),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopProductsSection(
    ThemeData theme,
    Color panelColor,
    Color mutedColor,
    Color accentColor,
    List<_RankedProductEntry> topProducts,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _surfaceDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            theme,
            'Top 10 produits likes',
            'Produits reels du studio',
          ),
          const SizedBox(height: 14),
          ...topProducts.take(5).map((product) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    alignment: Alignment.center,
                    child: Text(
                      '#${product.rank}',
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AppNetworkImage(
                      imageUrl: product.imageUrl,
                      width: 64,
                      height: 64,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${product.category} • ${product.price} Ar',
                          style: TextStyle(color: mutedColor),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.favorite_rounded,
                            size: 16,
                            color: theme.appColors.favoriteAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${product.likes}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.growth,
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCatalogSection(
    ThemeData theme,
    Color panelColor,
    Color mutedColor,
    List<Map<String, dynamic>> filteredProducts,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _surfaceDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            theme,
            'Catalogue studio',
            '${filteredProducts.length} resultats',
          ),
          const SizedBox(height: 14),
          if (filteredProducts.isEmpty)
            Text(
              'Aucun produit ne correspond a cette recherche.',
              style: TextStyle(color: mutedColor),
            )
          else
            ...filteredProducts.take(3).map((product) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  children: [
                    ProductCard(
                      product: product,
                      detailPageBuilder: (product) =>
                          seller_detail.ProductDetailPage(product: product),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () =>
                            _showCreateProductSheet(initialProduct: product),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Modifier le produit'),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAccountInfoSection(
    ThemeData theme,
    Color panelColor,
    Color mutedColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _surfaceDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Informations boutique',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _showIdentityEditor,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Modifier'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildInfoRow('Nom', _resolvedStudioName, mutedColor),
          _buildInfoRow('Adresse', _studioAddress, mutedColor),
          _buildInfoRow(
            'Description',
            _studioDescription,
            mutedColor,
            multiline: true,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    Color mutedColor, {
    bool multiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).appColors.inputFill.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _panelBorderColor(Theme.of(context))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: mutedColor, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: multiline ? 3 : 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableCoverImage() {
    if (_coverImageFile != null) {
      return Image.file(_coverImageFile!, fit: BoxFit.cover);
    }

    return AppNetworkImage(imageUrl: profile.coverImageUrl, fit: BoxFit.cover);
  }

  Widget _buildEditableAvatar() {
    if (_avatarImageFile != null) {
      return ClipOval(
        child: Image.file(
          _avatarImageFile!,
          width: 82,
          height: 82,
          fit: BoxFit.cover,
        ),
      );
    }

    return AppCircleNetworkAvatar(
      radius: 41,
      imageUrl: profile.avatarUrl,
      userId: profile.userId,
    );
  }

  Widget _buildImageEditButton({
    required VoidCallback onTap,
    bool compact = false,
  }) {
    final size = compact ? 34.0 : 40.0;
    final accentColor = _accentColor(Theme.of(context));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: accentColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).appColors.heroForegroundMuted,
              width: 2,
            ),
          ),
          child: Icon(
            Icons.photo_camera_rounded,
            size: compact ? 18 : 20,
            color: Theme.of(context).appColors.heroForeground,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroPill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).appColors.heroSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).appColors.heroBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).appColors.heroForeground,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).appColors.heroForeground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, String meta) {
    final accentColor = _accentColor(theme);

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            meta,
            style: TextStyle(color: accentColor, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _StudioMetric {
  final String label;
  final String value;
  final IconData icon;

  const _StudioMetric(this.label, this.value, this.icon);
}

class _RankedProductEntry {
  final int rank;
  final String title;
  final String category;
  final String imageUrl;
  final String price;
  final int likes;
  final String growth;

  const _RankedProductEntry({
    required this.rank,
    required this.title,
    required this.category,
    required this.imageUrl,
    required this.price,
    required this.likes,
    required this.growth,
  });
}
