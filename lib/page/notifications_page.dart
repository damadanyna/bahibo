import 'package:bahibo/auth/phoneNumber.dart';
import 'package:bahibo/component/app_network_image.dart';
import 'package:bahibo/component/theme_menu_button.dart';
import 'package:bahibo/services/app_api_client.dart';
import 'package:bahibo/services/app_auth_service.dart';
import 'package:bahibo/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';

class NotificationsPage extends StatelessWidget {
  final List<Map<String, dynamic>> notifications;
  static final AppAuthService _authService = AppAuthService();

  const NotificationsPage({super.key, required this.notifications});

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
          'Voulez-vous vraiment deconnecter ce compte ?',
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
          title: 'Conditions et regle de confidentialite',
          icon: Icons.verified_user_outlined,
          paragraphs: const [
            'Vos informations restent utilisees uniquement pour ameliorer les recommandations, les notifications et les echanges avec les vendeurs que vous suivez.',
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
            'Consultez vos notifications pour suivre les nouveaux produits, les activites des fournisseurs et les mises a jour de votre reseau.',
            'Si une notification semble incomplete, ouvrez la recherche pour retrouver rapidement le vendeur ou le produit concerne.',
          ],
        );
        return;
      case _NotificationAppBarAction.comment:
        await _showInfoSheet(
          context,
          title: 'Commentaire',
          icon: Icons.rate_review_outlined,
          paragraphs: const [
            'Vous pouvez nous envoyer vos remarques sur les notifications, la recherche ou l\'affichage des produits pour ameliorer l\'experience vendeur.',
            'Les commentaires servent a prioriser les corrections et les nouvelles fonctionnalites dans l\'application.',
          ],
        );
        return;
      case _NotificationAppBarAction.logout:
        await _logout(context);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final colorScheme = theme.colorScheme;
    final groupedNotifications = <String, List<Map<String, dynamic>>>{};

    for (final notification in notifications) {
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
                  label: 'Conditions et regle de confidentialite',
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
                  label: 'Commentaire',
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

  const _NotificationSection({
    required this.title,
    required this.notifications,
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
          (notification) => _NotificationTile(notification: notification),
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> notification;

  const _NotificationTile({required this.notification});

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

    return 'Nouvelle notification provenant du fournisseur $channel.';
  }

  String _resolveHeadline({
    required String content,
    required String productName,
  }) {
    if (content.trim().isNotEmpty) {
      return 'Mise en ligne : $content';
    }

    if (productName.trim().isNotEmpty) {
      return 'Mise en ligne : $productName';
    }

    return 'Mise en ligne : nouvelle activite';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final channel = notification['channel'] as String? ?? '';
    final content = notification['content'] as String? ?? '';
    final description = notification['description'] as String? ?? '';
    final productName = notification['productName'] as String? ?? '';
    final time = notification['time'] as String? ?? '';
    final avatarUrl = notification['avatarUrl'] as String? ?? '';
    final thumbnailUrl = notification['thumbnailUrl'] as String? ?? '';
    final isUnread = notification['unread'] == true;
    final hasProductPreview = productName.trim().isNotEmpty;
    final resolvedDescription = _resolveNotificationDescription(
      channel: channel,
      description: description,
      content: content,
      productName: productName,
    );
    final headline = _resolveHeadline(
      content: content,
      productName: productName,
    );

    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 20, right: 8),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isUnread
                      ? const Color(0xFF3EA6FF)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            _NotificationAvatar(label: channel, imageUrl: avatarUrl),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    headline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      height: 1.18,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    resolvedDescription,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.68),
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: theme.textTheme.bodySmall?.copyWith(
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
              width: 96,
              height: 72,
              showPlaceholder: !hasProductPreview,
            ),
          ],
        ),
      ),
    );
  }
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
      width: 34,
      height: 34,
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
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
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

class _NotificationProductPreview extends StatelessWidget {
  final String productName;
  final String imageUrl;

  const _NotificationProductPreview({
    required this.productName,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _NotificationThumbnail(imageUrl: imageUrl, width: 68, height: 52),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              productName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
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
                errorBuilder: (_, __, ___) => Icon(
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
