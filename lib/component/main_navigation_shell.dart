import 'dart:async';

import 'package:banay/component/profile_models.dart';
import 'package:banay/page/chat_page.dart';
import 'package:banay/page/navigation/main_home_panel.dart';
import 'package:banay/page/navigation/main_navigation_account_panel.dart';
import 'package:banay/page/navigation/main_simple_user.dart';
import 'package:banay/page/navigation/main_navigation_messages_panel.dart';
import 'package:banay/page/navigation/main_navigation_search_panel.dart';
import 'package:banay/page/notifications_page.dart';
import 'package:banay/page/productDetail.dart';
import 'package:banay/services/app_api_client.dart';
import 'package:banay/services/app_auth_service.dart';
import 'package:banay/services/chat_realtime_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:banay/theme/app_theme_extensions.dart';

class MainNavigationItem {
  final IconData icon;
  final String label;

  const MainNavigationItem({required this.icon, required this.label});
}

const List<MainNavigationItem> BANAYMainNavigationItems = [
  MainNavigationItem(icon: Icons.home_filled, label: 'Accueil'),
  MainNavigationItem(icon: Icons.search_rounded, label: 'Recherche'),
  MainNavigationItem(icon: Icons.message, label: 'Messages'),
  MainNavigationItem(icon: Icons.person, label: 'Compte'),
];

class BANAYNavigationShell extends StatefulWidget {
  static final GlobalKey<MainNavigationShellState> shellKey =
      GlobalKey<MainNavigationShellState>();

  final int initialIndex;

  const BANAYNavigationShell({super.key, this.initialIndex = 0});

  @override
  State<BANAYNavigationShell> createState() => MainNavigationShellState();
}

class MainNavigationShellState extends State<BANAYNavigationShell> {
  final AppAuthService _authService = AppAuthService();
  static const Duration _exitConfirmationWindow = Duration(seconds: 2);

