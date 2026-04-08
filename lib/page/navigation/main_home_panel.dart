import 'dart:async';

import 'package:bahibo/component/app_page_refresh.dart';
import 'package:bahibo/component/app_page_skeletons.dart';
import 'package:bahibo/component/profile_models.dart';
import 'package:bahibo/component/seller_profile_page.dart';
import 'package:bahibo/component/ui/dinamic_followed_people_h_list.dart';
import 'package:bahibo/component/user_profile_page.dart';
import 'package:bahibo/page/notifications_page.dart';
import 'package:bahibo/page/live/live_watch_page.dart';
import 'package:bahibo/services/catalog_api_service.dart';
import 'package:bahibo/services/chat_realtime_service.dart';
import 'package:bahibo/services/notifications_api_service.dart';
import 'package:bahibo/theme/app_theme_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../component/ProductCard.dart';

class MainHomePanel extends StatefulWidget {
  const MainHomePanel({super.key});

  @override
  State<MainHomePanel> createState() => _MainHomePanelState();
}

class _MainHomePanelState extends State<MainHomePanel>
    with AppPageRefreshMixin<MainHomePanel> {
  static const double _bottomContentPadding = 84;
  static const double _offlineBannerBottomOffset = 64;

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
  bool _isLoadingFollowedPeople = true;

  int get _unreadNotificationCount =>
      _notifications.where((item) => item['unread'] == true).length;

  @override
  void initState() {
    super.initState();
    initializePageRefresh();
    fetchFollowedPeople();
    fetchProducts();
    fetchNotifications();
    _bindRealtimeNotifications();
    _scrollController.addListener(_onScroll);
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
        unawaited(fetchNotifications());
      }

      if (type == 'live:updated') {
        unawaited(fetchFollowedPeople());
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

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  Future<void> fetchProducts() async {
    if (isLoading || !hasMore) return;
    setState(() => isLoading = true);

    try {
      final data = await _catalogApiService.fetchProducts(
        limit: limit,
        skip: skip,
      );
      final List<dynamic> newProducts = List<dynamic>.from(
        data['products'] as List? ?? const [],
      );

      if (!mounted) return;

      setState(() {
        skip += limit;
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
    } catch (_) {}
  }

  Future<void> _openNotificationsPage() async {
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
              'Boutique Bahibo',
          sellerAvatarUrl: person['avatarUrl']?.toString() ?? '',
        ),
      ),
    );
  }

  Widget _buildFollowedPeopleSection() {
    if (_isLoadingFollowedPeople) {
      return const FollowedPeopleHListSkeleton();
    }

    return DinamicFollowedPeopleHList(
      people: followedPeople,
      title: 'Vos abonnements',
      emptyTitle: 'Aucun abonnement pour le moment',
      emptyMessage: 'Abonnez-vous a des boutiques pour les retrouver ici.',
      onPersonTap: _openFollowedPerson,
      onLiveTap: _openFollowedPersonLive,
    );
  }

  Widget _buildNotificationButton(ThemeData theme) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: _openNotificationsPage,
          tooltip: 'Ouvrir les notifications',
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(12),
          ),
          icon: Icon(
            _unreadNotificationCount > 0
                ? Icons.notifications_active_rounded
                : Icons.notifications_none_rounded,
            color: Colors.white,
          ),
        ),
        if (_unreadNotificationCount > 0)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: theme.scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
              child: Text(
                _unreadNotificationCount > 9
                    ? '9+'
                    : '$_unreadNotificationCount',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget buildProductCardLoadig() {
    return const ProductCardSkeleton();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;

    return Scaffold(
      backgroundColor: appColors.authBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 5, 16, 7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Abaoly',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Row(children: [_buildNotificationButton(theme)]),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: refreshPageWithDialog,
                    child: products.isEmpty && isLoading
                        ? ListView(
                            padding: const EdgeInsets.only(
                              bottom: _bottomContentPadding,
                            ),
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
                            padding: const EdgeInsets.only(
                              bottom: _bottomContentPadding,
                            ),
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: products.length + 2,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return _buildFollowedPeopleSection();
                              }

                              if (index == products.length + 1) {
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
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text('Plus de produits 😊'),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              }

                              return ProductCard(
                                product:
                                    products[index - 1] as Map<String, dynamic>,
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
