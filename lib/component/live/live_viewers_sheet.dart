import 'package:banay/component/app_network_image.dart';
import 'package:banay/component/open_user_profile.dart';
import 'package:banay/services/live/live_viewers.dart';
import 'package:banay/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

/// Who is watching the live, for the host and the viewers alike. Read from
/// the room and refreshed on every join or leave while open; a row opens
/// the person's public profile.
Future<void> showLiveViewersSheet(BuildContext context, {required Room room}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => LiveViewersSheet(room: room),
  );
}

class LiveViewersSheet extends StatelessWidget {
  const LiveViewersSheet({super.key, required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      // The room notifies on every participant change: the list follows
      // joins and leaves without any polling.
      child: ListenableBuilder(
        listenable: room,
        builder: (context, _) {
          final viewers = liveViewersOf(room);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: appColors.inputBorder,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Spectateurs',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${viewers.length}',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (viewers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      "Personne ne regarde pour l'instant.",
                      style: TextStyle(
                        color: appColors.mutedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.paddingOf(context).bottom + 8,
                    ),
                    itemCount: viewers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 2),
                    itemBuilder: (context, index) =>
                        _LiveViewerRow(viewer: viewers[index]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LiveViewerRow extends StatelessWidget {
  const _LiveViewerRow({required this.viewer});

  final LiveViewer viewer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final primary = theme.colorScheme.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => pushUserProfileById(context, viewer.userId),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          children: [
            if (viewer.avatarUrl.isNotEmpty)
              AppCircleNetworkAvatar(
                imageUrl: viewer.avatarUrl,
                radius: 22,
                showPresenceBadge: false,
              )
            else
              CircleAvatar(
                radius: 22,
                backgroundColor: primary.withValues(alpha: 0.12),
                child: Icon(Icons.person_rounded, color: primary, size: 24),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                viewer.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (viewer.isMe) ...[
              const SizedBox(width: 8),
              Text(
                'Vous',
                style: TextStyle(
                  color: appColors.mutedText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: appColors.mutedText),
          ],
        ),
      ),
    );
  }
}
