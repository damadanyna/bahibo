import 'dart:async';

import 'package:banay/component/app_network_image.dart';
import 'package:banay/component/app_page_skeletons.dart';
import 'package:banay/component/ui/dinamic_followed_people_h_list.dart'
    show
        DynamicFollowedPersonLiveTapCallback,
        DynamicFollowedPersonTapCallback,
        FollowedPeopleEmptyState,
        isFollowedPersonLive,
        resolveFollowedPersonAvatarUrl,
        resolveFollowedPersonName,
        resolveFollowedPersonUserId;
import 'package:banay/localization/banay_localizations.dart';
import 'package:banay/services/stories_api_service.dart';
import 'package:banay/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';

typedef FollowingStoryTapCallback = FutureOr<void> Function(int groupIndex);

// 76 px avatar (the first 60 px version read as too small next to the
// product cards below).
const double _avatarRadius = 38;
const double _ringWidth = 3;
const double _ringGap = 3;
const double _circleDiameter = (_avatarRadius + _ringGap + _ringWidth) * 2;
const double _itemWidth = 96;
const double _itemSpacing = 8;
const double _rowHeight = 124;

/// TikTok-style "Following" bar: one circle per followed shop, the caller's
/// own circle first (with the "+" to post a story). A coloured ring means
/// the shop has a story not seen yet, a grey ring a story already watched,
/// and the red "LIVE" pill a broadcast in progress.
class FollowingStoriesRow extends StatelessWidget {
  const FollowingStoriesRow({
    super.key,
    required this.people,
    required this.storyGroups,
    this.canCreateStory = true,
    this.currentUserAvatarUrl = '',
    this.onCreateStoryTap,
    this.onStoryTap,
    this.onPersonTap,
    this.onLiveTap,
    this.emptyTitle = '',
    this.emptyMessage = '',
  });

  /// Followed shops, same maps as the profile "following" endpoint.
  final List<Map<String, dynamic>> people;

  /// Active stories, merged into [people] by the author's user id.
  final List<StoryGroup> storyGroups;

  /// Shows the caller's own circle with the "+" badge (every account can
  /// post; kept as a switch for callers that only want to browse).
  final bool canCreateStory;
  final String currentUserAvatarUrl;

  final VoidCallback? onCreateStoryTap;
  final FollowingStoryTapCallback? onStoryTap;
  final DynamicFollowedPersonTapCallback? onPersonTap;
  final DynamicFollowedPersonLiveTapCallback? onLiveTap;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final entries = _buildEntries(context);

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: FollowedPeopleEmptyState(
          emptyTitle: emptyTitle,
          emptyMessage: emptyMessage,
          borderColor: Theme.of(context).appColors.borderColor,
        ),
      );
    }

    return SizedBox(
      height: _rowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        physics: const ClampingScrollPhysics(),
        itemCount: entries.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: _itemSpacing),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return _FollowingCircle(
            entry: entry,
            onTap: () => _handleTap(entry),
            onCreateTap: entry.isOwn ? onCreateStoryTap : null,
            onLiveTap: entry.isLive && entry.person != null && onLiveTap != null
                ? () => onLiveTap!(entry.person!)
                : null,
          );
        },
      ),
    );
  }

  void _handleTap(_FollowingEntry entry) {
    if (entry.isOwn) {
      final groupIndex = entry.groupIndex;
      if (groupIndex != null && onStoryTap != null) {
        onStoryTap!(groupIndex);
      } else {
        onCreateStoryTap?.call();
      }
      return;
    }

    final person = entry.person;
    // A live beats a story: it is happening right now.
    if (entry.isLive && person != null && onLiveTap != null) {
      onLiveTap!(person);
      return;
    }
    final groupIndex = entry.groupIndex;
    if (groupIndex != null && onStoryTap != null) {
      onStoryTap!(groupIndex);
      return;
    }
    if (person != null) {
      onPersonTap?.call(person);
    }
  }

  /// Own circle first, then live shops, unseen stories, seen stories, and
  /// finally shops with nothing going on; the server's order is kept
  /// inside each bucket.
  List<_FollowingEntry> _buildEntries(BuildContext context) {
    final groupIndexByUser = <String, int>{};
    int? ownGroupIndex;
    for (var index = 0; index < storyGroups.length; index++) {
      final group = storyGroups[index];
      if (group.isOwner) {
        ownGroupIndex = index;
        continue;
      }
      if (group.authorUserId.isNotEmpty) {
        groupIndexByUser[group.authorUserId] = index;
      }
    }

    final fallbackName = context.tr(
      BanayLocalizationKeys.homeFollowedMemberFallback,
    );
    final live = <_FollowingEntry>[];
    final unviewed = <_FollowingEntry>[];
    final viewed = <_FollowingEntry>[];
    final rest = <_FollowingEntry>[];
    final seenKeys = <String>{};

    void addEntry(_FollowingEntry entry) {
      if (entry.isLive) {
        live.add(entry);
      } else if (entry.hasUnviewedStory) {
        unviewed.add(entry);
      } else if (entry.groupIndex != null) {
        viewed.add(entry);
      } else {
        rest.add(entry);
      }
    }

    for (final person in people) {
      final userId = resolveFollowedPersonUserId(person) ?? '';
      if (userId.isEmpty || !seenKeys.add(userId)) {
        continue;
      }

      final groupIndex = groupIndexByUser[userId];
      final group = groupIndex == null ? null : storyGroups[groupIndex];
      addEntry(
        _FollowingEntry(
          key: userId,
          name: resolveFollowedPersonName(person, fallbackName: fallbackName),
          avatarUrl: resolveFollowedPersonAvatarUrl(person),
          userId: userId.isEmpty ? null : userId,
          person: person,
          groupIndex: groupIndex,
          hasUnviewedStory: group?.hasUnviewed ?? false,
          isLive: isFollowedPersonLive(person),
        ),
      );
    }

    // Stories from contacts that are not followed shops (a customer you
    // chat with, a shop that follows you, or a fresh follow the two feeds
    // do not agree on yet): they get a circle of their own.
    groupIndexByUser.forEach((authorUserId, groupIndex) {
      if (!seenKeys.add(authorUserId)) {
        return;
      }
      final group = storyGroups[groupIndex];
      final sellerProfileId = group.authorSellerProfileId ?? '';
      addEntry(
        _FollowingEntry(
          key: authorUserId,
          name: group.authorName.trim().isEmpty
              ? fallbackName
              : group.authorName,
          avatarUrl: group.authorAvatarUrl,
          userId: authorUserId,
          person: <String, dynamic>{
            'sellerProfileId': sellerProfileId,
            'userId': authorUserId,
            'id': authorUserId,
            'displayName': group.authorName,
            'avatarUrl': group.authorAvatarUrl,
            'role': sellerProfileId.isEmpty ? 'CUSTOMER' : 'SELLER',
          },
          groupIndex: groupIndex,
          hasUnviewedStory: group.hasUnviewed,
          isLive: false,
        ),
      );
    });

    return [
      if (canCreateStory)
        _FollowingEntry(
          key: 'own',
          name: context.tr(BanayLocalizationKeys.homeStoriesYourStory),
          avatarUrl: currentUserAvatarUrl,
          userId: null,
          person: null,
          groupIndex: ownGroupIndex,
          hasUnviewedStory: false,
          isLive: false,
          isOwn: true,
        ),
      ...live,
      ...unviewed,
      ...viewed,
      ...rest,
    ];
  }
}

