import 'dart:async';

import 'package:bahibo/auth/phoneNumber.dart';
import 'package:bahibo/component/app_comments_sheet.dart';
import 'package:bahibo/component/app_likes_sheet.dart';
import 'package:bahibo/component/profile_models.dart';
import 'package:bahibo/component/user_list_page.dart';
import 'package:bahibo/page/productDetail.dart';
import 'package:bahibo/component/theme_menu_button.dart';
import 'package:bahibo/services/app_api_client.dart';
import 'package:bahibo/services/app_auth_service.dart';
import 'package:bahibo/services/catalog_api_service.dart';
import 'package:bahibo/services/chat_realtime_service.dart';
import 'package:bahibo/services/notifications_api_service.dart';
import 'package:bahibo/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';

class NotificationsPage extends StatefulWidget {
  final List<Map<String, dynamic>> notifications;
  final ValueChanged<List<Map<String, dynamic>>>? onNotificationsChanged;

  const NotificationsPage({
    super.key,
    required this.notifications,
    this.onNotificationsChanged,
  });

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static final AppAuthService _authService = AppAuthService();
  static final CatalogApiService _catalogApiService = CatalogApiService();
  static final NotificationsApiService _notificationsApiService =
      NotificationsApiService();

  final List<Map<String, dynamic>> _notifications = [];
  StreamSubscription<Map<String, dynamic>>? _realtimeEventsSubscription;

  @override
  void initState() {
    super.initState();
    _notifications.addAll(widget.notifications);
    _bindRealtimeNotifications();
  }

  @override
  void dispose() {
    _realtimeEventsSubscription?.cancel();
    super.dispose();
  }

  void _bindRealtimeNotifications() {
    ChatRealtimeService.instance.ensureConnected();
    _realtimeEventsSubscription?.cancel();
    _realtimeEventsSubscription = ChatRealtimeService.instance.events.listen((
      event,
    ) {
      final type = event['type']?.toString();
      if (type != 'notifications:updated') {
        return;
      }

      unawaited(_refreshNotifications());
    });
  }

  Future<void> _refreshNotifications() async {
    try {
      final data = await _notificationsApiService.fetchNotifications();
      if (!mounted) {
        return;
      }
      setState(() {
        _notifications
          ..clear()
          ..addAll(data);
      });
      _publishNotificationsChanged();
    } on AppApiException {
      // Ignore transient refresh failures for realtime updates.
    }
  }

  void _publishNotificationsChanged() {
    widget.onNotificationsChanged?.call(
      _notifications.map(Map<String, dynamic>.from).toList(),
    );
  }

