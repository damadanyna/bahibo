import 'dart:async';

import 'package:banay/component/app_page_refresh.dart';
import 'package:banay/component/app_page_skeletons.dart';
import 'package:banay/component/profile_models.dart';
import 'package:banay/component/seller_profile_page.dart';
import 'package:banay/component/ui/dinamic_icon_input.dart';
import 'package:banay/component/ui/dinamic_followed_people_h_list.dart';
import 'package:banay/component/user_profile_page.dart';
import 'package:banay/page/live/live_preview_page.dart';
import 'package:banay/page/notifications_page.dart';
import 'package:banay/page/live/live_watch_page.dart';
import 'package:banay/localization/banay_localizations.dart';
import 'package:banay/services/app_analytics.dart';
import 'package:banay/services/app_api_client.dart';
import 'package:banay/services/app_auth_service.dart';
import 'package:banay/services/catalog_api_service.dart';
import 'package:banay/services/chat_realtime_service.dart';
import 'package:banay/services/notifications_api_service.dart';
import 'package:banay/theme/app_theme_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../component/ProductCard.dart';
import '../../component/app_network_image.dart';
import '../../page/productDetail.dart';

class MainHomePanel extends StatefulWidget {
  const MainHomePanel({super.key});

  @override
  State<MainHomePanel> createState() => _MainHomePanelState();
}

