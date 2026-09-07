import 'dart:async';
import 'dart:math' as math;

import 'package:banay/component/app_network_image.dart';
import 'package:banay/localization/banay_localizations.dart';
import 'package:banay/services/app_api_client.dart';
import 'package:banay/services/app_logger.dart';
import 'package:banay/services/chat_media_cache_service.dart';
import 'package:banay/services/stories_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// Full-screen story player.
///
/// One horizontal page per author; a photo stays for [_storyDuration] (plus
/// caption reading time), a video plays to its end, then the next story
/// starts. Once an author's last story ends the player slides to the next
/// author until the last group is done, then closes. Tap right / left to
/// skip / go back, hold to pause, swipe down to close.
class StoryViewerPage extends StatefulWidget {
  const StoryViewerPage({
    super.key,
    required this.groups,
    this.initialGroupIndex = 0,
    this.onStoryViewed,
    this.onStoryDeleted,
  });

  final List<StoryGroup> groups;
  final int initialGroupIndex;

  /// Lets the caller grey out the ring without refetching the feed.
  final void Function(String storyId)? onStoryViewed;
  final void Function(String storyId)? onStoryDeleted;

  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// Base time on screen for a photo; a caption adds reading time on top
  /// (see [_durationFor]). 5 s felt too short in use.
  static const Duration _storyDuration = Duration(seconds: 8);
  static const Duration _storyMaxDuration = Duration(seconds: 12);

  /// Roughly one extra second per 30 caption characters.
  static const int _captionCharsPerSecond = 30;
  static const Duration _imageLoadTimeout = Duration(seconds: 8);
  static const Duration _videoLoadTimeout = Duration(seconds: 20);
  static const Duration _pageTransition = Duration(milliseconds: 280);
  static const String _tag = 'StoryViewerPage';

  final StoriesApiService _storiesApiService = StoriesApiService();

  late final PageController _pageController;
  late final AnimationController _progress;
  late List<StoryGroup> _groups;

  /// Story index per group so swiping back resumes where the viewer was.
  final Map<int, int> _storyIndexByGroup = <int, int>{};

  int _groupIndex = 0;

  /// Bumped on every story change so a slow media preload of a story that
  /// is no longer on screen cannot restart the timer.
  int _loadToken = 0;
  bool _isLoadingMedia = false;
  bool _isPausedByUser = false;
  bool _isPausedByLifecycle = false;

  /// Delete / viewers flow in progress: keeps playback stopped.
  bool _isBusy = false;
  bool _isClosing = false;

  /// Player of the story on screen when it is a video; null for photos.
  VideoPlayerController? _videoController;
  String? _videoStoryId;
  bool _videoLoadFailed = false;
  bool _videoAdvanced = false;

  int get _storyIndex => _storyIndexByGroup[_groupIndex] ?? 0;

  StoryGroup? get _currentGroup =>
      _groupIndex >= 0 && _groupIndex < _groups.length
      ? _groups[_groupIndex]
      : null;