class FollowingStoriesRowSkeleton extends StatelessWidget {
  const FollowingStoriesRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _rowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        separatorBuilder: (context, index) =>
            const SizedBox(width: _itemSpacing),
        itemBuilder: (context, index) {
          return const SizedBox(
            width: _itemWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SkeletonBox(
                  width: _circleDiameter,
                  height: _circleDiameter,
                  shape: BoxShape.circle,
                ),
                SizedBox(height: 8),
                SkeletonBox(width: 56, height: 11),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FollowingEntry {
  const _FollowingEntry({
    required this.key,
    required this.name,
    required this.avatarUrl,
    required this.userId,
    required this.person,
    required this.groupIndex,
    required this.hasUnviewedStory,
    required this.isLive,
    this.isOwn = false,
  });

  final String key;
  final String name;
  final String avatarUrl;
  final String? userId;
  final Map<String, dynamic>? person;

  /// Index into [FollowingStoriesRow.storyGroups]; null when no story.
  final int? groupIndex;
  final bool hasUnviewedStory;
  final bool isLive;
  final bool isOwn;

  bool get hasStory => groupIndex != null;
}

class _FollowingCircle extends StatelessWidget {
  const _FollowingCircle({
    required this.entry,
    required this.onTap,
    required this.onCreateTap,
    required this.onLiveTap,
  });

  final _FollowingEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onCreateTap;
  final VoidCallback? onLiveTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final colorScheme = theme.colorScheme;
    final background = theme.scaffoldBackgroundColor;

    // Ring: live red, unseen story = brand gradient, seen story = grey,
    // nothing = invisible (same size, so avatars stay aligned).
    final Gradient? ringGradient;
    final Color? ringColor;
    if (entry.isLive) {
      ringGradient = null;
      ringColor = appColors.liveIndicator;
    } else if (entry.hasUnviewedStory) {
      ringGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colorScheme.primary, colorScheme.secondary],
      );
      ringColor = null;
    } else if (entry.hasStory) {
      ringGradient = null;
      ringColor = appColors.mutedText.withValues(alpha: 0.45);
    } else {
      ringGradient = null;
      ringColor = Colors.transparent;
    }

    final avatar = Container(
      width: _circleDiameter,
      height: _circleDiameter,
      padding: const EdgeInsets.all(_ringWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: ringGradient,
        color: ringColor,
      ),
      child: Container(
        padding: const EdgeInsets.all(_ringGap),
        decoration: BoxDecoration(shape: BoxShape.circle, color: background),
        child: AppCircleNetworkAvatar(
          imageUrl: normalizeAvatarUrl(entry.avatarUrl),
          radius: _avatarRadius,
          userId: entry.userId,
          // The "+" and LIVE badges live in the same corner area.
          showPresenceBadge: false,
        ),
      ),
    );

    return SizedBox(
      width: _itemWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(onTap: onTap, child: avatar),
              ),
              if (entry.isOwn)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: onCreateTap ?? onTap,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: background, width: 2.5),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              if (entry.isLive)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: -5,
                  child: Center(
                    child: GestureDetector(
                      onTap: onLiveTap ?? onTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: appColors.liveIndicator,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: background, width: 2),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.2,
              fontWeight: entry.hasUnviewedStory || entry.isLive
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: entry.hasUnviewedStory || entry.isLive || entry.isOwn
                  ? colorScheme.onSurface
                  : appColors.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}