class _MainHomePanelState extends State<MainHomePanel>
    with AppPageRefreshMixin<MainHomePanel> {
  static const double _offlineBannerBottomOffset = 64;

  final AppAuthService _authService = AppAuthService();
  final CatalogApiService _catalogApiService = CatalogApiService();
  final NotificationsApiService _notificationsApiService =
      NotificationsApiService();
  final List<Map<String, dynamic>> _notifications = [];
  StreamSubscription<Map<String, dynamic>>? _realtimeEventsSubscription;

  final ScrollController _scrollController = ScrollController();

  List<dynamic> products = [];
  List<Map<String, dynamic>> followedPeople = [];

  int skip = 0;
  final int limit = 6;
  bool isLoading = false;
  bool hasMore = true;
  bool _isSeller = false;
  bool _isLoadingFollowedPeople = true;
  String _currentDisplayName = 'BANAY Shop';
  String _avatarUrl = '';
  String _currentUserId = '';
  String _viewerLocationLabel = '';
  double? _viewerLocationLatitude;
  double? _viewerLocationLongitude;

  bool _isProductAvailable(Map<String, dynamic> product) {
    final value = product['isAvailable'];
    return value is bool ? value : true;
  }

  bool _isSellerCertified(Map<String, dynamic> product) {
    final rawSeller = product['seller'];
    final seller = rawSeller is Map
        ? Map<String, dynamic>.from(rawSeller)
        : const <String, dynamic>{};
    final candidates = <Object?>[
      seller['isSellerCertified'],
      seller['isCertified'],
      seller['isVerified'],
      product['isSellerCertified'],
      product['sellerCertified'],
    ];
    for (final c in candidates) {
      if (c is bool && c) return true;
      final s = c?.toString().trim().toLowerCase() ?? '';
      if (s == 'true' || s == '1' || s == 'yes') return true;
    }
    return false;
  }

  bool _isFollowedSeller(Map<String, dynamic> product) {
    final rawSeller = product['seller'];
    final seller = rawSeller is Map
        ? Map<String, dynamic>.from(rawSeller)
        : const <String, dynamic>{};
    final sellerId =
        product['sellerUserId']?.toString().trim().isNotEmpty == true
        ? product['sellerUserId'].toString().trim()
        : seller['userId']?.toString().trim() ?? '';
    if (sellerId.isEmpty) return false;
    return followedPeople.any(
      (p) =>
          p['userId']?.toString().trim() == sellerId ||
          p['id']?.toString().trim() == sellerId,
    );
  }

  // Score: followed+certified=3, followed=2, certified=1, other=0
  int _productRankScore(Map<String, dynamic> product) {
    return (_isFollowedSeller(product) ? 2 : 0) +
        (_isSellerCertified(product) ? 1 : 0);
  }

  @override
  void initState() {
    super.initState();
    initializePageRefresh();
    unawaited(_bootstrapHomePanel());
    _bindRealtimeNotifications();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _bootstrapHomePanel() async {
    await _loadCurrentUserRole();
    await Future.wait([
      fetchFollowedPeople(),
      fetchProducts(),
      fetchNotifications(),
    ]);
  }

  @override
  void dispose() {
    disposePageRefresh();
    _realtimeEventsSubscription?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _bindRealtimeNotifications() {
    ChatRealtimeService.instance.ensureConnected();
    _realtimeEventsSubscription?.cancel();
    _realtimeEventsSubscription = ChatRealtimeService.instance.events.listen((
      event,
    ) {
      final type = event['type']?.toString();
      if (type == 'notifications:updated') {
        final unreadCount = (event['unreadCount'] as num?)?.toInt();
        if (unreadCount != null) {
          NotificationsApiService.unreadCountNotifier.value = unreadCount;
        }
        unawaited(fetchNotifications());
      }

      if (type == 'live:updated') {
        unawaited(fetchFollowedPeople());
      }

      if (type == 'profile:public-updated') {
        _applyPublicProfileUpdate(event);
      }
    });
  }

  void _applyPublicProfileUpdate(Map<String, dynamic> event) {
    final userId = event['userId']?.toString().trim() ?? '';
    final profile = event['profile'];
    if (userId.isEmpty || profile is! Map) {
      return;
    }

    final rawSellerProfile = profile['sellerProfile'];
    final sellerProfile = rawSellerProfile is Map
        ? Map<String, dynamic>.from(rawSellerProfile)
        : const <String, dynamic>{};
    final sellerProfileId = sellerProfile['id']?.toString().trim() ?? '';
    final displayName = profile['displayName']?.toString().trim() ?? '';
    final studioName = sellerProfile['studioName']?.toString().trim() ?? '';
    final resolvedName = studioName.isNotEmpty ? studioName : displayName;
    final avatarUrl = profile['avatarUrl']?.toString().trim() ?? '';
    final coverImageUrl = profile['coverImageUrl']?.toString().trim() ?? '';

    var hasChanged = false;

    final updatedProducts = products.map((entry) {
      if (entry is! Map) {
        return entry;
      }

      final product = Map<String, dynamic>.from(entry);
      final productSellerProfileId =
          product['sellerProfileId']?.toString().trim() ??
          product['seller']?['id']?.toString().trim() ??
          '';
      final productSellerUserId =
          product['sellerUserId']?.toString().trim() ??
          product['seller']?['userId']?.toString().trim() ??
          '';

      final matchesProfile =
          (sellerProfileId.isNotEmpty &&
              productSellerProfileId == sellerProfileId) ||
          productSellerUserId == userId;
      if (!matchesProfile) {
        return entry;
      }

      hasChanged = true;
      if (resolvedName.isNotEmpty) {
        product['sellerName'] = resolvedName;
      }
      if (avatarUrl.isNotEmpty) {
        product['sellerAvatarUrl'] = avatarUrl;
        product['avatarUrl'] = avatarUrl;
      }

      final seller = product['seller'];
      if (seller is Map) {
        final nextSeller = Map<String, dynamic>.from(seller);
        if (resolvedName.isNotEmpty) {
          nextSeller['name'] = resolvedName;
          nextSeller['displayName'] = resolvedName;
        }
        if (avatarUrl.isNotEmpty) {
          nextSeller['avatarUrl'] = avatarUrl;
        }
        if (sellerProfileId.isNotEmpty) {
          nextSeller['id'] = sellerProfileId;
        }
        nextSeller['userId'] = userId;
        product['seller'] = nextSeller;
      }

      return product;
    }).toList();

    final updatedFollowedPeople = followedPeople.map((person) {
      final nextPerson = Map<String, dynamic>.from(person);
      final personUserId =
          nextPerson['userId']?.toString().trim() ??
          nextPerson['id']?.toString().trim() ??
          '';
      final personSellerProfileId =
          nextPerson['sellerProfileId']?.toString().trim() ?? '';
      final matchesProfile =
          personUserId == userId ||
          (sellerProfileId.isNotEmpty &&
              personSellerProfileId == sellerProfileId);
      if (!matchesProfile) {
        return person;
      }

      hasChanged = true;
      if (resolvedName.isNotEmpty) {
        nextPerson['displayName'] = resolvedName;
        nextPerson['name'] = resolvedName;
      }
      if (avatarUrl.isNotEmpty) {
        nextPerson['avatarUrl'] = avatarUrl;
      }
      if (coverImageUrl.isNotEmpty) {
        nextPerson['coverImageUrl'] = coverImageUrl;
      }
      if (sellerProfileId.isNotEmpty) {
        nextPerson['sellerProfileId'] = sellerProfileId;
      }
      nextPerson['userId'] = userId;
      return nextPerson;
    }).toList();

    final isOwnProfile = _currentUserId.isNotEmpty && userId == _currentUserId;
    if (isOwnProfile && avatarUrl.isNotEmpty) {
      hasChanged = true;
    }

    if (!mounted || !hasChanged) {
      return;
    }

    setState(() {
      products = updatedProducts;
      followedPeople = updatedFollowedPeople;
      _isLoadingFollowedPeople = false;
      if (isOwnProfile && avatarUrl.isNotEmpty) {
        _avatarUrl = avatarUrl;
      }
    });
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      fetchProducts();
    }
  }

  @override
  Future<void> onPageReload() async {
    setState(() {
      products = [];
      followedPeople = [];
      skip = 0;
      hasMore = true;
      isLoading = false;
      _isLoadingFollowedPeople = true;
    });

    await fetchFollowedPeople();
    await fetchProducts();
    await fetchNotifications();
    await _loadCurrentUserRole();

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  Future<void> _loadCurrentUserRole() async {
    try {
      final user = await _authService.fetchCurrentUser();
      if (!mounted) {
        return;
      }

      final role =
          (user['role'] as String?)?.trim().toUpperCase() ?? 'CUSTOMER';
      final displayName = (user['displayName'] as String?)?.trim();
      final avatarUrl = (user['avatarUrl'] as String?)?.trim() ?? '';
      final userId = (user['id'] as String?)?.trim() ?? '';
      final locationLabel = (user['locationLabel'] as String?)?.trim() ?? '';
      final locationLatitude = (user['locationLatitude'] as num?)?.toDouble();
      final locationLongitude = (user['locationLongitude'] as num?)?.toDouble();
      setState(() {
        _isSeller = role == 'SELLER';
        _currentDisplayName = displayName != null && displayName.isNotEmpty
            ? displayName
            : _currentDisplayName;
        if (avatarUrl.isNotEmpty) _avatarUrl = avatarUrl;
        if (userId.isNotEmpty) _currentUserId = userId;
        _viewerLocationLabel = locationLabel;
        _viewerLocationLatitude = locationLatitude;
        _viewerLocationLongitude = locationLongitude;
      });
    } catch (_) {}
  }

  Future<void> fetchProducts() async {
    if (isLoading || !hasMore) return;
    setState(() => isLoading = true);

    try {
      final data = await _catalogApiService.fetchProducts(
        limit: limit,
        skip: skip,
        userLocationLabel: _viewerLocationLabel,
        userLocationLatitude: _viewerLocationLatitude,
        userLocationLongitude: _viewerLocationLongitude,
      );
      final List<Map<String, dynamic>> newProducts =
          ((data['products'] as List?) ?? const [])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .where(_isProductAvailable)
              .toList()
            ..sort(
              (a, b) => _productRankScore(b).compareTo(_productRankScore(a)),
            );

      if (!mounted) return;

      setState(() {
        skip += limit;
        products.removeWhere(
          (item) => item is Map<String, dynamic> && !_isProductAvailable(item),
        );
        products.addAll(newProducts);
        hasMore =
            products.length < ((data['total'] as int?) ?? products.length);
        isLoading = false;
      });

      if (kDebugMode) {
        print('Charge: ${products.length} produits, hasMore: $hasMore');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchFollowedPeople() async {
    try {
      final data = await _catalogApiService.fetchCurrentUserFollowing();
      if (!mounted) return;
      setState(() {
        followedPeople = data;
        _isLoadingFollowedPeople = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        followedPeople = const [];
        _isLoadingFollowedPeople = false;
      });
    }
  }

  Future<void> fetchNotifications() async {
    try {
      final data = await _notificationsApiService.fetchNotifications();
      if (!mounted) return;
      setState(() {
        _notifications
          ..clear()
          ..addAll(data);
      });
      NotificationsApiService.syncUnreadCount(_notifications);
    } catch (_) {}
  }

  Future<void> _openNotificationsPage() async {
    await AppAnalytics.instance.logNotificationOpened(type: 'avatar');
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationsPage(
          notifications: List<Map<String, dynamic>>.from(_notifications),
          onNotificationsChanged: (updatedNotifications) {
            if (!mounted) {
              return;
            }

            setState(() {
              _notifications
                ..clear()
                ..addAll(updatedNotifications);
            });
            NotificationsApiService.syncUnreadCount(_notifications);
          },
        ),
      ),
    );

    await fetchNotifications();
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
        SnackBar(
          content: Text(context.tr(BanayLocalizationKeys.homeLiveUnavailable)),
        ),
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
              context.tr(BanayLocalizationKeys.homeDefaultStoreName),
          sellerAvatarUrl: person['avatarUrl']?.toString() ?? '',
        ),
      ),
    );
  }

  Widget _buildFollowedPeopleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isSeller) ...[
          _buildSellerLiveButton(Theme.of(context)),
          const SizedBox(height: 4),
        ],
        if (_isLoadingFollowedPeople)
          const FollowedPeopleHListSkeleton()
        else
          DinamicFollowedPeopleHList(
            people: followedPeople,
            title: context.tr(BanayLocalizationKeys.homeFollowedTitle),
            emptyTitle: context.tr(
              BanayLocalizationKeys.homeFollowedEmptyTitle,
            ),
            emptyMessage: context.tr(
              BanayLocalizationKeys.homeFollowedEmptyMessage,
            ),
            onPersonTap: _openFollowedPerson,
            onLiveTap: _openFollowedPersonLive,
          ),
      ],
    );
  }

  Widget buildProductCardLoadig() {
    return const ProductCardSkeleton(variant: ProductCardVariant.marketplace);
  }

  Future<void> _openLivePreview(String title, String category) async {
    Map<String, dynamic>? liveInfo;
    var liveStarted = false;
    final livekitConfigIncompleteMessage = context.tr(
      BanayLocalizationKeys.homeLivekitConfigIncomplete,
    );

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
        throw AppApiException(livekitConfigIncompleteMessage);
      }

      if (!mounted) {
        return;
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
        SnackBar(
          content: Text(context.tr(BanayLocalizationKeys.homeCannotStartLive)),
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

  Future<void> _showLaunchLiveSheet() async {
    final titleController = TextEditingController(
      text: context.tr(
        BanayLocalizationKeys.homeLiveDefaultTitle,
        params: {'name': _currentDisplayName},
      ),
    );
    final categoryController = TextEditingController(
      text: context.tr(BanayLocalizationKeys.homeLiveDefaultCategory),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final accentColor = theme.colorScheme.primary;
        final panelColor = theme.appColors.backgroundBase;
        final liveColor = theme.colorScheme.secondary;

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: panelColor,
              borderRadius: BorderRadius.circular(28),
            ),
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
                            context.tr(
                              BanayLocalizationKeys.homeCreateLiveTitle,
                            ),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr(
                              BanayLocalizationKeys.homeCreateLiveSubtitle,
                            ),
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
                  hintText: context.tr(BanayLocalizationKeys.homeLiveTitleHint),
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
                  hintText: context.tr(
                    BanayLocalizationKeys.homeLiveCategoryHint,
                  ),
                  leadingIcon: Icon(Icons.sell_outlined, color: accentColor),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final liveTitle = titleController.text.trim();
                      final liveCategory = categoryController.text.trim();

                      if (liveTitle.isEmpty) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.tr(
                                BanayLocalizationKeys.homeLiveTitleRequired,
                              ),
                            ),
                          ),
                        );
                        return;
                      }

                      if (liveCategory.isEmpty) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.tr(
                                BanayLocalizationKeys.homeLiveCategoryRequired,
                              ),
                            ),
                          ),
                        );
                        return;
                      }

                      Navigator.of(sheetContext).pop();
                      _openLivePreview(liveTitle, liveCategory);
                    },
                    icon: const Icon(Icons.live_tv_rounded, size: 18),
                    label: Text(
                      context.tr(BanayLocalizationKeys.homeLaunchLive),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: theme.colorScheme.onPrimary,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSellerLiveButton(ThemeData theme) {
    final appColors = theme.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showLaunchLiveSheet,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  appColors.liveIndicator.withValues(alpha: 0.18),
                  appColors.liveIndicator.withValues(alpha: 0.08),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: appColors.liveIndicator.withValues(alpha: 0.38),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: appColors.liveIndicator,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.live_tv_rounded,
                  size: 18,
                  color: appColors.liveIndicator,
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr(BanayLocalizationKeys.homeStartLive),
                  style: TextStyle(
                    color: appColors.liveIndicator,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final visibleProducts = products
        .whereType<Map<String, dynamic>>()
        .where(_isProductAvailable)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: appColors.authBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
              child: Row(
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'B',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.primary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        TextSpan(
                          text: 'anay',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  ValueListenableBuilder<int>(
                    valueListenable:
                        NotificationsApiService.unreadCountNotifier,
                    builder: (context, unreadNotificationCount, _) =>
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _openNotificationsPage,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              AppCircleNetworkAvatar(
                                imageUrl: _avatarUrl,
                                radius: 24,
                                userId: _currentUserId,
                                showPresenceBadge: false,
                              ),
                              if (unreadNotificationCount > 0)
                                Positioned(
                                  top: -3,
                                  right: -3,
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      minWidth: 18,
                                      minHeight: 18,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE53935),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: appColors.backgroundBase,
                                        width: 2,
                                      ),
                                    ),
                                    child: Text(
                                      unreadNotificationCount > 9
                                          ? '9+'
                                          : '$unreadNotificationCount',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: refreshPageWithDialog,
                    child: visibleProducts.isEmpty && isLoading
                        ? ListView(
                            padding: EdgeInsets.zero,
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              _buildFollowedPeopleSection(),
                              ...List.generate(
                                8,
                                (_) => buildProductCardLoadig(),
                              ),
                            ],
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.zero,
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: visibleProducts.length + 2,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return _buildFollowedPeopleSection();
                              }

                              if (index == visibleProducts.length + 1) {
                                if (isLoading) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Column(
                                      children: List.generate(
                                        2,
                                        (_) => buildProductCardLoadig(),
                                      ),
                                    ),
                                  );
                                }
                                if (!hasMore) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text(
                                        context.tr(
                                          BanayLocalizationKeys
                                              .homeNoMoreProducts,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              }

                              return ProductCard(
                                product: visibleProducts[index - 1],
                                variant: ProductCardVariant.marketplace,
                                onProductOpen: (product, isLiked) =>
                                    Navigator.of(context).push(
                                      PageRouteBuilder(
                                        pageBuilder: (_, _, _) =>
                                            ProductDetailPage(
                                              product: product,
                                              initialLikeCount:
                                                  (product['likesCount']
                                                          as num?)
                                                      ?.toInt() ??
                                                  0,
                                              initialCommentCount:
                                                  (product['commentsCount']
                                                          as num?)
                                                      ?.toInt() ??
                                                  0,
                                              initialShareCount:
                                                  (product['sharesCount']
                                                          as num?)
                                                      ?.toInt() ??
                                                  0,
                                              initialIsLiked: isLiked,
                                              initialIsSubscribed:
                                                  _isFollowedSeller(product),
                                            ),
                                        transitionDuration: Duration.zero,
                                        reverseTransitionDuration:
                                            Duration.zero,
                                      ),
                                    ),
                              );
                            },
                          ),
                  ),
                  if (isOffline)
                    const AppOfflineBanner(
                      bottomOffset: _offlineBannerBottomOffset,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