  StoryItem? get _currentStory {
    final group = _currentGroup;
    if (group == null || group.stories.isEmpty) {
      return null;
    }
    return group.stories[_storyIndex.clamp(0, group.stories.length - 1)];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Own mutable copy: deletions and "seen" flags are applied locally.
    _groups = widget.groups
        .where((group) => group.stories.isNotEmpty)
        .map((group) => group.copyWith(stories: List.of(group.stories)))
        .toList();
    _groupIndex = _groups.isEmpty
        ? 0
        : widget.initialGroupIndex.clamp(0, _groups.length - 1);
    if (_groups.isNotEmpty) {
      _storyIndexByGroup[_groupIndex] = _groups[_groupIndex].firstUnviewedIndex;
    }

    _pageController = PageController(initialPage: _groupIndex);
    _progress = AnimationController(vsync: this, duration: _storyDuration)
      ..addStatusListener(_onProgressStatus);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_groups.isEmpty) {
        _close();
        return;
      }
      unawaited(_playCurrentStory());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progress.dispose();
    _pageController.dispose();
    final controller = _videoController;
    _videoController = null;
    if (controller != null) {
      controller.removeListener(_onVideoTick);
      unawaited(_disposeQuietly(controller));
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isPausedByLifecycle = false;
      _resumeIfAllowed();
      return;
    }
    _isPausedByLifecycle = true;
    _pausePlayback();
  }

  /// Photos only: videos advance from [_onVideoTick] (their bar never
  /// reaches 1.0 through this controller).
  void _onProgressStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _goToNextStory();
    }
  }

  Future<void> _playCurrentStory() async {
    final story = _currentStory;
    if (story == null) {
      return;
    }

    final token = ++_loadToken;
    _progress.stop();
    _progress.reset();
    _isLoadingMedia = true;
    await _disposeVideoController();
    if (!mounted || token != _loadToken) {
      return;
    }
    setState(() {});
    _markViewed(story);

    if (story.isVideo) {
      await _prepareVideo(story, token);
      return;
    }

    _progress.duration = _durationFor(story);
    // Bounded wait so the timer does not tick on a blank screen; on a slow
    // link it simply starts once the photo is there (or after the cap).
    await _warmImage(
      story.posterUrl,
    ).timeout(_imageLoadTimeout, onTimeout: () {});
    if (!mounted || token != _loadToken) {
      return;
    }

    _isLoadingMedia = false;
    final nextStory = _peekNextStory();
    if (nextStory != null) {
      unawaited(_warmImage(nextStory.posterUrl));
    }
    _resumeIfAllowed();
  }

  Future<void> _prepareVideo(StoryItem story, int token) async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(story.mediaUrl),
    );
    _videoController = controller;
    _videoStoryId = story.id;
    _videoLoadFailed = false;
    _videoAdvanced = false;

    var initialized = false;
    try {
      await controller.initialize().timeout(_videoLoadTimeout);
      initialized = true;
    } catch (error) {
      initialized = false;
      // MissingPluginException here means the app was hot-reloaded after
      // adding video_player: a full rebuild is needed.
      AppLogger.warning(
        _tag,
        'Story video failed to initialize: ${story.mediaUrl}',
        error,
      );
    }
    if (!mounted || token != _loadToken) {
      // Superseded while loading: the new story already disposed us, or
      // will never use this controller.
      if (identical(_videoController, controller)) {
        await _disposeVideoController();
      }
      return;
    }

    if (!initialized || controller.value.duration <= Duration.zero) {
      // Show the poster for the usual photo time so the flow continues.
      await _disposeVideoController();
      _videoLoadFailed = true;
      _progress.duration = _storyDuration;
      _isLoadingMedia = false;
      setState(() {});
      _resumeIfAllowed();
      return;
    }

    _progress.duration = controller.value.duration;
    controller.addListener(_onVideoTick);
    _isLoadingMedia = false;
    setState(() {});
    _resumeIfAllowed();
  }

  void _onVideoTick() {
    final controller = _videoController;
    if (controller == null || !mounted) {
      return;
    }
    final value = controller.value;
    final duration = value.duration;
    if (duration <= Duration.zero) {
      return;
    }

    // Drive the segment bar from the real position; capped just under 1 so
    // the AnimationController never reports "completed" on its own.
    final fraction = value.position.inMilliseconds / duration.inMilliseconds;
    _progress.value = fraction.clamp(0.0, 0.999);

    final reachedEnd =
        value.isCompleted ||
        (!value.isPlaying &&
            !value.isBuffering &&
            value.position >= duration - const Duration(milliseconds: 250));
    if (reachedEnd && !_videoAdvanced && !_isPausedByUser && !_isBusy) {
      _videoAdvanced = true;
      _goToNextStory();
    }
  }

  Future<void> _disposeVideoController() async {
    final controller = _videoController;
    _videoController = null;
    _videoStoryId = null;
    _videoLoadFailed = false;
    _videoAdvanced = false;
    if (controller == null) {
      return;
    }
    controller.removeListener(_onVideoTick);
    await _disposeQuietly(controller);
  }

  /// A player whose native side never came up (plugin missing, decoder
  /// error) can throw again on dispose; that must not stall the flow.
  static Future<void> _disposeQuietly(VideoPlayerController controller) async {
    try {
      await controller.dispose();
    } catch (error) {
      AppLogger.warning(_tag, 'Video controller dispose failed', error);
    }
  }

  Duration _durationFor(StoryItem story) {
    final captionLength = story.caption?.trim().length ?? 0;
    if (captionLength == 0) {
      return _storyDuration;
    }
    final readingTime = Duration(
      seconds: (captionLength / _captionCharsPerSecond).ceil(),
    );
    final total = _storyDuration + readingTime;
    return total > _storyMaxDuration ? _storyMaxDuration : total;
  }

  Future<void> _warmImage(String imageUrl) async {
    try {
      await ChatMediaCacheService.instance.getOrDownloadFile(imageUrl);
    } catch (_) {
      // The image widget shows its own error state.
    }
  }

  StoryItem? _peekNextStory() {
    final group = _currentGroup;
    if (group == null) {
      return null;
    }
    if (_storyIndex + 1 < group.stories.length) {
      return group.stories[_storyIndex + 1];
    }
    if (_groupIndex + 1 < _groups.length) {
      final nextGroup = _groups[_groupIndex + 1];
      return nextGroup.stories.isEmpty
          ? null
          : nextGroup.stories[nextGroup.firstUnviewedIndex];
    }
    return null;
  }

  void _pausePlayback() {
    _progress.stop();
    final controller = _videoController;
    if (controller != null && controller.value.isPlaying) {
      controller.pause();
    }
  }

  void _resumeIfAllowed() {
    if (!mounted ||
        _isClosing ||
        _isBusy ||
        _isLoadingMedia ||
        _isPausedByUser ||
        _isPausedByLifecycle) {
      return;
    }

    final controller = _videoController;
    if (controller != null && controller.value.isInitialized) {
      if (!controller.value.isPlaying && !controller.value.isCompleted) {
        controller.play();
      }
      return;
    }
    if (_progress.status != AnimationStatus.completed) {
      _progress.forward();
    }
  }

  void _markViewed(StoryItem story) {
    if (story.isOwner || story.isViewed) {
      return;
    }
    _replaceStory(story.copyWith(isViewed: true));
    widget.onStoryViewed?.call(story.id);
    unawaited(_sendViewed(story.id));
  }

  Future<void> _sendViewed(String storyId) async {
    try {
      await _storiesApiService.markStoryViewed(storyId);
    } catch (_) {
      // Best effort: the ring greys out locally either way.
    }
  }

  void _replaceStory(StoryItem updated) {
    final groupIndex = _groups.indexWhere(
      (group) => group.authorUserId == updated.authorUserId,
    );
    if (groupIndex < 0) {
      return;
    }
    final stories = _groups[groupIndex].stories
        .map((story) => story.id == updated.id ? updated : story)
        .toList();
    _groups[groupIndex] = _groups[groupIndex].copyWith(stories: stories);
    if (mounted) {
      setState(() {});
    }
  }

  // ---------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------

  void _goToNextStory() {
    final group = _currentGroup;
    if (group == null) {
      return;
    }
    if (_storyIndex + 1 < group.stories.length) {
      _storyIndexByGroup[_groupIndex] = _storyIndex + 1;
      unawaited(_playCurrentStory());
      return;
    }
    _goToGroup(_groupIndex + 1);
  }

  void _goToPreviousStory() {
    if (_storyIndex > 0) {
      _storyIndexByGroup[_groupIndex] = _storyIndex - 1;
      unawaited(_playCurrentStory());
      return;
    }
    if (_groupIndex > 0) {
      _storyIndexByGroup[_groupIndex - 1] = 0;
      _goToGroup(_groupIndex - 1);
      return;
    }
    // First story of the first author: replay it.
    unawaited(_playCurrentStory());
  }

  void _goToGroup(int index) {
    if (index < 0 || index >= _groups.length) {
      _close();
      return;
    }
    _pausePlayback();
    if (!_pageController.hasClients) {
      _onPageChanged(index);
      return;
    }
    _pageController.animateToPage(
      index,
      duration: _pageTransition,
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int index) {
    if (index == _groupIndex || index < 0 || index >= _groups.length) {
      return;
    }
    _groupIndex = index;
    _storyIndexByGroup.putIfAbsent(
      index,
      () => _groups[index].firstUnviewedIndex,
    );
    unawaited(_playCurrentStory());
  }

  void _close() {
    if (_isClosing) {
      return;
    }
    _isClosing = true;
    _pausePlayback();
    if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  // ---------------------------------------------------------------------
  // Gestures
  // ---------------------------------------------------------------------

  void _handleTapUp(TapUpDetails details, double width) {
    if (_isBusy || _isClosing) {
      return;
    }
    if (details.localPosition.dx < width * 0.3) {
      _goToPreviousStory();
    } else {
      _goToNextStory();
    }
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    _isPausedByUser = true;
    _pausePlayback();
    setState(() {});
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    _isPausedByUser = false;
    setState(() {});
    _resumeIfAllowed();
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if ((details.primaryVelocity ?? 0) > 400) {
      _close();
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    // Manual swipe between authors: freeze playback while the finger is
    // down, resume once the page settles (a completed swipe restarts
    // through _onPageChanged anyway).
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _pausePlayback();
    } else if (notification is ScrollEndNotification) {
      _resumeIfAllowed();
    }
    return false;
  }

  // ---------------------------------------------------------------------
  // Owner actions
  // ---------------------------------------------------------------------

  Future<void> _confirmDeleteCurrentStory() async {
    final story = _currentStory;
    if (story == null || !story.isOwner || _isBusy) {
      return;
    }

    _isBusy = true;
    _pausePlayback();

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              dialogContext.tr(
                BanayLocalizationKeys.homeStoryDeleteConfirmTitle,
              ),
            ),
            content: Text(
              dialogContext.tr(
                BanayLocalizationKeys.homeStoryDeleteConfirmBody,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(
                  dialogContext.tr(BanayLocalizationKeys.accountCancelAction),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(dialogContext).colorScheme.error,
                ),
                child: Text(
                  dialogContext.tr(BanayLocalizationKeys.homeStoryDeleteAction),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!mounted) {
      return;
    }
    if (!confirmed) {
      _isBusy = false;
      _resumeIfAllowed();
      return;
    }

    try {
      await _storiesApiService.deleteStory(story.id);
      if (!mounted) {
        return;
      }
      widget.onStoryDeleted?.call(story.id);
      _showSnackBar(context.tr(BanayLocalizationKeys.homeStoryDeleted));
      _isBusy = false;
      _removeStoryLocally(story);
    } on AppApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(error.message);
      _isBusy = false;
      _resumeIfAllowed();
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar(context.tr(BanayLocalizationKeys.homeStoryDeleteFailed));
      _isBusy = false;
      _resumeIfAllowed();
    }
  }

  void _removeStoryLocally(StoryItem story) {
    final groupIndex = _groups.indexWhere(
      (group) => group.authorUserId == story.authorUserId,
    );
    if (groupIndex < 0) {
      return;
    }

    final remaining = _groups[groupIndex].stories
        .where((item) => item.id != story.id)
        .toList();

    if (remaining.isNotEmpty) {
      _groups[groupIndex] = _groups[groupIndex].copyWith(stories: remaining);
      if (groupIndex == _groupIndex) {
        _storyIndexByGroup[groupIndex] = _storyIndex.clamp(
          0,
          remaining.length - 1,
        );
        unawaited(_playCurrentStory());
      } else {
        setState(() {});
      }
      return;
    }

    // The author has nothing left: drop the page and re-index the others.
    _groups.removeAt(groupIndex);
    if (_groups.isEmpty) {
      _close();
      return;
    }
    final shifted = <int, int>{};
    _storyIndexByGroup.forEach((index, storyIndex) {
      if (index < groupIndex) {
        shifted[index] = storyIndex;
      } else if (index > groupIndex) {
        shifted[index - 1] = storyIndex;
      }
    });
    _storyIndexByGroup
      ..clear()
      ..addAll(shifted);
    _groupIndex = math.min(_groupIndex, _groups.length - 1);
    _storyIndexByGroup[_groupIndex] = 0;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_groupIndex);
      }
      unawaited(_playCurrentStory());
    });
  }

  Future<void> _showViewers() async {
    final story = _currentStory;
    if (story == null || !story.isOwner || _isBusy) {
      return;
    }

    _isBusy = true;
    _pausePlayback();

    List<Map<String, dynamic>>? viewers;
    try {
      viewers = await _storiesApiService.fetchStoryViewers(story.id);
    } catch (_) {
      viewers = null;
    }
    if (!mounted) {
      return;
    }
    if (viewers != null) {
      _replaceStory(story.copyWith(viewCount: viewers.length));
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _StoryViewersSheet(
        viewers: viewers ?? const [],
        timeLabelBuilder: (date) => _formatTimeAgo(sheetContext, date),
      ),
    );

    if (!mounted) {
      return;
    }
    _isBusy = false;
    _resumeIfAllowed();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatTimeAgo(BuildContext context, DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) {
      return context.tr(BanayLocalizationKeys.homeStoryJustNow);
    }
    if (difference.inMinutes < 60) {
      return context.tr(
        BanayLocalizationKeys.homeStoryMinutesAgo,
        params: {'count': '${difference.inMinutes}'},
      );
    }
    return context.tr(
      BanayLocalizationKeys.homeStoryHoursAgo,
      params: {'count': '${difference.inHours}'},
    );
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _groups.isEmpty
            ? const SizedBox.shrink()
            : NotificationListener<ScrollNotification>(
                onNotification: _handleScrollNotification,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _groups.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: _buildGroupPage,
                ),
              ),
      ),
    );
  }

  Widget _buildGroupPage(BuildContext context, int index) {
    final group = _groups[index];
    final isCurrent = index == _groupIndex;
    final storyIndex = (_storyIndexByGroup[index] ?? group.firstUnviewedIndex)
        .clamp(0, group.stories.length - 1);
    final story = group.stories[storyIndex];
    final showChrome = !_isPausedByUser;
    final size = MediaQuery.sizeOf(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildMedia(story, isCurrent, size),
        const _StoryScrim(),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: (details) => _handleTapUp(details, size.width),
            onLongPressStart: _handleLongPressStart,
            onLongPressEnd: _handleLongPressEnd,
            onVerticalDragEnd: _handleVerticalDragEnd,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: AnimatedOpacity(
            opacity: showChrome ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildProgressRow(group, storyIndex, isCurrent),
                  _buildHeader(context, group, story),
                ],
              ),
            ),
          ),
        ),
        if (story.caption != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedOpacity(
              opacity: showChrome ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Text(
                    story.caption!,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Letterboxed on black: product photos are rarely 9:16 and a crop would
  /// hide what the author wanted to show. Videos show their poster until
  /// the player is ready.
  Widget _buildMedia(StoryItem story, bool isCurrent, Size size) {
    final controller = _videoController;
    final isPlayableVideo =
        story.isVideo &&
        isCurrent &&
        controller != null &&
        _videoStoryId == story.id &&
        controller.value.isInitialized;

    if (isPlayableVideo) {
      return Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio <= 0
              ? 9 / 16
              : controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
      );
    }

    final poster = AppNetworkImage(
      key: ValueKey('story-${story.id}'),
      imageUrl: story.posterUrl,
      width: size.width,
      height: size.height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorChild: const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.white38,
          size: 56,
        ),
      ),
    );

    if (!story.isVideo) {
      return poster;
    }

    final showsFailure = isCurrent && _videoLoadFailed;
    return Stack(
      fit: StackFit.expand,
      children: [
        poster,
        Center(
          child: showsFailure
              ? const Icon(
                  Icons.videocam_off_rounded,
                  color: Colors.white70,
                  size: 44,
                )
              : const SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: Colors.white,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildProgressRow(StoryGroup group, int storyIndex, bool isCurrent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
      child: Row(
        children: [
          for (var i = 0; i < group.stories.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _StoryProgressBar(
                  // Only the story on screen animates; the others are
                  // either done (1) or still to come (0).
                  animation: i == storyIndex && isCurrent ? _progress : null,
                  staticValue: i < storyIndex ? 1 : 0,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, StoryGroup group, StoryItem story) {
    final name = group.isOwner
        ? context.tr(BanayLocalizationKeys.homeStoriesYourStory)
        : group.authorName;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 0),
      child: Row(
        children: [
          AppCircleNetworkAvatar(
            imageUrl: normalizeAvatarUrl(group.authorAvatarUrl),
            radius: 18,
            showPresenceBadge: false,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _formatTimeAgo(context, story.createdAt),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (story.isOwner) ...[
            TextButton.icon(
              onPressed: _showViewers,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 40),
              ),
              icon: const Icon(Icons.visibility_rounded, size: 18),
              label: Text(
                '${story.viewCount ?? 0}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              onPressed: _confirmDeleteCurrentStory,
              tooltip: context.tr(BanayLocalizationKeys.homeStoryDeleteAction),
              icon: const Icon(Icons.delete_outline_rounded),
              color: Colors.white,
            ),
          ],
          IconButton(
            onPressed: _close,
            icon: const Icon(Icons.close_rounded),
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _StoryProgressBar extends StatelessWidget {
  const _StoryProgressBar({required this.animation, required this.staticValue});

  final Animation<double>? animation;
  final double staticValue;

  @override
  Widget build(BuildContext context) {
    final animation = this.animation;
    if (animation == null) {
      return _bar(staticValue);
    }
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => _bar(animation.value),
    );
  }

  Widget _bar(double value) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.white30),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: const ColoredBox(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// Darkens only the top and bottom bands where text sits; the media in the
/// middle stays untouched.
class _StoryScrim extends StatelessWidget {
  const _StoryScrim();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.18, 0.72, 1.0],
            colors: [
              Color(0x8A000000),
              Colors.transparent,
              Colors.transparent,
              Color(0x99000000),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryViewersSheet extends StatelessWidget {
  const _StoryViewersSheet({
    required this.viewers,
    required this.timeLabelBuilder,
  });

  final List<Map<String, dynamic>> viewers;
  final String Function(DateTime date) timeLabelBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.6;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 46,
              height: 5,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${context.tr(BanayLocalizationKeys.homeStoryViewersTitle)}'
            '${viewers.isEmpty ? '' : ' (${viewers.length})'}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (viewers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                context.tr(BanayLocalizationKeys.homeStoryNoViewersYet),
                style: theme.textTheme.bodyMedium,
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: viewers.length,
                separatorBuilder: (context, index) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final viewer = viewers[index];
                  final viewedAt = DateTime.tryParse(
                    viewer['viewedAt']?.toString() ?? '',
                  )?.toLocal();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: AppCircleNetworkAvatar(
                      imageUrl: normalizeAvatarUrl(
                        viewer['avatarUrl']?.toString(),
                      ),
                      radius: 20,
                      userId: viewer['userId']?.toString(),
                    ),
                    title: Text(
                      viewer['displayName']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    trailing: viewedAt == null
                        ? null
                        : Text(
                            timeLabelBuilder(viewedAt),
                            style: theme.textTheme.bodySmall,
                          ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
