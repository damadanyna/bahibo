import 'dart:io';
import 'dart:async';
import 'dart:math' as math;

import 'package:banay/component/ProductCard.dart';
import 'package:banay/component/app_network_image.dart';
import 'package:banay/component/app_page_refresh.dart';
import 'package:banay/component/app_page_skeletons.dart';
import 'package:banay/component/product_list_page.dart';
import 'package:banay/component/profile_models.dart';
import 'package:banay/component/seller_profile_page.dart';
import 'package:banay/component/user_profile_page.dart';
import 'package:banay/component/ui/dinamic_icon_button.dart';
import 'package:banay/component/ui/dinamic_icon_checkbox.dart';
import 'package:banay/component/ui/dinamic_icon_combobox.dart';
import 'package:banay/component/ui/dinamic_icon_input.dart';
import 'package:banay/component/ui/dinamic_icon_textarea.dart';
import 'package:banay/component/ui/dinamic_followed_people_h_list.dart';
import 'package:banay/component/ui/seller_certified_badge.dart';
import 'package:banay/component/user_list_page.dart';
import 'package:banay/formatter/product_detail_formatter.dart';
import 'package:banay/localization/banay_localizations.dart';
import 'package:banay/page/private_image_viewer.dart';
import 'package:banay/page/dashboard_page.dart';
import 'package:banay/page/live/live_watch_page.dart';
import 'package:banay/page/live/live_preview_page.dart';
import 'package:banay/page/qa_event_log_page.dart';
import 'package:banay/page/productDetailSeller.dart' as seller_detail;
import 'package:banay/services/app_api_client.dart';
import 'package:banay/services/app_auth_service.dart';
import 'package:banay/services/catalog_api_service.dart';
import 'package:banay/services/product_upload_queue_service.dart';
import 'package:banay/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

enum _EditableProfileImageTarget { avatar, cover }