  late int _currentIndex;
  bool _usesSellerAccountPanel = false;
  UserProfileData? _sellerAccountProfile;
  StreamSubscription<Map<String, dynamic>>? _profileEventsSubscription;
  DateTime? _lastExitAttemptAt;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadAccountPanelKind();
    _bindRealtimeProfileUpdates();
  }

  @override
  void dispose() {
    _profileEventsSubscription?.cancel();
    super.dispose();
  }

  void _handleNavigationSelection(int index) {
    if (_currentIndex == index) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BANAYNavigationShell(initialIndex: index),
      ),
    );
  }

  Future<void> _loadAccountPanelKind() async {
    try {
      final user = await _authService.fetchCurrentUser();
      if (!mounted) {
        return;
      }

      final role = (user['role'] as String?)?.trim() ?? 'CUSTOMER';
      setState(() {
        _usesSellerAccountPanel = role == 'SELLER';
        _sellerAccountProfile = role == 'SELLER'
            ? buildSellerAccountProfileFromCurrentUser(user)
            : null;
      });
    } on AppApiException {
      if (!mounted) {
        return;
      }

      setState(() {
        _usesSellerAccountPanel = false;
        _sellerAccountProfile = null;
      });
    }
  }

  void _bindRealtimeProfileUpdates() {
    ChatRealtimeService.instance.ensureConnected();
    _profileEventsSubscription?.cancel();
    _profileEventsSubscription = ChatRealtimeService.instance.events.listen((
      event,
    ) {
      final type = event['type']?.toString();
      if (type != 'profile:shop-request-updated' && type != 'profile:updated') {
        return;
      }

      unawaited(_loadAccountPanelKind());
    });
  }

  Future<void> openConversationFromNotification({
    required String conversationId,
    required String sellerName,
    required String sellerRole,
    required String avatarUrl,
  }) async {
    if (mounted && _currentIndex != 2) {
      setState(() => _currentIndex = 2);
    }

    await Future<void>.delayed(const Duration(milliseconds: 30));
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          conversationId: conversationId,
          productPageBuilder: (product, {openedFromChat = false}) =>
              ProductDetailPage(
                product: product,
                openedFromChat: openedFromChat,
              ),
          sellerName: sellerName,
          sellerRole: sellerRole,
          avatarUrl: avatarUrl,
        ),
      ),
    );
  }

  Future<void> openNotificationsFromNotification() async {
    if (mounted && _currentIndex != 0) {
      setState(() => _currentIndex = 0);
    }

    await Future<void>.delayed(const Duration(milliseconds: 30));
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NotificationsPage(notifications: []),
      ),
    );
  }

  Future<bool> _handleWillPop() async {
    if (widget.initialIndex != 0) {
      return true;
    }

    final now = DateTime.now();
    final lastAttemptAt = _lastExitAttemptAt;
    final shouldConfirmExit =
        lastAttemptAt == null ||
        now.difference(lastAttemptAt) > _exitConfirmationWindow;

    if (shouldConfirmExit) {
      _lastExitAttemptAt = now;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Retourne une fois pour quitter'),
            duration: _exitConfirmationWindow,
          ),
        );
      return false;
    }

    await SystemNavigator.pop();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pages = [
      const MainHomePanel(),
      const MainNavigationSearchPanel(),
      const MainNavigationMessagesPanel(),
      _usesSellerAccountPanel
          ? MainNavigationAccountPanel(profile: _sellerAccountProfile)
          : const MainSimpleUser(),
    ];

    return WillPopScope(
      onWillPop: _handleWillPop,
      child: Scaffold(
        backgroundColor: theme.cardColor,
        body: Stack(
          children: [
            Positioned.fill(
              child: IndexedStack(index: _currentIndex, children: pages),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ValueListenableBuilder<int>(
                valueListenable: mainNavigationUnreadMessageCountNotifier,
                builder: (context, unreadMessageCount, _) => MainNavigationBar(
                  currentIndex: _currentIndex,
                  items: BANAYMainNavigationItems,
                  unreadMessageCount: unreadMessageCount,
                  onTap: _handleNavigationSelection,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MainNavigationBar extends StatelessWidget {
  final int currentIndex;
  final List<MainNavigationItem> items;
  final int unreadMessageCount;
  final ValueChanged<int> onTap;

  const MainNavigationBar({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.unreadMessageCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final barColor = theme.cardColor;
    final activeColor = theme.cardColor;
    final borderColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.outlineVariant.withValues(alpha: 0.18)
        : theme.colorScheme.onSurface.withValues(alpha: 0.12);
    final accentGreen = theme.colorScheme.primary;
    final inactiveIconColor = theme.brightness == Brightness.dark
        ? appColors.heroForeground
        : appColors.mutedText;
    final activeIconColor = accentGreen;
    const innerHorizontalPadding = 16.0;
    const barHeight = 38.0;
    const activeBubbleSize = 35.0;
    const cradleSize = 50.0;

    return SizedBox(
      height: barHeight + bottomInset + 10,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth =
              constraints.maxWidth - (innerHorizontalPadding * 2);
          final slotWidth = contentWidth / items.length;
          final activeLeft =
              innerHorizontalPadding +
              (slotWidth * currentIndex) +
              ((slotWidth - activeBubbleSize) / 2);
          final cradleLeft =
              innerHorizontalPadding +
              (slotWidth * currentIndex) +
              ((slotWidth - cradleSize) / 2);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: barHeight + bottomInset,
                  padding: EdgeInsets.fromLTRB(
                    innerHorizontalPadding,
                    0,
                    innerHorizontalPadding,
                    bottomInset,
                  ),
                  decoration: BoxDecoration(
                    color: barColor,
                    border: Border(top: BorderSide(color: borderColor)),
                    // borderRadius: const BorderRadius.only(
                    //   topLeft: Radius.circular(barRadius),
                    //   topRight: Radius.circular(barRadius),
                    // ),
                  ),
                  child: SizedBox(
                    height: barHeight,
                    child: Row(
                      children: List.generate(items.length, (index) {
                        final isSelected = index == currentIndex;
                        return Expanded(
                          child: Center(
                            child: isSelected
                                ? const SizedBox(
                                    width: activeBubbleSize,
                                    height: activeBubbleSize,
                                  )
                                : _CapsuleNavigationButton(
                                    icon: _navigationDisplayIcon(
                                      index,
                                      items[index].icon,
                                    ),
                                    badgeLabel: _navigationBadgeLabel(
                                      index,
                                      unreadMessageCount,
                                    ),
                                    isSelected: false,
                                    activeColor: activeColor,
                                    iconColor: inactiveIconColor,
                                    onTap: () => onTap(index),
                                    size: activeBubbleSize,
                                  ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: cradleLeft,
                top: -((cradleSize - barHeight) / 1.4),
                child: Container(
                  width: cradleSize,
                  height: cradleSize,

                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor, width: 2.5),
                    color: barColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 0),
                curve: Curves.easeOutCubic,
                left: activeLeft,
                top: 1.4,
                child: _CapsuleNavigationButton(
                  icon: _navigationDisplayIcon(
                    currentIndex,
                    items[currentIndex].icon,
                  ),
                  badgeLabel: _navigationBadgeLabel(
                    currentIndex,
                    unreadMessageCount,
                  ),
                  isSelected: true,
                  activeColor: activeColor,
                  iconColor: activeIconColor,
                  onTap: () => onTap(currentIndex),
                  size: activeBubbleSize,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String? _navigationBadgeLabel(int index, int unreadMessageCount) {
  if (index != 2 || unreadMessageCount <= 0) {
    return null;
  }

  if (unreadMessageCount > 9) {
    return '9+';
  }

  return unreadMessageCount.toString();
}

IconData _navigationDisplayIcon(int index, IconData fallback) {
  switch (index) {
    case 0:
      return Icons.home;
    case 1:
      return Icons.search_rounded;
    case 2:
      return Icons.message;
    case 3:
      return Icons.person;
    default:
      return fallback;
  }
}

class _CapsuleNavigationButton extends StatelessWidget {
  final IconData icon;
  final String? badgeLabel;
  final bool isSelected;
  final Color activeColor;
  final Color iconColor;
  final VoidCallback onTap;
  final double size;

  const _CapsuleNavigationButton({
    required this.icon,
    this.badgeLabel,
    required this.isSelected,
    required this.activeColor,
    required this.iconColor,
    required this.onTap,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badgeColor = theme.appColors.favoriteAccent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Icon(icon, size: isSelected ? 35 : 23, color: iconColor),
              ),
              if (badgeLabel != null)
                Positioned(
                  top: isSelected ? -4 : -2,
                  right: isSelected ? -6 : -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: theme.cardColor, width: 1.5),
                    ),
                    constraints: const BoxConstraints(minWidth: 20),
                    child: Text(
                      badgeLabel!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


