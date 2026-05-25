import 'dart:async';

import 'package:banay/component/app_network_image.dart';
import 'package:banay/component/app_page_skeletons.dart';
import 'package:banay/localization/banay_localizations.dart';
import 'package:banay/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';

typedef DynamicFollowedPersonTapCallback =
    FutureOr<void> Function(Map<String, dynamic> person);
typedef DynamicFollowedPersonLiveTapCallback =
    FutureOr<void> Function(Map<String, dynamic> person);

String resolveFollowedPersonName(
  Map<String, dynamic> person, {
  required String fallbackName,
}) {
  return person['displayName']?.toString().trim().isNotEmpty == true
      ? person['displayName'].toString().trim()
      : person['name']?.toString().trim().isNotEmpty == true
      ? person['name'].toString().trim()
      : fallbackName;
}

String resolveFollowedPersonSubtitle(
  Map<String, dynamic> person, {
  required String fallbackSubtitle,
}) {
  return person['subtitle']?.toString().trim().isNotEmpty == true
      ? person['subtitle'].toString().trim()
      : person['headline']?.toString().trim().isNotEmpty == true
      ? person['headline'].toString().trim()
      : person['locationLabel']?.toString().trim().isNotEmpty == true
      ? person['locationLabel'].toString().trim()
      : person['sellerProfileDescription']?.toString().trim().isNotEmpty == true
      ? person['sellerProfileDescription'].toString().trim()
      : fallbackSubtitle;
}

String resolveFollowedPersonTrailingText(
  Map<String, dynamic> person, {
  required String sellerBadge,
  required String profileBadge,
}) {
  return person['trailingText']?.toString().trim().isNotEmpty == true
      ? person['trailingText'].toString().trim()
      : person['role']?.toString().trim().toUpperCase() == 'SELLER'
      ? sellerBadge
      : profileBadge;
}

String? resolveFollowedPersonUserId(Map<String, dynamic> person) {
  final userId = person['userId']?.toString().trim();
  if (userId != null && userId.isNotEmpty) {
    return userId;
  }

  final id = person['id']?.toString().trim();
  if (id != null && id.isNotEmpty) {
    return id;
  }

  return null;
}

String resolveFollowedPersonAvatarUrl(Map<String, dynamic> person) {
  final avatarUrl = person['avatarUrl']?.toString().trim();
  if (avatarUrl != null && avatarUrl.isNotEmpty) {
    return avatarUrl;
  }

  return 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(person['displayName']?.toString().trim().isNotEmpty == true
      ? person['displayName'].toString().trim()
      : person['name']?.toString().trim().isNotEmpty == true
      ? person['name'].toString().trim()
      : 'BANAY')}&background=E5E7EB&color=111827';
}

bool isFollowedPersonLive(Map<String, dynamic> person) {
  return person['isLive'] == true;
}

String resolveFollowedPersonLiveTitle(
  Map<String, dynamic> person, {
  required String fallbackLiveTitle,
}) {
  return person['liveTitle']?.toString().trim().isNotEmpty == true
      ? person['liveTitle'].toString().trim()
      : fallbackLiveTitle;
}

class DinamicFollowedPeopleHList extends StatelessWidget {
  const DinamicFollowedPeopleHList({
    super.key,
    required this.people,
    this.title = 'Abonnements',
    this.emptyTitle = 'Aucun abonnement pour le moment',
    this.emptyMessage = 'Les profils suivis apparaitront ici.',
    this.showTitle = true,
    this.onPersonTap,
    this.onLiveTap,
  });

  final List<Map<String, dynamic>> people;
  final String title;
  final String emptyTitle;
  final String emptyMessage;
  final bool showTitle;
  final DynamicFollowedPersonTapCallback? onPersonTap;
  final DynamicFollowedPersonLiveTapCallback? onLiveTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
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
    final viewLiveLabel = context.tr(
      BanayLocalizationKeys.homeFollowedViewLive,
    );
    final viewProfileLabel = context.tr(
      BanayLocalizationKeys.homeFollowedViewProfile,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
        SizedBox(
          height: 214,
          child: people.isEmpty
              ? _FollowedPeopleEmptyState(
                  emptyTitle: emptyTitle,
                  emptyMessage: emptyMessage,
                  borderColor: appColors.borderColor,
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  physics: const ClampingScrollPhysics(),
                  itemCount: people.length,
                  itemBuilder: (context, index) {
                    final person = people[index];
                    final name = resolveFollowedPersonName(
                      person,
                      fallbackName: fallbackName,
                    );
                    final subtitle = resolveFollowedPersonSubtitle(
                      person,
                      fallbackSubtitle: fallbackSubtitle,
                    );
                    final trailingText = resolveFollowedPersonTrailingText(
                      person,
                      sellerBadge: sellerBadge,
                      profileBadge: profileBadge,
                    );
                    final avatarUrl = resolveFollowedPersonAvatarUrl(person);
                    final userId = resolveFollowedPersonUserId(person);
                    final isLive = isFollowedPersonLive(person);
                    final liveTitle = resolveFollowedPersonLiveTitle(
                      person,
                      fallbackLiveTitle: fallbackLiveTitle,
                    );

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onPersonTap == null
                            ? null
                            : () => onPersonTap!(person),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          width: 172,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: appColors.borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  AppCircleNetworkAvatar(
                                    imageUrl: avatarUrl,
                                    radius: 24,
                                    userId: userId,
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      trailingText,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isLive ? liveTitle : subtitle,
                                maxLines: isLive ? 2 : 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.3,
                                  color: isLive
                                      ? const Color(0xFFE53935)
                                      : appColors.mutedText,
                                  fontWeight: isLive
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              if (isLive && onLiveTap != null)
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => onLiveTap!(person),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE53935),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.live_tv_rounded,
                                      size: 16,
                                    ),
                                    label: Text(
                                      viewLiveLabel,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Row(
                                  children: [
                                    Icon(
                                      Icons.arrow_outward_rounded,
                                      size: 18,
                                      color: appColors.mutedText,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      viewProfileLabel,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: appColors.mutedText,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (showTitle) const SizedBox(height: 28),
      ],
    );
  }
}

class FollowedPeopleHListSkeleton extends StatelessWidget {
  const FollowedPeopleHListSkeleton({super.key, this.showTitle = true});

  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SkeletonBox(width: 150, height: 18),
          ),
        ],
        SizedBox(
          height: 214,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: 4,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return Container(
                width: 172,
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Theme.of(context).cardColor,
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SkeletonBox(
                          width: 48,
                          height: 48,
                          shape: BoxShape.circle,
                        ),
                        Spacer(),
                        SkeletonBox(width: 54, height: 24),
                      ],
                    ),
                    SizedBox(height: 14),
                    SkeletonBox(width: 120, height: 16),
                    SizedBox(height: 8),
                    SkeletonBox(width: 136, height: 12),
                    SizedBox(height: 6),
                    SkeletonBox(width: 98, height: 12),
                    Spacer(),
                    SkeletonBox(width: 92, height: 12),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FollowedPeopleEmptyState extends StatelessWidget {
  const _FollowedPeopleEmptyState({
    required this.emptyTitle,
    required this.emptyMessage,
    required this.borderColor,
  });

  final String emptyTitle;
  final String emptyMessage;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline_rounded,
                color: theme.colorScheme.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              emptyTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              emptyMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: appColors.mutedText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
