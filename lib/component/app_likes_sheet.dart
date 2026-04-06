import 'package:flutter/material.dart';

import 'package:bahibo/component/app_network_image.dart';
import 'package:bahibo/component/profile_models.dart';
import 'package:bahibo/component/seller_profile_page.dart';
import 'package:bahibo/theme/app_theme_extensions.dart';

class AppLikeItem {
  final String? authorId;
  final String authorName;
  final String avatarUrl;
  final String timeLabel;

  const AppLikeItem({
    this.authorId,
    required this.authorName,
    required this.avatarUrl,
    required this.timeLabel,
  });
}

List<AppLikeItem> defaultAppLikes() {
  return const [
    AppLikeItem(
      authorName: 'Miora Andrianiaina',
      avatarUrl:
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=600',
      timeLabel: 'il y a 2 min',
    ),
    AppLikeItem(
      authorName: 'Aina Ravelona',
      avatarUrl:
          'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=600',
      timeLabel: 'il y a 16 min',
    ),
    AppLikeItem(
      authorName: 'Toky Rajaonarison',
      avatarUrl:
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=600',
      timeLabel: 'il y a 1 h',
    ),
  ];
}

Future<void> showAppLikesSheet(
  BuildContext context, {
  required int currentLikeCount,
  required List<AppLikeItem> likes,
}) {
  final appColors = Theme.of(context).appColors;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    barrierColor: appColors.overlaySurface,
    backgroundColor: appColors.panelBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) =>
        _AppLikesSheetContent(initialLikeCount: currentLikeCount, likes: likes),
  );
}

class _AppLikesSheetContent extends StatelessWidget {
  final int initialLikeCount;
  final List<AppLikeItem> likes;

  const _AppLikesSheetContent({
    required this.initialLikeCount,
    required this.likes,
  });

  void _openLikeAuthorProfile(BuildContext context, AppLikeItem like) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SellerProfilePage(
          profile: buildProfileFromUser(
            name: like.authorName,
            avatarUrl: like.avatarUrl,
            subtitle: 'Membre de la communaute Bahibo',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.72,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: appColors.heroBorder,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Likes',
                style: TextStyle(
                  color: appColors.heroForeground,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$initialLikeCount personnes ont aime ce produit',
                style: TextStyle(
                  color: theme.colorScheme.primary.withOpacity(0.72),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: likes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final like = likes[index];

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: appColors.heroSurface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: appColors.heroBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () =>
                                  _openLikeAuthorProfile(context, like),
                              customBorder: const CircleBorder(),
                              child: Container(
                                padding: const EdgeInsets.all(1.5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: appColors.success.withOpacity(0.32),
                                    width: 1.5,
                                  ),
                                ),
                                child: AppCircleNetworkAvatar(
                                  radius: 18,
                                  imageUrl: like.avatarUrl,
                                  userId: like.authorId,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => _openLikeAuthorProfile(
                                            context,
                                            like,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 2,
                                            ),
                                            child: Text(
                                              like.authorName,
                                              style: TextStyle(
                                                color:
                                                    theme.colorScheme.primary,
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      like.timeLabel,
                                      style: TextStyle(
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.52),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.favorite_rounded,
                                      size: 16,
                                      color: appColors.favoriteAccent,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'A aime ce produit',
                                      style: TextStyle(
                                        color: appColors.heroForeground,
                                        fontSize: 13,
                                        height: 1.35,
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
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
