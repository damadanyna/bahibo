import 'package:bahibo/component/app_back_button.dart';
import 'package:bahibo/component/app_network_image.dart';
import 'package:bahibo/component/profile_models.dart';
import 'package:bahibo/page/image_viewer_page.dart';
import 'package:bahibo/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';

class UserProfilePage extends StatelessWidget {
  const UserProfilePage({super.key, required this.profile});

  final UserProfileData profile;

  void _openImageViewer(
    BuildContext context, {
    required String imageUrl,
    required String heroTag,
  }) {
    final normalizedUrl = imageUrl.trim();
    if (normalizedUrl.isEmpty) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImageViewerPage(
          imageUrls: [normalizedUrl],
          heroTag: heroTag,
          overlay: ImageViewerOverlayData(
            sellerName: profile.name,
            sellerUserId: profile.userId,
            sellerAvatarUrl: profile.avatarUrl,
            isUserProfileImage: true,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: appColors.inputBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: appColors.mutedText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final coverHeroTag = 'user-profile-cover-${profile.userId ?? profile.name}';
    final avatarHeroTag =
        'user-profile-avatar-${profile.userId ?? profile.name}';

    return Scaffold(
      backgroundColor: appColors.backgroundBase,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 36),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(32),
                    ),
                    border: Border.all(color: appColors.inputBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 238,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _openImageViewer(
                                context,
                                imageUrl: profile.coverImageUrl,
                                heroTag: coverHeroTag,
                              ),
                              child: SizedBox(
                                height: 190,
                                width: double.infinity,
                                child: Hero(
                                  tag: coverHeroTag,
                                  child: profile.coverImageUrl.trim().isNotEmpty
                                      ? AppNetworkImage(
                                          imageUrl: profile.coverImageUrl,
                                          fit: BoxFit.cover,
                                          errorChild: Container(
                                            color: const Color(0xFF9E9E9E),
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons.person,
                                              color: Colors.white,
                                              size: 44,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          color: const Color(0xFF9E9E9E),
                                          alignment: Alignment.center,
                                          child: const Icon(
                                            Icons.person,
                                            color: Colors.white,
                                            size: 74,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: 190,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.08),
                                        Colors.black.withValues(alpha: 0.28),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 24,
                              bottom: 0,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _openImageViewer(
                                  context,
                                  imageUrl: profile.avatarUrl,
                                  heroTag: avatarHeroTag,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: theme.cardColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: appColors.inputBorder,
                                    ),
                                  ),
                                  child: Hero(
                                    tag: avatarHeroTag,
                                    child: profile.avatarUrl.trim().isNotEmpty
                                        ? AppCircleNetworkAvatar(
                                            imageUrl: profile.avatarUrl,
                                            radius: 44,
                                            userId: profile.userId,
                                          )
                                        : Container(
                                            width: 88,
                                            height: 88,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Color(0xFF9E9E9E),
                                            ),
                                            child: const Icon(
                                              Icons.person_rounded,
                                              color: Colors.white,
                                              size: 52,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.name,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.10,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    profile.roleLabel,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (profile.headline.trim().isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      profile.headline,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: appColors.mutedText,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Text(
                              profile.about,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: appColors.mutedText,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: Column(
                    children: [
                      _buildMetricCard(
                        context,
                        icon: Icons.favorite_border_rounded,
                        label: 'Likes total',
                        value: profile.totalLikesCount,
                      ),
                      const SizedBox(height: 12),
                      _buildMetricCard(
                        context,
                        icon: Icons.visibility_outlined,
                        label: 'Vues profil',
                        value: profile.visitorCount,
                      ),
                      const SizedBox(height: 12),
                      _buildMetricCard(
                        context,
                        icon: Icons.inventory_2_outlined,
                        label: 'Produits',
                        value: profile.productCount,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(top: 16, left: 24, child: const AppBackButton()),
          ],
        ),
      ),
    );
  }
}