enum _AccountPanelTab { products, statistics, following }

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
  final CatalogApiService _catalogApiService = CatalogApiService();
  final AppAuthService _authService = AppAuthService();
  final ImagePicker _imagePicker = ImagePicker();
  final ProductUploadQueueService _productUploadQueueService =
      ProductUploadQueueService.instance;
  final TextEditingController _searchController = TextEditingController();

  _AccountPanelTab _selectedTab = _AccountPanelTab.products;
  List<Map<String, dynamic>> _sellerPublishedProducts =
      <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> _customStudioProducts =
      <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> _followedPeople = <Map<String, dynamic>>[];
  final Map<String, Map<String, dynamic>> _productOverrides =
      <String, Map<String, dynamic>>{};
  final Set<String> _productAvailabilityBusy = <String>{};
  final Set<String> _productDeletionBusy = <String>{};
  String _searchQuery = '';
  String _studioName = '';
  String _studioAddress = '';
  String _studioDescription = '';
  bool _showEntrySkeleton = true;
  bool _isLoadingFollowedPeople = true;
  bool _isSavingIdentity = false;
  bool _isSellerCertified = false;
  bool _isSubmittingSellerCertificationRequest = false;
  bool _isUploadingAvatarImage = false;
  bool _isUploadingCoverImage = false;
  String? _sellerVerificationRequestStatus;
  File? _avatarImageFile;
  File? _coverImageFile;

  UserProfileData get profile => widget.profile!;

  Map<String, dynamic> _attachCurrentSellerIdentity(
    Map<String, dynamic> product,
  ) {
    final mergedProduct = Map<String, dynamic>.from(product);
    final seller = Map<String, dynamic>.from(
      (mergedProduct['seller'] as Map?) ?? const <String, dynamic>{},
    );

    seller['name'] = _resolvedStudioName;
    seller['displayName'] = _resolvedStudioName;
    seller['avatarUrl'] = profile.avatarUrl;
    if ((profile.userId ?? '').trim().isNotEmpty) {
      seller['userId'] = profile.userId!.trim();
      seller['id'] = profile.userId!.trim();
    }

    mergedProduct['seller'] = seller;
    mergedProduct['sellerName'] = _resolvedStudioName;
    mergedProduct['sellerAvatarUrl'] = profile.avatarUrl;
    if ((profile.userId ?? '').trim().isNotEmpty) {
      mergedProduct['sellerUserId'] = profile.userId!.trim();
    }

    return mergedProduct;
  }

  List<Map<String, dynamic>> get _catalogProducts {
    final mergedProducts = _sellerPublishedProducts
        .map(_attachCurrentSellerIdentity)
        .toList();

    for (final entry in _productOverrides.entries) {
      final existingIndex = mergedProducts.indexWhere(
        (product) => (product['id'] ?? '').toString() == entry.key,
      );
      if (existingIndex >= 0) {
        mergedProducts[existingIndex] = _attachCurrentSellerIdentity(
          entry.value,
        );
      } else {
        mergedProducts.insert(0, _attachCurrentSellerIdentity(entry.value));
      }
    }

    for (final product in _customStudioProducts.reversed) {
      final productId = (product['id'] ?? '').toString();
      final existingIndex = mergedProducts.indexWhere(
        (item) => (item['id'] ?? '').toString() == productId,
      );
      if (existingIndex >= 0) {
        mergedProducts[existingIndex] = _attachCurrentSellerIdentity(product);
      } else {
        mergedProducts.insert(0, _attachCurrentSellerIdentity(product));
      }
    }

    return mergedProducts;
  }

  List<Map<String, dynamic>> get _filteredProducts {
    final normalizedQuery = _searchQuery.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return _catalogProducts;
    }

    return _catalogProducts.where((product) {
      final title = (product['title'] ?? '').toString().toLowerCase();
      final category = (product['category'] ?? '').toString().toLowerCase();
      final description = (product['description'] ?? '')
          .toString()
          .toLowerCase();

      return title.contains(normalizedQuery) ||
          category.contains(normalizedQuery) ||
          description.contains(normalizedQuery);
    }).toList();
  }

  int _metricCountValue(Object? rawValue) {
    if (rawValue is int) {
      return rawValue;
    }
    if (rawValue is num) {
      return rawValue.toInt();
    }

    return int.tryParse(rawValue?.toString() ?? '') ?? 0;
  }

  int _metricValueByLabel(String metricLabel) {
    return switch (metricLabel) {
      'Abonnes' => _metricCountValue(profile.followerCount),
      'Vues profil' => _metricCountValue(profile.visitorCount),
      'Produits' => _metricCountValue(profile.productCount),
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
      name: name != null && name.isNotEmpty ? name : 'Membre BANAY',
      avatarUrl: avatarUrl,
      subtitle: metricLabel == 'Likes total' && count != null && count > 0
          ? count > 1
                ? 'A laisse $count likes sur vos produits'
                : 'A laisse 1 like sur votre produit'
          : subtitle != null && subtitle.isNotEmpty
          ? subtitle
          : 'Membre de la communaute BANAY',
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

  (String?, String?) _splitStudioAddress(String rawAddress) {
    final normalizedAddress = rawAddress.trim();
    if (normalizedAddress.isEmpty) {
      return (null, null);
    }

    final parts = normalizedAddress
        .split(',')
        .map(_sanitizeDisplayText)
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return (null, null);
    }

    if (parts.length == 1) {
      return (parts.first, null);
    }

    return (parts.first, parts.sublist(1).join(', '));
  }

  @override
  void initState() {
    super.initState();
    initializePageRefresh();
    _seedSellerPublishedProducts();
    _productUploadQueueService.addListener(_handleProductUploadQueueChanged);
    unawaited(_initializeProductUploadQueue());
    _hydrateStudioFields();
    _syncSellerVerificationState();
    _loadSellerPublishedProducts();
    _loadFollowedPeople();
    _searchController.addListener(_handleSearchChanged);
    Future.delayed(const Duration(milliseconds: 240), () {
      if (!mounted) return;
      setState(() => _showEntrySkeleton = false);
    });
  }

  @override
  void didUpdateWidget(covariant MainNavigationAccountPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    final previousAvatarUrl = oldWidget.profile?.avatarUrl ?? '';
    final nextAvatarUrl = widget.profile?.avatarUrl ?? '';
    final previousCoverImageUrl = oldWidget.profile?.coverImageUrl ?? '';
    final nextCoverImageUrl = widget.profile?.coverImageUrl ?? '';

    if (oldWidget.profile != widget.profile && widget.profile != null) {
      _seedSellerPublishedProducts();
      _hydrateStudioFields(forceFromProfile: true);
      _syncSellerVerificationState();
      _loadSellerPublishedProducts();

      if (previousAvatarUrl != nextAvatarUrl) {
        _avatarImageFile = null;
      }
      if (previousCoverImageUrl != nextCoverImageUrl) {
        _coverImageFile = null;
      }
    }
  }

  void _seedSellerPublishedProducts() {
    _sellerPublishedProducts = profile.products
        .map((product) => Map<String, dynamic>.from(product))
        .toList();
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

  Future<void> _loadSellerPublishedProducts() async {
    final sellerProfileId = profile.sellerProfileId?.trim() ?? '';
    if (sellerProfileId.isEmpty) {
      return;
    }

    try {
      final sellerProfile = await _catalogApiService.fetchSellerProfile(
        sellerProfileId,
      );
      final products = (sellerProfile['products'] as List?)
          ?.whereType<Map>()
          .map((product) => Map<String, dynamic>.from(product))
          .toList();

      if (!mounted || products == null) {
        return;
      }

      setState(() {
        _sellerPublishedProducts = products;
      });
    } catch (_) {}
  }

  Future<void> _loadFollowedPeople() async {
    try {
      final followedPeople = await _catalogApiService
          .fetchCurrentUserFollowing();
      if (!mounted) {
        return;
      }
      setState(() {
        _followedPeople
          ..clear()
          ..addAll(followedPeople);
        _isLoadingFollowedPeople = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _followedPeople.clear();
        _isLoadingFollowedPeople = false;
      });
    }
  }

  Future<void> _openFollowedPerson(Map<String, dynamic> person) async {
    final role = person['role']?.toString().trim().toUpperCase() ?? '';
    final sellerProfileId = person['sellerProfileId']?.toString().trim() ?? '';
    final userId =
        person['userId']?.toString().trim() ??
        person['id']?.toString().trim() ??
        '';

    if (role == 'SELLER' && sellerProfileId.isNotEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FutureBuilder<Map<String, dynamic>>(
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
          ),
        ),
      );
      return;
    }

    if (userId.isEmpty) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FutureBuilder<Map<String, dynamic>>(
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
        ),
      ),
    );
  }

  Future<void> _openFollowedPersonLive(Map<String, dynamic> person) async {
    if (person['isLive'] != true) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ce live n\'est plus disponible.')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveWatchPage(
          sellerProfileId: person['sellerProfileId']?.toString().trim() ?? '',
          sellerName:
              person['displayName']?.toString() ??
              person['name']?.toString() ??
              'Boutique BANAY',
          sellerAvatarUrl: person['avatarUrl']?.toString() ?? '',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _productUploadQueueService.removeListener(_handleProductUploadQueueChanged);
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    disposePageRefresh();
    super.dispose();
  }

  @override
  Future<void> onPageReload() async {
    if (mounted) {
      setState(() {
        _showEntrySkeleton = true;
        _isLoadingFollowedPeople = true;
      });
    }
    await Future.delayed(const Duration(milliseconds: 450));
    await _loadSellerPublishedProducts();
    await _loadFollowedPeople();
    if (!mounted) return;
    setState(() {
      _syncPendingProductTasks();
      _showEntrySkeleton = false;
    });
  }

  Future<void> _initializeProductUploadQueue() async {
    await _productUploadQueueService.initialize();
    if (!mounted) {
      return;
    }
    _handleProductUploadQueueChanged();
  }

  void _handleProductUploadQueueChanged() {
    if (!mounted) {
      return;
    }

    final completedTasks = _productUploadQueueService.completedTasks;
    setState(() {
      _syncPendingProductTasks();
      for (final task in completedTasks) {
        _removePendingProductsFromState(taskId: task.id);
        final resultProduct = task.resultProduct;
        if (resultProduct == null) {
          continue;
        }
        _upsertProductInState({
          ...resultProduct,
          if (task.condition != null) 'condition': task.condition,
          'status': task.previewProduct?['status'] ?? 'Disponible',
          'isLocalFile': false,
        });
      }
    });

    for (final task in completedTasks) {
      unawaited(_productUploadQueueService.acknowledgeTask(task.id));
    }
  }

  void _syncPendingProductTasks() {
    _removePendingProductsFromState();
    for (final task in _productUploadQueueService.activeTasks) {
      final previewProduct = task.previewProduct;
      if (previewProduct == null || previewProduct.isEmpty) {
        continue;
      }

      _upsertProductInState({
        ...previewProduct,
        'syncStatus': switch (task.state) {
          ProductUploadTaskState.uploading => 'Synchronisation...',
          ProductUploadTaskState.waitingForConnection => 'Pending',
          ProductUploadTaskState.failed => 'Echec',
          ProductUploadTaskState.queued => 'Pending',
          ProductUploadTaskState.completed => 'Synchronise',
        },
        'pendingTaskId': task.id,
        'pendingMessage': task.statusText,
        'pendingProgress': task.progress,
        'pendingCanResume': task.canResume,
        'pendingIsUploading': task.state == ProductUploadTaskState.uploading,
      });
    }
  }

  void _removePendingProductsFromState({String? taskId}) {
    bool shouldRemove(Map<String, dynamic> product) {
      final pendingTaskId = product['pendingTaskId']?.toString().trim() ?? '';
      if (pendingTaskId.isEmpty) {
        return false;
      }
      if (taskId == null) {
        return true;
      }
      return pendingTaskId == taskId;
    }

    _sellerPublishedProducts.removeWhere(shouldRemove);
    _customStudioProducts.removeWhere(shouldRemove);
    _productOverrides.removeWhere((_, product) => shouldRemove(product));
  }

  Map<String, dynamic> _buildPendingProductPreview({
    required String tempId,
    required String productName,
    required String productCategory,
    required String productDescription,
    required double parsedPrice,
    required String availability,
    required String productCondition,
    required bool hasWarranty,
    required int? warrantyDurationValue,
    required String warrantyDurationUnit,
    required List<File> localImageFiles,
    required List<String> imageOrder,
    Map<String, dynamic>? initialProduct,
  }) {
    final previewImages = imageOrder
        .map((entry) {
          if (!entry.startsWith('__upload__')) {
            return entry;
          }

          final uploadIndex = int.tryParse(
            entry.replaceFirst('__upload__', ''),
          );
          if (uploadIndex == null ||
              uploadIndex < 0 ||
              uploadIndex >= localImageFiles.length) {
            return '';
          }
          return localImageFiles[uploadIndex].path;
        })
        .where((entry) => entry.trim().isNotEmpty)
        .toList(growable: false);

    final previewId =
        (initialProduct?['id']?.toString().trim().isNotEmpty ?? false)
        ? initialProduct!['id'].toString().trim()
        : tempId;

    return {
      'id': previewId,
      'title': productName,
      'category': productCategory,
      'description': productDescription,
      'price': parsedPrice,
      'currencyCode':
          initialProduct?['currencyCode']?.toString().trim().isNotEmpty == true
          ? initialProduct!['currencyCode'].toString().trim()
          : 'MGA',
      'images': previewImages,
      'thumbnail': previewImages.isNotEmpty ? previewImages.first : '',
      'status': availability,
      'condition': productConditionApiFromLabel(productCondition),
      'isAvailable': availability == 'Disponible',
      'hasWarranty': hasWarranty,
      'warrantyDurationValue': hasWarranty ? warrantyDurationValue : null,
      'warrantyDurationUnit': hasWarranty
          ? warrantyDurationUnitApiFromLabel(warrantyDurationUnit)
          : null,
      'isLocalFile': true,
    };
  }

  Future<void> _resumePendingProductUploads() async {
    await _productUploadQueueService.resumeAllPending();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isOffline
              ? 'Les produits restent en pending jusqu\'au retour de la connexion.'
              : 'Reprise des produits en attente.',
        ),
      ),
    );
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
    if (_isSellerCertified) {
      return const SizedBox.shrink();
    }

    final isPending = _sellerVerificationRequestStatus == 'PENDING';
    final isRejected = _sellerVerificationRequestStatus == 'REJECTED';

    final title = isPending
        ? 'Certification en attente'
        : isRejected
        ? 'Demande a renvoyer'
        : 'Certification vendeur';

    final description = isPending
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
              text: isPending
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
                      isRejected
                          ? Icons.refresh_rounded
                          : Icons.workspace_premium_outlined,
                      size: 18,
                    ),
              onPressed: (isPending || _isSubmittingSellerCertificationRequest)
                  ? null
                  : _submitSellerCertificationRequest,
              backgroundColor: isPending
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
    final isUploadInProgress = target == _EditableProfileImageTarget.avatar
        ? _isUploadingAvatarImage
        : _isUploadingCoverImage;
    if (isUploadInProgress) {
      return;
    }

    final file = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1800,
    );
    if (file == null || !mounted) return;

    final selectedFile = File(file.path);
    final previousAvatarImageFile = _avatarImageFile;
    final previousCoverImageFile = _coverImageFile;

    setState(() {
      if (target == _EditableProfileImageTarget.avatar) {
        _avatarImageFile = selectedFile;
        _isUploadingAvatarImage = true;
      } else {
        _coverImageFile = selectedFile;
        _isUploadingCoverImage = true;
      }
    });

    try {
      if (target == _EditableProfileImageTarget.avatar) {
        await _authService.uploadAvatarImage(imageFile: selectedFile);
      } else {
        await _authService.uploadCoverImage(imageFile: selectedFile);
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            target == _EditableProfileImageTarget.avatar
                ? 'Photo de profil mise a jour.'
                : 'Photo de couverture mise a jour.',
          ),
        ),
      );
    } on AppApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _avatarImageFile = previousAvatarImageFile;
        _coverImageFile = previousCoverImageFile;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          if (target == _EditableProfileImageTarget.avatar) {
            _isUploadingAvatarImage = false;
          } else {
            _isUploadingCoverImage = false;
          }
        });
      }
    }
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
        final sheetMessenger = ScaffoldMessenger.of(sheetContext);
        final pageMessenger = ScaffoldMessenger.of(context);
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
                  borderColor: accentColor.withValues(alpha: 0.12),
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
                  borderColor: accentColor.withValues(alpha: 0.12),
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
                    onPressed: () async {
                      if (_isSavingIdentity) {
                        return;
                      }

                      final sanitizedStudioName = _sanitizeDisplayText(
                        nameController.text,
                      );
                      final sanitizedStudioAddress = _sanitizeDisplayText(
                        addressController.text,
                      );
                      final sanitizedStudioDescription = _sanitizeDisplayText(
                        descriptionController.text,
                      );

                      if (sanitizedStudioName.isEmpty) {
                        sheetMessenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Le nom de la boutique est obligatoire.',
                            ),
                          ),
                        );
                        return;
                      }

                      final (city, country) = _splitStudioAddress(
                        sanitizedStudioAddress,
                      );

                      setState(() {
                        _isSavingIdentity = true;
                      });

                      try {
                        await _authService.updateSellerProfile(
                          studioName: sanitizedStudioName,
                          description: sanitizedStudioDescription,
                          city: city,
                          country: country,
                        );

                        if (!mounted) {
                          return;
                        }

                        setState(() {
                          _studioName = sanitizedStudioName;
                          _studioAddress = sanitizedStudioAddress;
                          _studioDescription = sanitizedStudioDescription;
                        });

                        if (!sheetContext.mounted) {
                          return;
                        }

                        Navigator.of(sheetContext).pop();
                        pageMessenger.showSnackBar(
                          const SnackBar(
                            content: Text('Profil boutique mis a jour.'),
                          ),
                        );
                      } on AppApiException catch (error) {
                        if (!mounted) {
                          return;
                        }

                        sheetMessenger.showSnackBar(
                          SnackBar(content: Text(error.message)),
                        );
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isSavingIdentity = false;
                          });
                        }
                      }
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
    String productCondition =
        productConditionLabelFromApi(initialProduct?['condition']) ?? 'Neuf';
    bool hasWarranty = initialProduct?['hasWarranty'] as bool? ?? false;
    final warrantyDurationController = TextEditingController(
      text: initialProduct?['warrantyDurationValue'] == null
          ? ''
          : '${initialProduct?['warrantyDurationValue']}',
    );
    String warrantyDurationUnit =
        warrantyDurationUnitLabelFromApi(
          initialProduct?['warrantyDurationUnit'],
        ) ??
        'Mois';
    var isPublishingProduct = false;
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
                              value: 'Occasion',
                              child: Text('Occasion'),
                            ),
                            DropdownMenuItem(
                              value: 'Reconditionne',
                              child: Text('Reconditionne'),
                            ),
                            DropdownMenuItem(
                              value: 'Neuf',
                              child: Text('Neuf'),
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
                        DynamicIconCheckbox(
                          value: hasWarranty,
                          onChanged: (value) {
                            setModalState(() {
                              hasWarranty = value;
                              if (!value) {
                                warrantyDurationController.clear();
                              }
                            });
                          },
                          primary: accentColor,
                          panelColor: panelColor,
                          borderColor: accentColor.withValues(alpha: 0.12),
                          label: 'Ce produit a une garantie',
                          leadingIcon: Icon(
                            Icons.shield_outlined,
                            color: accentColor,
                          ),
                        ),
                        if (hasWarranty) ...[
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: DynamicIconInput(
                                  controller: warrantyDurationController,
                                  primary: accentColor,
                                  panelColor: panelColor,
                                  borderColor: accentColor.withValues(
                                    alpha: 0.12,
                                  ),
                                  hintText: 'Duree',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  leadingIcon: Icon(
                                    Icons.timer_outlined,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DynamicIconComboBox<String>(
                                  value: warrantyDurationUnit,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Jours',
                                      child: Text('Jours'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Mois',
                                      child: Text('Mois'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Annee',
                                      child: Text('Annee'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setModalState(() {
                                      warrantyDurationUnit = value;
                                    });
                                  },
                                  primary: accentColor,
                                  panelColor: panelColor,
                                  borderColor: accentColor.withValues(
                                    alpha: 0.12,
                                  ),
                                  hintText: 'Unite',
                                ),
                              ),
                            ],
                          ),
                        ],
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

                                    final parsedWarrantyDuration =
                                        int.tryParse(
                                          warrantyDurationController.text
                                              .trim(),
                                        );

                                    if (productName.isEmpty ||
                                        productCategory.isEmpty ||
                                        parsedPrice == null ||
                                        parsedPrice <= 0 ||
                                        productDescription.isEmpty ||
                                        productImages.isEmpty ||
                                        (hasWarranty &&
                                            (parsedWarrantyDuration == null ||
                                                parsedWarrantyDuration <=
                                                    0))) {
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

                                    String? errorMessage;

                                    try {
                                      setModalState(() {
                                        isPublishingProduct = true;
                                      });

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

                                      final previewProduct =
                                          _buildPendingProductPreview(
                                            tempId:
                                                'pending-${DateTime.now().microsecondsSinceEpoch}',
                                            productName: productName,
                                            productCategory: productCategory,
                                            productDescription:
                                                productDescription,
                                            parsedPrice: parsedPrice.toDouble(),
                                            availability: availability,
                                            productCondition: productCondition,
                                            hasWarranty: hasWarranty,
                                            warrantyDurationValue:
                                                parsedWarrantyDuration,
                                            warrantyDurationUnit:
                                                warrantyDurationUnit,
                                            localImageFiles: localImageFiles,
                                            imageOrder: imageOrder,
                                            initialProduct: initialProduct,
                                          );
                                      final apiCondition =
                                          productConditionApiFromLabel(
                                            productCondition,
                                          );
                                      final apiWarrantyDurationUnit =
                                          warrantyDurationUnitApiFromLabel(
                                            warrantyDurationUnit,
                                          );

                                      final taskId = isEditingProduct
                                          ? await _productUploadQueueService
                                                .enqueueUpdate(
                                                  productId:
                                                      (initialProduct['id'] ??
                                                              '')
                                                          .toString(),
                                                  title: productName,
                                                  description:
                                                      productDescription,
                                                  priceAmount: parsedPrice,
                                                  categoryName: productCategory,
                                                  imageFilePaths:
                                                      localImageFiles
                                                          .map(
                                                            (file) => file.path,
                                                          )
                                                          .toList(
                                                            growable: false,
                                                          ),
                                                  imageOrder: imageOrder,
                                                  isAvailable:
                                                      availability ==
                                                      'Disponible',
                                                  condition: apiCondition,
                                                  hasWarranty: hasWarranty,
                                                  warrantyDurationValue:
                                                      hasWarranty
                                                      ? parsedWarrantyDuration
                                                      : null,
                                                  warrantyDurationUnit:
                                                      hasWarranty
                                                      ? apiWarrantyDurationUnit
                                                      : null,
                                                  previewProduct:
                                                      previewProduct,
                                                )
                                          : await _productUploadQueueService
                                                .enqueueCreate(
                                                  title: productName,
                                                  description:
                                                      productDescription,
                                                  priceAmount: parsedPrice,
                                                  categoryName: productCategory,
                                                  imageFilePaths:
                                                      localImageFiles
                                                          .map(
                                                            (file) => file.path,
                                                          )
                                                          .toList(
                                                            growable: false,
                                                          ),
                                                  imageOrder: imageOrder,
                                                  condition: apiCondition,
                                                  hasWarranty: hasWarranty,
                                                  warrantyDurationValue:
                                                      hasWarranty
                                                      ? parsedWarrantyDuration
                                                      : null,
                                                  warrantyDurationUnit:
                                                      hasWarranty
                                                      ? apiWarrantyDurationUnit
                                                      : null,
                                                  previewProduct:
                                                      previewProduct,
                                                );

                                      if (!mounted || !sheetContext.mounted) {
                                        return;
                                      }

                                      setState(() {
                                        _upsertProductInState({
                                          ...previewProduct,
                                          'pendingTaskId': taskId,
                                          'pendingMessage': isOffline
                                              ? 'Pending: en attente de connexion...'
                                              : 'Synchronisation en arriere-plan...',
                                          'pendingProgress': isOffline
                                              ? 0.08
                                              : 0.12,
                                          'syncStatus': isOffline
                                              ? 'Pending'
                                              : 'Synchronisation...',
                                          'pendingCanResume': false,
                                        });
                                      });

                                      Navigator.of(sheetContext).pop();
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            isOffline
                                                ? '$productName est passe en pending et reprendra avec la connexion.'
                                                : isEditingProduct
                                                ? '$productName est en cours de mise a jour en arriere-plan.'
                                                : '$productName est en cours de publication en arriere-plan.',
                                          ),
                                        ),
                                      );
                                    } on AppApiException catch (error) {
                                      if (!mounted || !sheetContext.mounted) {
                                        return;
                                      }

                                      errorMessage = error.message;
                                    } finally {
                                      if (sheetContext.mounted) {
                                        setModalState(() {
                                          isPublishingProduct = false;
                                        });
                                      }

                                      if (context.mounted &&
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
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

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

      await navigator.push<bool>(
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
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      messenger.showSnackBar(
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
                  borderColor: accentColor.withValues(alpha: 0.12),
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
                  borderColor: accentColor.withValues(alpha: 0.12),
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

    final existingPublishedIndex = _sellerPublishedProducts.indexWhere(
      (item) => (item['id'] ?? '').toString() == productId,
    );
    if (existingPublishedIndex >= 0) {
      _sellerPublishedProducts[existingPublishedIndex] = normalizedProduct;
      _productOverrides.remove(productId);
      return;
    }

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

  void _removeProductFromState(String productId) {
    _sellerPublishedProducts.removeWhere(
      (item) => (item['id'] ?? '').toString() == productId,
    );
    _customStudioProducts.removeWhere(
      (item) => (item['id'] ?? '').toString() == productId,
    );
    _productOverrides.remove(productId);
    _productAvailabilityBusy.remove(productId);
    _productDeletionBusy.remove(productId);
  }

  Future<bool> _showProductActionConfirmationDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required IconData icon,
    required Color iconColor,
  }) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
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
                  color: iconColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 30),
              ),
              const SizedBox(height: 14),
              Text(title, textAlign: TextAlign.center),
            ],
          ),
          content: Text(message, textAlign: TextAlign.center),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: iconColor),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                confirmLabel,
                style: TextStyle(color: theme.colorScheme.onPrimary),
              ),
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }

  Future<void> _confirmAndToggleProductAvailability(
    Map<String, dynamic> product,
  ) async {
    final productName = (product['title'] as String?)?.trim() ?? 'ce produit';
    final isAvailable = (product['isAvailable'] as bool?) ?? true;
    final confirmed = await _showProductActionConfirmationDialog(
      title: isAvailable
          ? 'Rendre ce produit indisponible ?'
          : 'Remettre ce produit disponible ?',
      message: isAvailable
          ? 'Le produit "$productName" ne sera plus visible comme disponible tant que vous ne le reactivez pas.'
          : 'Le produit "$productName" redeviendra disponible dans votre catalogue.',
      confirmLabel: isAvailable ? 'Mettre indisponible' : 'Remettre disponible',
      icon: isAvailable
          ? Icons.visibility_off_outlined
          : Icons.visibility_rounded,
      iconColor: isAvailable
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.secondary,
    );

    if (!confirmed || !mounted) {
      return;
    }

    await _toggleProductAvailability(product);
  }

  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    final productId = (product['id'] ?? '').toString().trim();
    if (productId.isEmpty || _productDeletionBusy.contains(productId)) {
      return;
    }

    setState(() {
      _productDeletionBusy.add(productId);
    });

    try {
      await _catalogApiService.deleteProduct(productId);
      if (!mounted) {
        return;
      }

      setState(() {
        _removeProductFromState(productId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le produit a ete supprime.')),
      );
    } on AppApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      setState(() {
        _productDeletionBusy.remove(productId);
      });
    }
  }

  Future<void> _confirmAndDeleteProduct(Map<String, dynamic> product) async {
    final productName = (product['title'] as String?)?.trim() ?? 'ce produit';
    final confirmed = await _showProductActionConfirmationDialog(
      title: 'Supprimer ce produit ?',
      message:
          'Le produit "$productName" sera retire de votre catalogue. Cette action est definitive.',
      confirmLabel: 'Supprimer',
      icon: Icons.delete_outline_rounded,
      iconColor: Colors.red.shade400,
    );

    if (!confirmed || !mounted) {
      return;
    }

    await _deleteProduct(product);
  }

  Future<void> _toggleProductAvailability(Map<String, dynamic> product) async {
    final productId = (product['id'] ?? '').toString().trim();
    if (productId.isEmpty || _productAvailabilityBusy.contains(productId)) {
      return;
    }

    final nextAvailability = !((product['isAvailable'] as bool?) ?? true);
    final productTitle = (product['title'] as String?)?.trim() ?? '';
    final productDescription =
        (product['description'] as String?)?.trim() ?? '';
    final productCategory = (product['category'] as String?)?.trim() ?? '';
    final productPrice = (product['price'] as num?)?.toDouble();
    final productImages =
        ((product['images'] as List?)
            ?.whereType<String>()
            .map((image) => image.trim())
            .where((image) => image.isNotEmpty)
            .toList()) ??
        <String>[];
    final thumbnail = (product['thumbnail'] as String?)?.trim() ?? '';
    final imageOrder = productImages.isNotEmpty
        ? productImages
        : thumbnail.isNotEmpty
        ? <String>[thumbnail]
        : <String>[];

    if (productTitle.isEmpty ||
        productDescription.isEmpty ||
        productCategory.isEmpty ||
        productPrice == null ||
        imageOrder.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible de changer la disponibilite: donnees produit incompletes.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _productAvailabilityBusy.add(productId);
    });

    try {
      final updatedProduct = await _catalogApiService.updateProduct(
        productId: productId,
        title: productTitle,
        description: productDescription,
        priceAmount: productPrice,
        categoryName: productCategory,
        imageFiles: const <File>[],
        imageOrder: imageOrder,
        isAvailable: nextAvailability,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _upsertProductInState(updatedProduct);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextAvailability
                ? 'Le produit est de nouveau disponible.'
                : 'Le produit est passe en indisponible.',
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
          _productAvailabilityBusy.remove(productId);
        });
      }
    }
  }

  Widget _buildSellerProductActions(Map<String, dynamic> product) {
    final theme = Theme.of(context);
    final productId = (product['id'] ?? '').toString().trim();
    final pendingTaskId = product['pendingTaskId']?.toString().trim() ?? '';
    final isPendingTask = pendingTaskId.isNotEmpty;
    final isAvailable = (product['isAvailable'] as bool?) ?? true;
    final isAvailabilityBusy =
        productId.isNotEmpty && _productAvailabilityBusy.contains(productId);
    final isDeleteBusy =
        productId.isNotEmpty && _productDeletionBusy.contains(productId);
    final isAnyBusy = isAvailabilityBusy || isDeleteBusy;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isPendingTask) ...[
          _buildSellerProductActionButton(
            icon: Icons.play_arrow_rounded,
            tooltip: 'Reprendre',
            onTap: () => _productUploadQueueService.retryTask(pendingTaskId),
            iconColor: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
        ],
        _buildSellerProductActionButton(
          icon: Icons.edit_outlined,
          tooltip: 'Modifier',
          onTap: isAnyBusy || isPendingTask
              ? null
              : () => _showCreateProductSheet(initialProduct: product),
        ),
        const SizedBox(width: 8),
        _buildSellerProductActionButton(
          icon: Icons.delete_outline_rounded,
          tooltip: 'Supprimer',
          onTap: isDeleteBusy || isPendingTask
              ? null
              : () => _confirmAndDeleteProduct(product),
          iconColor: Colors.red.shade300,
          busy: isDeleteBusy,
        ),
        const SizedBox(width: 8),
        _buildSellerProductActionButton(
          icon: isAvailable
              ? Icons.visibility_off_outlined
              : Icons.visibility_rounded,
          tooltip: isAvailable ? 'Non disponible' : 'Remettre disponible',
          onTap: isAvailabilityBusy || isPendingTask
              ? null
              : () => _confirmAndToggleProductAvailability(product),
          iconColor: isAvailable
              ? theme.colorScheme.onSurface
              : theme.colorScheme.primary,
          busy: isAvailabilityBusy,
        ),
      ],
    );
  }

  Widget _buildSellerProductActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    Color? iconColor,
    bool busy = false,
  }) {
    final theme = Theme.of(context);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: busy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onSurface,
                      ),
                    )
                  : Icon(icon, size: 21, color: iconColor ?? Colors.white),
            ),
          ),
        ),
      ),
    );
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
                      _buildTabNavigation(theme, panelColor, mutedColor),
                      const SizedBox(height: 18),
                      _buildTabContent(
                        theme,
                        panelColor,
                        mutedColor,
                        accentColor,
                        supportAccentColor,
                        filteredProducts,
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
    final coverHeight = compact ? 190.0 : 214.0;
    final summaryOffset = compact ? 64.0 : 72.0;
    final panelColor = _panelColor(theme);
    final accentColor = _accentColor(theme);
    final mutedColor = _mutedColor(theme);

    return SizedBox(
      height: coverHeight + summaryOffset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: SizedBox(
              height: coverHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'account-cover-${profile.userId}',
                    child: _buildEditableCoverImage(),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.08),
                          Colors.black.withValues(alpha: 0.14),
                          Colors.black.withValues(alpha: 0.52),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: summaryOffset,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openImageViewer(
                  imageUrl: _coverImageFile?.path ?? profile.coverImageUrl,
                  heroTag: 'account-cover-${profile.userId}',
                  isLocalFile: _coverImageFile != null,
                ),
              ),
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
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, compact ? 14 : 16, 16, 16),
              decoration: BoxDecoration(
                color: panelColor.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: _panelBorderColor(theme)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                            color: accentColor.withValues(alpha: 0.28),
                            width: 2,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _openImageViewer(
                              imageUrl:
                                  _avatarImageFile?.path ?? profile.avatarUrl,
                              heroTag: 'account-avatar-${profile.userId}',
                              isLocalFile: _avatarImageFile != null,
                            ),
                            child: Hero(
                              tag: 'account-avatar-${profile.userId}',
                              child: _buildEditableAvatar(),
                            ),
                          ),
                        ),
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
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onLongPress: _openQaEventLogPage,
                          child: Text(
                            _resolvedStudioName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _buildProfileStatPill(
                              theme,
                              value: profile.followerCount,
                              icon: Icons.groups_rounded,
                            ),
                            _buildProfileStatPill(
                              theme,
                              value: profile.productCount,
                              icon: Icons.grid_view_rounded,
                            ),
                            _buildProfileEditPill(theme),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _isSellerCertified
                            ? const SellerCertifiedMiniBadge()
                            : Text(
                                profile.roleLabel,
                                style: TextStyle(
                                  color: mutedColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openImageViewer({
    required String imageUrl,
    required String heroTag,
    bool isLocalFile = false,
  }) async {
    final normalizedUrl = imageUrl.trim();
    if (normalizedUrl.isEmpty) {
      return;
    }

    if (isLocalFile) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: Hero(
                      tag: heroTag,
                      child: InteractiveViewer(
                        minScale: 1,
                        maxScale: 5,
                        child: Image.file(
                          File(normalizedUrl),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrivateImageViewerPage(
          imageUrls: [normalizedUrl],
          heroTag: heroTag,
          overlay: ImageViewerOverlayData(
            sellerName: _resolvedStudioName,
            sellerUserId: profile.userId,
            sellerAvatarUrl: profile.avatarUrl,
            sellerBadge: _isSellerCertified
                ? 'Vendeur certifie'
                : profile.roleLabel,
            isUserProfileImage: true,
          ),
        ),
      ),
    );
  }

  Future<void> _openQaEventLogPage() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const QaEventLogPage()));
  }

  Widget _buildTabNavigation(
    ThemeData theme,
    Color panelColor,
    Color mutedColor,
  ) {
    final tabs = [
      (_AccountPanelTab.products, 'Mes produits', Icons.storefront_rounded),
      (_AccountPanelTab.statistics, 'Statistique', Icons.bar_chart_rounded),
      (_AccountPanelTab.following, 'Abonnement', Icons.groups_rounded),
    ];

    final accentColor = _accentColor(theme);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: tabs.map((tab) {
          final isSelected = _selectedTab == tab.$1;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => setState(() => _selectedTab = tab.$1),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accentColor.withValues(alpha: 0.10)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(
                              color: accentColor.withValues(alpha: 0.22),
                            )
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            tab.$3,
                            key: ValueKey(isSelected),
                            size: 20,
                            color: isSelected ? accentColor : mutedColor,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          tab.$2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? accentColor : mutedColor,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w500,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabContent(
    ThemeData theme,
    Color panelColor,
    Color mutedColor,
    Color accentColor,
    Color supportAccentColor,
    List<Map<String, dynamic>> filteredProducts,
  ) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: KeyedSubtree(
        key: ValueKey<_AccountPanelTab>(_selectedTab),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: switch (_selectedTab) {
            _AccountPanelTab.products => _buildProductsTab(
              theme,
              panelColor,
              mutedColor,
              accentColor,
              supportAccentColor,
              filteredProducts,
            ),
            _AccountPanelTab.statistics => _buildStatisticsTab(
              theme,
              panelColor,
              mutedColor,
              accentColor,
              supportAccentColor,
            ),
            _AccountPanelTab.following => _buildFollowingTab(theme, mutedColor),
          },
        ),
      ),
    );
  }

  List<Widget> _buildProductsTab(
    ThemeData theme,
    Color panelColor,
    Color mutedColor,
    Color accentColor,
    Color supportAccentColor,
    List<Map<String, dynamic>> filteredProducts,
  ) {
    return [
      _buildProductActionsSection(theme, accentColor, filteredProducts.length),
      _buildCatalogSection(
        theme,
        panelColor,
        mutedColor,
        filteredProducts,
        maxItems: null,
      ),
    ];
  }

  List<Widget> _buildStatisticsTab(
    ThemeData theme,
    Color panelColor,
    Color mutedColor,
    Color accentColor,
    Color supportAccentColor,
  ) {
    return [
      _buildMetricsGrid(theme, panelColor, mutedColor, accentColor),
      const SizedBox(height: 18),
      _buildDashboardCard(
        theme,
        panelColor,
        mutedColor,
        accentColor,
        supportAccentColor,
      ),
    ];
  }

  List<Widget> _buildFollowingTab(ThemeData theme, Color mutedColor) {
    return [_buildFollowingSection(theme, mutedColor)];
  }

  Widget _buildProductActionsSection(
    ThemeData theme,
    Color accentColor,
    int resultCount,
  ) {
    final pendingTasks = _productUploadQueueService.activeTasks;
    final hasPendingTasks = pendingTasks.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _surfaceDecoration(theme, radius: 24, tinted: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(theme, 'Mes produits', '$resultCount resultats'),
          if (hasPendingTasks) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: accentColor.withValues(alpha: 0.16)),
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud_upload_outlined, color: accentColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${pendingTasks.length} produit${pendingTasks.length > 1 ? 's' : ''} en pending ou en synchronisation.',
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _resumePendingProductUploads,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reprendre'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showCreateProductSheet,
                  icon: const Icon(Icons.add_box_outlined, size: 18),
                  label: const Text('Creer produit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: theme.colorScheme.onPrimary,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Rechercher un produit ou une categorie',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.trim().isEmpty
                  ? null
                  : IconButton(
                      onPressed: _searchController.clear,
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: theme.appColors.inputFill.withValues(alpha: 0.58),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowingSection(ThemeData theme, Color mutedColor) {
    final panelColor = _panelColor(theme);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _surfaceDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            theme,
            'Mes abonnements',
            '${_followedPeople.length} profil${_followedPeople.length > 1 ? 's' : ''}',
          ),
          const SizedBox(height: 14),
          if (_isLoadingFollowedPeople)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_followedPeople.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: panelColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _panelBorderColor(theme)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aucun abonnement pour le moment',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Abonnez-vous a des boutiques pour les retrouver ici.',
                    style: TextStyle(
                      color: mutedColor,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              primary: false,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _followedPeople.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final person = _followedPeople[index];
                return _buildFollowedPersonTile(theme, mutedColor, person);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFollowedPersonTile(
    ThemeData theme,
    Color mutedColor,
    Map<String, dynamic> person,
  ) {
    final fallbackName = context.tr(
      BanayLocalizationKeys.homeFollowedMemberFallback,
    );
    final fallbackSubtitle = context.tr(
      BanayLocalizationKeys.homeFollowedSubtitleFallback,
    );
    final sellerBadge = context.tr(
      BanayLocalizationKeys.homeFollowedSellerBadge,
    );
    final profileBadge = context.tr(
      BanayLocalizationKeys.homeFollowedProfileBadge,
    );
    final fallbackLiveTitle = context.tr(
      BanayLocalizationKeys.homeFollowedLiveNow,
    );
    final name = resolveFollowedPersonName(person, fallbackName: fallbackName);
    final subtitle = resolveFollowedPersonSubtitle(
      person,
      fallbackSubtitle: fallbackSubtitle,
    );
    final avatarUrl = resolveFollowedPersonAvatarUrl(person);
    final userId = resolveFollowedPersonUserId(person);
    final trailingText = resolveFollowedPersonTrailingText(
      person,
      sellerBadge: sellerBadge,
      profileBadge: profileBadge,
    );
    final isLive = isFollowedPersonLive(person);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openFollowedPerson(person),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: _surfaceDecoration(theme, radius: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppCircleNetworkAvatar(
                imageUrl: avatarUrl,
                radius: 28,
                userId: userId,
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
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (trailingText.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              trailingText,
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isLive
                          ? resolveFollowedPersonLiveTitle(
                              person,
                              fallbackLiveTitle: fallbackLiveTitle,
                            )
                          : subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isLive ? const Color(0xFFE53935) : mutedColor,
                        height: 1.35,
                        fontWeight: isLive ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => _openFollowedPerson(person),
                          icon: const Icon(
                            Icons.person_outline_rounded,
                            size: 18,
                          ),
                          label: const Text('Voir le profil'),
                        ),
                        if (isLive) ...[
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _openFollowedPersonLive(person),
                            icon: const Icon(Icons.live_tv_rounded, size: 18),
                            label: const Text('Voir le live'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ],
                      ],
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
              padding: const EdgeInsets.all(16),
              decoration: _surfaceDecoration(
                theme,
                radius: 22,
                tinted: index.isEven,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: iconBackground,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(metric.icon, color: accentColor),
                  ),
                  const Spacer(),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      metric.value,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
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
                                  duration: const Duration(milliseconds: 320),
                                  curve: Curves.easeOutCubic,
                                  width: double.infinity,
                                  height: 90 * bars[index],
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

  Widget _buildCatalogSection(
    ThemeData theme,
    Color panelColor,
    Color mutedColor,
    List<Map<String, dynamic>> filteredProducts, {
    int? maxItems = 3,
  }) {
    final visibleProducts = maxItems == null
        ? filteredProducts
        : filteredProducts.take(maxItems).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (filteredProducts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                'Aucun produit ne correspond a cette recherche.',
                style: TextStyle(color: mutedColor),
              ),
            )
          else
            ...visibleProducts.map((product) {
              final isPendingProduct =
                  (product['pendingTaskId']?.toString().trim().isNotEmpty ??
                  false);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  children: [
                    if (isPendingProduct)
                      _buildPendingProductCard(theme, mutedColor, product)
                    else
                      ProductCard(
                        product: product,
                        variant: ProductCardVariant.marketplace,
                        detailPageBuilder: (product) =>
                            seller_detail.ProductDetailPage(product: product),
                        topRightOverlay: _buildSellerProductActions(product),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPendingProductCard(
    ThemeData theme,
    Color mutedColor,
    Map<String, dynamic> product,
  ) {
    final pendingTaskId = product['pendingTaskId']?.toString().trim() ?? '';
    final statusLabel = product['syncStatus']?.toString().trim() ?? 'Pending';
    final statusMessage =
        product['pendingMessage']?.toString().trim().isNotEmpty == true
        ? product['pendingMessage'].toString().trim()
        : 'Synchronisation en attente.';
    final imageValue = (product['thumbnail'] ?? '').toString().trim();
    final hasLocalImage =
        imageValue.isNotEmpty && File(imageValue).existsSync();
    final priceValue = (product['price'] as num?)?.toDouble() ?? 0;
    final currencyCode =
        (product['currencyCode']?.toString().trim().isNotEmpty ?? false)
        ? product['currencyCode'].toString().trim()
        : 'MGA';
    final canResume = product['pendingCanResume'] == true;
    final isBlocked = canResume;
    final statusColor = isBlocked
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    final waterTrackColor = isBlocked
        ? theme.colorScheme.error.withValues(alpha: 0.12)
        : theme.appColors.inputFill;
    final progress = ((product['pendingProgress'] as num?)?.toDouble() ?? 0.08)
        .clamp(0.0, 1.0);

    return Container(
      decoration: _surfaceDecoration(theme),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 92,
              height: 92,
              child: hasLocalImage
                  ? Image.file(File(imageValue), fit: BoxFit.cover)
                  : imageValue.isNotEmpty
                  ? AppNetworkImage(imageUrl: imageValue, fit: BoxFit.cover)
                  : Container(
                      color: theme.appColors.inputFill,
                      child: Icon(
                        Icons.inventory_2_outlined,
                        color: theme.appColors.placeholderIcon,
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
                        (product['title'] ?? 'Produit').toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${product['category'] ?? 'Produit'} • ${priceValue.toStringAsFixed(0)} $currencyCode',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _PendingWaterFillIndicator(
                        progress: progress,
                        color: statusColor,
                        trackColor: waterTrackColor,
                        animateWave: !canResume && progress < 1,
                        showSecondaryWave: !canResume && progress < 1,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${(progress * 100).round()}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  statusMessage,
                  style: TextStyle(color: mutedColor, height: 1.35),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (canResume)
                      TextButton.icon(
                        onPressed: pendingTaskId.isEmpty
                            ? null
                            : () => _productUploadQueueService.retryTask(
                                pendingTaskId,
                              ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Reprendre'),
                      )
                    else
                      Text(
                        'Le reste de l\'application reste utilisable.',
                        style: TextStyle(
                          color: mutedColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color mutedColor,
    bool highlighted = false,
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
        child: Row(
          crossAxisAlignment: multiline
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _accentColor(Theme.of(context)).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: _accentColor(Theme.of(context))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: mutedColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: multiline ? 3 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                      color: highlighted
                          ? _accentColor(Theme.of(context))
                          : null,
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

  Widget _buildProfileStatPill(
    ThemeData theme, {
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _accentColor(theme).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _accentColor(theme)),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: _accentColor(theme),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileEditPill(ThemeData theme) {
    final accentColor = _accentColor(theme);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showIdentityEditor,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Icon(Icons.edit_rounded, size: 16, color: accentColor),
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

  Widget _buildSectionHeader(ThemeData theme, String title, [String? meta]) {
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
        if (meta != null && meta.trim().isNotEmpty)
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

class _PendingWaterFillIndicator extends StatefulWidget {
  const _PendingWaterFillIndicator({
    required this.progress,
    required this.color,
    required this.trackColor,
    this.animateWave = true,
    this.showSecondaryWave = true,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final bool animateWave;
  final bool showSecondaryWave;

  @override
  State<_PendingWaterFillIndicator> createState() =>
      _PendingWaterFillIndicatorState();
}

class _PendingWaterFillIndicatorState extends State<_PendingWaterFillIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.animateWave) {
      _waveController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _PendingWaterFillIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animateWave && !_waveController.isAnimating) {
      _waveController.repeat();
    } else if (!widget.animateWave && _waveController.isAnimating) {
      _waveController.stop();
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clampedProgress = widget.progress.clamp(0.0, 1.0);

    return SizedBox(
      height: 28,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: clampedProgress),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, animatedProgress, _) {
          return AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: widget.trackColor),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: animatedProgress,
                          widthFactor: 1,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CustomPaint(
                                painter: _WaterFillPainter(
                                  color: widget.color.withValues(alpha: 0.78),
                                  phase: _waveController.value,
                                  verticalFactor: 0.22,
                                  amplitudeFactor: 0.12,
                                ),
                              ),
                              if (widget.showSecondaryWave)
                                CustomPaint(
                                  painter: _WaterFillPainter(
                                    color: widget.color.withValues(alpha: 0.44),
                                    phase: (_waveController.value + 0.35) % 1,
                                    verticalFactor: 0.3,
                                    amplitudeFactor: 0.08,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _WaterFillPainter extends CustomPainter {
  const _WaterFillPainter({
    required this.color,
    required this.phase,
    required this.verticalFactor,
    required this.amplitudeFactor,
  });

  final Color color;
  final double phase;
  final double verticalFactor;
  final double amplitudeFactor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.72), color.withValues(alpha: 0.92)],
      ).createShader(Offset.zero & size);

    final path = Path()..moveTo(0, size.height * (1 - verticalFactor));
    final amplitude = math.min(size.height * amplitudeFactor, 4.0);
    final baseY = size.height * (1 - verticalFactor);
    final frequency = (2 * math.pi) / size.width;

    for (double x = 0; x <= size.width; x += 1) {
      final y =
          baseY +
          amplitude * math.sin((x * frequency * 2) + (phase * 2 * math.pi));
      path.lineTo(x, y);
    }

    path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WaterFillPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.phase != phase ||
        oldDelegate.verticalFactor != verticalFactor ||
        oldDelegate.amplitudeFactor != amplitudeFactor;
  }
}

class _StudioMetric {
  final String label;
  final String value;
  final IconData icon;

  const _StudioMetric(this.label, this.value, this.icon);
}
