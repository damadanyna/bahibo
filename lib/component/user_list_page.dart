import 'package:flutter/material.dart';
import 'package:banay/component/app_back_button.dart';
import 'package:banay/component/app_network_image.dart';
import 'package:banay/component/app_page_skeletons.dart';
import 'package:banay/component/app_page_refresh.dart';
import 'package:banay/component/app_text_input.dart';
import 'package:banay/component/profile_models.dart';
import 'package:banay/services/app_auth_service.dart';
import 'package:banay/theme/app_theme_extensions.dart';

class UserListItemData {
  final String name;
  final String subtitle;
  final String imageUrl;
  final String trailingText;
  final String? userId;
  final UserProfileData? profileData;
  final WidgetBuilder? destinationBuilder;
  final Future<bool> Function()? onTrailingTap;

  const UserListItemData({
    required this.name,
    required this.subtitle,
    required this.imageUrl,
    required this.trailingText,
    this.userId,
    this.profileData,
    this.destinationBuilder,
    this.onTrailingTap,
  });
}

class UserListPage extends StatefulWidget {
  final String title;
  final List<UserListItemData> users;
  final int? totalCount;
  final Widget Function(UserListItemData user)? onUserTapBuilder;

  const UserListPage({
    super.key,
    required this.title,
    required this.users,
    this.totalCount,
    this.onUserTapBuilder,
  });

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage>
    with AppPageRefreshMixin<UserListPage> {
  final AppAuthService _authService = AppAuthService();
  final TextEditingController _searchController = TextEditingController();
  late List<UserListItemData> _users;
  final Set<String> _pendingTrailingActions = <String>{};
  String _searchQuery = '';
  bool _showEntrySkeleton = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _users = List<UserListItemData>.from(widget.users);
    initializePageRefresh();
    _loadCurrentUser();
    Future.delayed(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() => _showEntrySkeleton = false);
    });
  }

  @override
  void didUpdateWidget(covariant UserListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.users, widget.users)) {
      _users = List<UserListItemData>.from(widget.users);
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _authService.fetchCurrentUser();
      final userId = user['id']?.toString().trim();
      if (!mounted) {
        return;
      }
      setState(() {
        _currentUserId = userId != null && userId.isNotEmpty ? userId : null;
      });
    } catch (_) {
      // Keep the list usable even if the current user cannot be resolved.
    }
  }

  String _resolveDisplayName(UserListItemData user) {
    final currentUserId = _currentUserId;
    final listedUserId = user.profileData?.userId?.trim();
    if (currentUserId != null &&
        listedUserId != null &&
        listedUserId.isNotEmpty &&
        listedUserId == currentUserId) {
      return 'Vous';
    }

    return user.name;
  }

  @override
  void dispose() {
    disposePageRefresh();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Future<void> onPageReload() async {
    if (mounted) {
      setState(() => _showEntrySkeleton = true);
    }
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _showEntrySkeleton = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appColors = theme.appColors;
    final primary = theme.colorScheme.primary;
    final backgroundColor = appColors.backgroundBase;
    final surfaceColor = appColors.panelBackground;
    final mutedColor = appColors.mutedText;
    final titleColor =
        theme.textTheme.headlineSmall?.color ?? theme.colorScheme.onSurface;
    final filteredUsers = _users.where((user) {
      final normalizedQuery = _searchQuery.trim().toLowerCase();
      if (normalizedQuery.isEmpty) return true;
      return user.name.toLowerCase().contains(normalizedQuery);
    }).toList();
    final displayedCount = _searchQuery.trim().isEmpty
        ? (widget.totalCount ?? filteredUsers.length)
        : filteredUsers.length;
    final hasSourceUsers = _users.isNotEmpty;
    final itemCount = filteredUsers.isEmpty ? 2 : filteredUsers.length + 1;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: refreshPageWithDialog,
            child: _showEntrySkeleton
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [UserListSkeleton()],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: itemCount,
                    separatorBuilder: (_, index) => index == 0
                        ? const SizedBox(height: 18)
                        : const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Container(
                          margin: const EdgeInsets.only(top: 24),
                          padding: const EdgeInsets.fromLTRB(20, 88, 20, 20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                primary.withValues(alpha: isDark ? 0.30 : 0.18),
                                surfaceColor,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: titleColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$displayedCount profils disponibles',
                                style: TextStyle(
                                  color: mutedColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              AppInputContainer(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.search,
                                      color: primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: _searchController,
                                        cursorColor: primary,
                                        onChanged: (value) {
                                          setState(() => _searchQuery = value);
                                        },
                                        decoration: appInputDecoration(
                                          context,
                                          hintText: 'Explorer la liste',
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: 6,
                                              ),
                                        ),
                                        style: appInputTextStyle(context),
                                      ),
                                    ),
                                    if (_searchQuery.isNotEmpty)
                                      GestureDetector(
                                        onTap: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                        child: Icon(
                                          Icons.close,
                                          color: mutedColor,
                                        ),
                                      )
                                    else
                                      Icon(Icons.tune, color: mutedColor),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (filteredUsers.isEmpty) {
                        return _buildEmptyStateCard(
                          context: context,
                          surfaceColor: surfaceColor,
                          mutedColor: mutedColor,
                          icon: hasSourceUsers
                              ? Icons.search_off_rounded
                              : Icons.people_outline_rounded,
                          title: hasSourceUsers
                              ? 'Aucun profil trouve'
                              : 'Aucun profil disponible',
                          message: hasSourceUsers
                              ? 'Essaie un autre nom dans la recherche.'
                              : 'Les profils apparaitront ici des qu\'ils seront disponibles.',
                        );
                      }

                      final user = filteredUsers[index - 1];
                      return _buildUserCard(
                        context: context,
                        user: user,
                        isDark: isDark,
                        surfaceColor: surfaceColor,
                        mutedColor: mutedColor,
                        primary: primary,
                      );
                    },
                  ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 24,
            child: const AppBackButton(),
          ),
          if (isOffline) const AppOfflineBanner(),
        ],
      ),
    );
  }

  Widget _buildUserCard({
    required BuildContext context,
    required UserListItemData user,
    required bool isDark,
    required Color surfaceColor,
    required Color mutedColor,
    required Color primary,
  }) {
    final destinationBuilder =
        user.destinationBuilder ??
        (widget.onUserTapBuilder == null
            ? null
            : (_) => widget.onUserTapBuilder!(user));
    final trailingActionKey = user.userId ?? user.name;
    final isTrailingActionPending = _pendingTrailingActions.contains(
      trailingActionKey,
    );

    Future<void> handleTrailingAction() async {
      final onTrailingTap = user.onTrailingTap;
      if (onTrailingTap == null || isTrailingActionPending) {
        return;
      }

      setState(() => _pendingTrailingActions.add(trailingActionKey));
      var shouldRemove = false;
      try {
        shouldRemove = await onTrailingTap();
      } finally {
        if (mounted) {
          setState(() {
            _pendingTrailingActions.remove(trailingActionKey);
            if (shouldRemove) {
              _users.remove(user);
            }
          });
        }
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: destinationBuilder == null
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: destinationBuilder),
                );
              },
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: primary.withValues(alpha: 0.25),
                    width: 2,
                  ),
                ),
                child: AppCircleNetworkAvatar(
                  radius: 28,
                  imageUrl: user.imageUrl,
                  userId: user.userId ?? user.profileData?.userId,
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
                            _resolveDisplayName(user),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Icon(Icons.verified, size: 18, color: primary),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      user.subtitle,
                      style: TextStyle(
                        color: mutedColor,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: user.onTrailingTap == null
                      ? null
                      : handleTrailingAction,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: isTrailingActionPending
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                primary,
                              ),
                            ),
                          )
                        : Text(
                            user.trailingText,
                            style: TextStyle(
                              color: primary,
                              fontWeight: FontWeight.w800,
                            ),
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

  Widget _buildEmptyStateCard({
    required BuildContext context,
    required Color surfaceColor,
    required Color mutedColor,
    required IconData icon,
    required String title,
    required String message,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(icon, size: 38, color: mutedColor),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: mutedColor),
          ),
        ],
      ),
    );
  }
}
