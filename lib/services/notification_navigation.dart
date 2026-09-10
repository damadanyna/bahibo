import 'package:banay/page/live/live_watch_page.dart';
import 'package:banay/page/story/story_viewer_page.dart';
import 'package:banay/services/stories_api_service.dart';
import 'package:flutter/material.dart';

/// Destinations of the "live_started" / "story_published" notifications,
/// shared by the push tap (app closed or in background) and the in-app list
/// so both land on the same screen.

Future<void> openLiveFromNotification(
  NavigatorState navigator, {
  required String sellerProfileId,
  required String sellerName,
  required String sellerAvatarUrl,
}) async {
  final targetId = sellerProfileId.trim();
  if (targetId.isEmpty) {
    return;
  }

  final name = sellerName.trim();
  await navigator.push(
    MaterialPageRoute(
      builder: (_) => LiveWatchPage(
        sellerProfileId: targetId,
        sellerName: name.isNotEmpty ? name : 'Boutique BANAY',
        sellerAvatarUrl: sellerAvatarUrl.trim(),
      ),
    ),
  );
}

/// Opens the story player on the shop's group. The feed is refetched so a
/// story that expired since the notification simply reads as gone: returns
/// `false` in that case so the caller can say so.
Future<bool> openStoryFromNotification(
  NavigatorState navigator, {
  required String sellerProfileId,
}) async {
  final targetId = sellerProfileId.trim();
  if (targetId.isEmpty) {
    return false;
  }

  List<StoryGroup> groups;
  try {
    groups = await StoriesApiService().fetchStoryFeed();
  } catch (_) {
    return false;
  }

  final groupIndex = groups.indexWhere(
    (group) => group.authorSellerProfileId == targetId,
  );
  if (groupIndex < 0 || !navigator.mounted) {
    return false;
  }

  await navigator.push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          StoryViewerPage(groups: groups, initialGroupIndex: groupIndex),
    ),
  );
  return true;
}