  Future<void> _markNotificationAsRead(
    Map<String, dynamic> notification,
  ) async {
    final notificationId = notification['id']?.toString();
    if (notificationId == null || notificationId.isEmpty) {
      return;
    }

    final index = _notifications.indexWhere(
      (item) => item['id']?.toString() == notificationId,
    );
    if (index == -1 || _notifications[index]['unread'] != true) {
      return;
    }

    final previousNotification = Map<String, dynamic>.from(
      _notifications[index],
    );

    setState(() {
      _notifications[index] = {..._notifications[index], 'unread': false};
    });
    _publishNotificationsChanged();

    try {
      await _notificationsApiService.markNotificationAsRead(notificationId);
    } on AppApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _notifications[index] = previousNotification;
      });
      _publishNotificationsChanged();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _showInfoSheet(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<String> paragraphs,
  }) {
    final theme = Theme.of(context);

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final sheetTheme = Theme.of(sheetContext);
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              decoration: BoxDecoration(
                color: sheetTheme.cardColor,
                borderRadius: BorderRadius.circular(28),
              ),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: sheetTheme.dividerColor.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: sheetTheme.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          icon,
                          color: sheetTheme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          title,
                          style: sheetTheme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ...paragraphs.map(
                    (paragraph) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        paragraph,
                        style: sheetTheme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.76,
                          ),
                          height: 1.5,
                        ),
                      ),
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

  Future<bool> _confirmLogout(BuildContext context) async {
    final decision = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Deconnexion'),
        content: const Text(
          'Voulez-vous vraiment vous deconnecter de ce compte ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Deconnecter'),
          ),
        ],
      ),
    );

    return decision ?? false;
  }

  Future<void> _logout(BuildContext context) async {
    final shouldLogout = await _confirmLogout(context);
    if (!shouldLogout || !context.mounted) {
      return;
    }

    try {
      await _authService.logout();
    } on AppApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
      return;
    }

    if (!context.mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PhoneNumberPage()),
      (route) => false,
    );
  }

  Future<void> _handleMenuSelection(
    BuildContext context,
    _NotificationAppBarAction action,
  ) async {
    switch (action) {
      case _NotificationAppBarAction.theme:
        await showThemeSelectionSheet(context);
        return;
      case _NotificationAppBarAction.conditions:
        await _showInfoSheet(
          context,
          title: 'Conditions et regles de confidentialite',
          icon: Icons.verified_user_outlined,
          paragraphs: const [
            'Vos informations sont utilisees uniquement pour ameliorer les recommandations, les notifications et les echanges avec les vendeurs que vous suivez.',
            'Bahibo protege les donnees partagees dans l\'application et limite leur affichage aux actions strictement necessaires a votre experience.',
          ],
        );
        return;
      case _NotificationAppBarAction.help:
        await _showInfoSheet(
          context,
          title: 'Aide',
          icon: Icons.help_outline_rounded,
          paragraphs: const [
            'Consultez vos notifications pour suivre les nouveaux produits, l\'activite des vendeurs et les mises a jour de votre reseau.',
            'Si une notification semble incomplete, utilisez la recherche pour retrouver rapidement le vendeur ou le produit concerne.',
          ],
        );
        return;
      case _NotificationAppBarAction.comment:
        await _showInfoSheet(
          context,
          title: 'Commentaires',
          icon: Icons.rate_review_outlined,
          paragraphs: const [
            'Vous pouvez nous envoyer vos remarques sur les notifications, la recherche ou l\'affichage des produits afin d\'ameliorer l\'experience utilisateur.',
            'Vos commentaires nous aident a prioriser les corrections et les nouvelles fonctionnalites de l\'application.',
          ],
        );
        return;
      case _NotificationAppBarAction.logout:
        await _logout(context);
        return;
    }
  }

  Future<void> _openNotification(
    BuildContext context,
    Map<String, dynamic> notification,
  ) async {
    await _markNotificationAsRead(notification);

    if (!context.mounted) {
      return;
    }

    final type = (notification['type'] as String? ?? '').trim();

    switch (type) {
      case 'product_added':
      case 'product_updated':
        await _openProductNotification(context, notification);
        return;
      case 'followed_product_comment':
      case 'product_comment':
        await _openProductNotification(
          context,
          notification,
          initialAction: ProductDetailInitialAction.comments,
        );
        return;
      case 'product_like':
        await _openProductNotification(
          context,
          notification,
          initialAction: ProductDetailInitialAction.likes,
        );
        return;
      case 'profile_view':
        await _openProfileViewers(context, notification);
        return;
      default:
        await _openProductNotification(context, notification);
        return;
    }
  }

  Future<void> _openProductNotification(
    BuildContext context,
    Map<String, dynamic> notification, {
    ProductDetailInitialAction initialAction = ProductDetailInitialAction.none,
  }) async {
    final productId = (notification['productId'] as String? ?? '').trim();
    if (productId.isEmpty) {
      _showNotificationActionUnavailable(context);
      return;
    }

    try {
      final product = await _catalogApiService.fetchProductById(productId);
      if (!context.mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductDetailPage(
            product: product,
            initialAction: initialAction,
            initialLikes: _buildLikeItems(notification),
            initialComments: _buildCommentItems(notification),
            initialLikeCount: _readInt(notification['likeCount']),
            initialCommentCount: _readInt(notification['commentCount']),
          ),
        ),
      );
    } on AppApiException catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _openProfileViewers(
    BuildContext context,
    Map<String, dynamic> notification,
  ) async {
    final actors = ((notification['actors'] as List?) ?? const [])
        .whereType<Map>()
        .map((actor) => Map<String, dynamic>.from(actor))
        .toList();

    if (actors.isEmpty) {
      _showNotificationActionUnavailable(context);
      return;
    }

    final users = actors
        .map(
          (actor) => UserListItemData(
            name: (actor['name'] as String?) ?? 'Utilisateur Bahibo',
            subtitle: 'A consulte votre profil.',
            imageUrl: (actor['avatarUrl'] as String?) ?? '',
            trailingText: (actor['timeLabel'] as String?) ?? 'recent',
            profileData: buildProfileFromUser(
              userId: actor['id'] as String?,
              name: (actor['name'] as String?) ?? 'Utilisateur Bahibo',
              avatarUrl: (actor['avatarUrl'] as String?) ?? '',
              subtitle: 'A consulte votre profil Bahibo.',
            ),
          ),
        )
        .toList();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserListPage(title: 'Vues du profil', users: users),
      ),
    );
  }

  List<AppLikeItem> _buildLikeItems(Map<String, dynamic> notification) {
    final actors = ((notification['actors'] as List?) ?? const [])
        .whereType<Map>()
        .map((actor) => Map<String, dynamic>.from(actor))
        .toList();

    if (actors.isEmpty) {
      return defaultAppLikes();
    }

    return actors
        .map(
          (actor) => AppLikeItem(
            authorId: actor['id']?.toString(),
            authorName: (actor['name'] as String?) ?? 'Utilisateur Bahibo',
            avatarUrl: (actor['avatarUrl'] as String?) ?? '',
            timeLabel: (actor['timeLabel'] as String?) ?? 'recent',
          ),
        )
        .toList();
  }

  List<AppCommentItem> _buildCommentItems(Map<String, dynamic> notification) {
    final actors = ((notification['actors'] as List?) ?? const [])
        .whereType<Map>()
        .map((actor) => Map<String, dynamic>.from(actor))
        .toList();

    if (actors.isEmpty) {
      return defaultAppComments();
    }

    final productName =
        (notification['productName'] as String?) ?? 'ce produit';
    return actors
        .map(
          (actor) => AppCommentItem(
            authorName: (actor['name'] as String?) ?? 'Utilisateur Bahibo',
            avatarUrl: (actor['avatarUrl'] as String?) ?? '',
            timeLabel: (actor['timeLabel'] as String?) ?? 'recent',
            message: 'A commente le produit $productName.',
          ),
        )
        .toList();
  }

  int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  void _showNotificationActionUnavailable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Les details de cette notification ne sont pas disponibles pour le moment.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final colorScheme = theme.colorScheme;
    final groupedNotifications = <String, List<Map<String, dynamic>>>{};

    for (final notification in _notifications) {
      final section = notification['section'] as String? ?? 'Recents';
      groupedNotifications.putIfAbsent(section, () => []).add(notification);
    }

    return Scaffold(
      backgroundColor: appColors.backgroundBase,
      appBar: AppBar(
        backgroundColor: appColors.backgroundBase,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: Text(
          'Notifications',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          PopupMenuButton<_NotificationAppBarAction>(
            onSelected: (action) => _handleMenuSelection(context, action),
            tooltip: 'Plus',
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _NotificationAppBarAction.theme,
                child: _NotificationMenuItem(
                  icon: Icons.palette_outlined,
                  label: 'Theme',
                ),
              ),
              PopupMenuItem(
                value: _NotificationAppBarAction.conditions,
                child: _NotificationMenuItem(
                  icon: Icons.shield_outlined,
                  label: 'Conditions et regles de confidentialite',
                ),
              ),
              PopupMenuItem(
                value: _NotificationAppBarAction.help,
                child: _NotificationMenuItem(
                  icon: Icons.help_outline_rounded,
                  label: 'Aide',
                ),
              ),
              PopupMenuItem(
                value: _NotificationAppBarAction.comment,
                child: _NotificationMenuItem(
                  icon: Icons.rate_review_outlined,
                  label: 'Commentaires',
                ),
              ),
              PopupMenuItem(
                value: _NotificationAppBarAction.logout,
                child: _NotificationMenuItem(
                  icon: Icons.logout_rounded,
                  label: 'Deconnexion',
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
        children: groupedNotifications.entries
            .map(
              (entry) => _NotificationSection(
                title: entry.key,
                notifications: entry.value,
                onNotificationTap: (notification) =>
                    _openNotification(context, notification),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _NotificationSection extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> notifications;
  final Future<void> Function(Map<String, dynamic> notification)
  onNotificationTap;

  const _NotificationSection({
    required this.title,
    required this.notifications,
    required this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.76),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...notifications.map(
          (notification) => _NotificationTile(
            notification: notification,
            onTap: () => onNotificationTap(notification),
          ),
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> notification;
  final Future<void> Function() onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  _NotificationVisual _resolveVisual(String type) {
    switch (type) {
      case 'product_added':
        return const _NotificationVisual(
          icon: Icons.add_box_rounded,
          label: 'Nouveau produit',
        );
      case 'product_updated':
        return const _NotificationVisual(
          icon: Icons.price_change_rounded,
          label: 'Produit mis a jour',
        );
      case 'followed_product_comment':
        return const _NotificationVisual(
          icon: Icons.chat_bubble_rounded,
          label: 'Commentaire d\'un abonne',
        );
      case 'product_comment':
        return const _NotificationVisual(
          icon: Icons.mode_comment_rounded,
          label: 'Nouveaux commentaires',
        );
      case 'product_like':
        return const _NotificationVisual(
          icon: Icons.favorite_rounded,
          label: 'Nouveaux likes',
        );
      case 'profile_view':
        return const _NotificationVisual(
          icon: Icons.visibility_rounded,
          label: 'Vues du profil',
        );
      default:
        return const _NotificationVisual(
          icon: Icons.notifications_active_rounded,
          label: 'Notification',
        );
    }
  }

  String _resolveNotificationDescription({
    required String channel,
    required String description,
    required String content,
    required String productName,
  }) {
    final trimmedDescription = description.trim();
    if (trimmedDescription.isNotEmpty) {
      return trimmedDescription;
    }

    if (productName.trim().isNotEmpty) {
      return '$channel a ajoute le produit $productName.';
    }

    final trimmedContent = content.trim();
    if (trimmedContent.isNotEmpty) {
      return '$channel $trimmedContent';
    }

    return 'Nouvelle notification de $channel.';
  }

  String _formatRelativeTime(String value) {
    final normalizedValue = value.trim();
    if (normalizedValue.isEmpty) {
      return 'recemment';
    }

    final createdAt = DateTime.tryParse(normalizedValue)?.toLocal();
    if (createdAt == null) {
      return normalizedValue;
    }

    final difference = DateTime.now().difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'il y a quelques secondes';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final channel = notification['channel'] as String? ?? '';
    final type = notification['type'] as String? ?? '';
    final description = notification['description'] as String? ?? '';
    final productName = notification['productName'] as String? ?? '';
    final time = notification['time'] as String? ?? '';
    final relativeTime = _formatRelativeTime(time);
    final avatarUrl = notification['avatarUrl'] as String? ?? '';
    final thumbnailUrl = notification['thumbnailUrl'] as String? ?? '';
    final isUnread = notification['unread'] == true;
    final visual = _resolveVisual(type);
    final hasProductPreview = productName.trim().isNotEmpty;
    final descriptionColor = isUnread
        ? (theme.brightness == Brightness.dark
              ? Colors.white
              : colorScheme.onSurface)
        : colorScheme.onSurface.withValues(alpha: 0.52);
    final resolvedDescription = _resolveNotificationDescription(
      channel: channel,
      description: description,
      content: notification['content'] as String? ?? '',
      productName: productName,
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NotificationAvatar(label: channel, imageUrl: avatarUrl),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(visual.icon, size: 14, color: colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          visual.label,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    resolvedDescription,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: descriptionColor,
                      fontSize: 13,
                      fontWeight: isUnread ? FontWeight.w800 : FontWeight.w500,
                      height: 1.24,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    relativeTime,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.52),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _NotificationThumbnail(
              imageUrl: thumbnailUrl,
              width: 86,
              height: 62,
              showPlaceholder: !hasProductPreview,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationVisual {
  final IconData icon;
  final String label;

  const _NotificationVisual({required this.icon, required this.label});
}

class _NotificationAvatar extends StatelessWidget {
  final String label;
  final String imageUrl;

  const _NotificationAvatar({required this.label, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallback = label.trim().isEmpty
        ? 'N'
        : label.trim().substring(0, 1).toUpperCase();
    final hasImage = imageUrl.trim().isNotEmpty;

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.primary.withValues(alpha: 0.14),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.16),
          width: 1,
        ),
      ),
      child: ClipOval(
        child: !hasImage
            ? Center(
                child: Text(
                  fallback,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
              )
            : Image.network(
                imageUrl,
                width: 42,
                height: 42,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text(
                    fallback,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _NotificationThumbnail extends StatelessWidget {
  final String imageUrl;
  final double width;
  final double height;
  final bool showPlaceholder;

  const _NotificationThumbnail({
    required this.imageUrl,
    this.width = 96,
    this.height = 60,
    this.showPlaceholder = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (imageUrl.trim().isEmpty && !showPlaceholder) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: width,
        height: height,
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.42,
        ),
        child: imageUrl.isEmpty
            ? Icon(
                Icons.image_outlined,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.42),
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.image_not_supported_outlined,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.42),
                ),
              ),
      ),
    );
  }
}

enum _NotificationAppBarAction { theme, conditions, help, comment, logout }

class _NotificationMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _NotificationMenuItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
      ],
    );
  }
}
