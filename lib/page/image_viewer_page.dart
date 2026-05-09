import 'dart:async';

import 'package:flutter/material.dart';
import 'package:banay/component/app_back_button.dart';
import 'package:banay/component/app_comments_sheet.dart';
import 'package:banay/component/app_network_image.dart';
import 'package:banay/component/app_page_skeletons.dart';
import 'package:banay/component/app_page_refresh.dart';
import 'package:banay/component/app_share_sheet.dart';
import 'package:banay/component/chat_media_cached_image.dart';
import 'package:banay/services/chat_media_cache_service.dart';
import 'package:banay/services/cloudinary_image_url.dart';
import 'package:banay/theme/app_theme_extensions.dart';

class ImageViewerOverlayData {
  final String? title;
  final String? description;
  final String? sellerName;
  final String? sellerUserId;
  final String? sellerAvatarUrl;
  final String? sellerBadge;
  final String? sellerHandle;
  final String? musicLabel;
  final String? postedAtLabel;
  final String? likesCount;
  final String? commentsCount;
  final String? sharesCount;
  final bool isUserProfileImage;

  const ImageViewerOverlayData({
    this.title,
    this.description,
    this.sellerName,
    this.sellerUserId,
    this.sellerAvatarUrl,
    this.sellerBadge,
    this.sellerHandle,
    this.musicLabel,
    this.postedAtLabel,
    this.likesCount,
    this.commentsCount,
    this.sharesCount,
    this.isUserProfileImage = false,
  });

  bool get hasContent =>
      (title != null && title!.trim().isNotEmpty) ||
      (description != null && description!.trim().isNotEmpty) ||
      (sellerName != null && sellerName!.trim().isNotEmpty) ||
      (sellerUserId != null && sellerUserId!.trim().isNotEmpty) ||
      (sellerAvatarUrl != null && sellerAvatarUrl!.trim().isNotEmpty) ||
      (sellerBadge != null && sellerBadge!.trim().isNotEmpty) ||
      (sellerHandle != null && sellerHandle!.trim().isNotEmpty) ||
      (musicLabel != null && musicLabel!.trim().isNotEmpty) ||
      (postedAtLabel != null && postedAtLabel!.trim().isNotEmpty) ||
      (likesCount != null && likesCount!.trim().isNotEmpty) ||
      (commentsCount != null && commentsCount!.trim().isNotEmpty) ||
      (sharesCount != null && sharesCount!.trim().isNotEmpty);
}

class ImageViewerEntry {
  final List<String> imageUrls;
  final int initialIndex;
  final String? heroTag;
  final ImageViewerOverlayData? overlay;

  const ImageViewerEntry({
    required this.imageUrls,
    this.initialIndex = 0,
    this.heroTag,
    this.overlay,
  });
}

class ImageViewerPage extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final int initialEntryIndex;
  final String? heroTag;
  final ImageViewerOverlayData? overlay;
  final List<ImageViewerEntry>? entries;
  final VoidCallback? onSellerTap;
  final VoidCallback? onSellerMessageTap;
  final Future<void> Function(String imageUrl)? onDownloadImage;

  const ImageViewerPage({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.initialEntryIndex = 0,
    this.heroTag,
    this.overlay,
    this.entries,
    this.onSellerTap,
    this.onSellerMessageTap,
    this.onDownloadImage,
  });

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage>
    with AppPageRefreshMixin<ImageViewerPage> {
  late final PageController _entryPageController;
  late final List<ImageViewerEntry> _entries;
  final Map<int, int> _entryImageIndexes = <int, int>{};
  late int _currentEntryIndex;
  late int _currentIndex;
  int _commentCount = 64;
  bool _showEntrySkeleton = true;
  bool _showChrome = true;
  bool _isDescriptionExpanded = false;
  bool _isDownloadingImage = false;
  final List<AppCommentItem> _comments = defaultAppComments();

  @override
  void initState() {
    super.initState();
    initializePageRefresh();
    _entries = widget.entries != null && widget.entries!.isNotEmpty
        ? widget.entries!
        : <ImageViewerEntry>[
            ImageViewerEntry(
              imageUrls: widget.imageUrls,
              initialIndex: widget.initialIndex,
              heroTag: widget.heroTag,
              overlay: widget.overlay,
            ),
          ];
    _currentEntryIndex = widget.initialEntryIndex.clamp(0, _entries.length - 1);
    _currentIndex = _safeImageIndex(_currentEntryIndex);
    _entryImageIndexes[_currentEntryIndex] = _currentIndex;
    _commentCount =
        _parseCompactCount(
          _entries[_currentEntryIndex].overlay?.commentsCount,
        ) ??
        64;
    _entryPageController = PageController(initialPage: _currentEntryIndex);
    _prefetchViewerNeighborhood(_currentEntryIndex, _currentIndex);
    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() => _showEntrySkeleton = false);
    });
  }

  @override
  void didUpdateWidget(covariant ImageViewerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final updatedCount = _parseCompactCount(
      _entries[_currentEntryIndex].overlay?.commentsCount,
    );
    if (updatedCount != null && updatedCount != _commentCount) {
      _commentCount = updatedCount;
    }
  }

  @override
  void dispose() {
    disposePageRefresh();
    _entryPageController.dispose();
    super.dispose();
  }

  @override
  Future<void> onPageReload() async {
    if (mounted) {
      setState(() => _showEntrySkeleton = true);
    }
    await Future.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;
    setState(() => _showEntrySkeleton = false);
  }

  @override
  Widget build(BuildContext context) {
    final activeEntry = _entries[_currentEntryIndex];
    final images = activeEntry.imageUrls
        .map(CloudinaryImageUrl.forViewer)
        .toList(growable: false);
    final overlay = activeEntry.overlay;
    final bottomOverlayOffset = isOffline ? 74.0 : 28.0;
    final appColors = Theme.of(context).appColors;

    return Scaffold(
      backgroundColor: appColors.viewerBackground,
      body: Stack(
        children: [
          if (images.isEmpty)
            Center(
              child: Icon(
                Icons.broken_image,
                color: appColors.heroForegroundMuted,
                size: 80,
              ),
            )
          else if (_showEntrySkeleton)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: SkeletonBox(height: 320),
              ),
            )
          else
            PageView.builder(
              controller: _entryPageController,
              scrollDirection: Axis.vertical,
              itemCount: _entries.length,
              onPageChanged: _handleEntryPageChanged,
              itemBuilder: (context, entryIndex) {
                return _buildEntryPage(context, entryIndex);
              },
            ),
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _showChrome ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: IgnorePointer(
                ignoring: !_showChrome,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          appColors.scrimSoft,
                          Colors.transparent,
                          Colors.transparent,
                          appColors.scrimStrong,
                        ],
                        stops: const [0, 0.18, 0.52, 1],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedOpacity(
            opacity: _showChrome ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: IgnorePointer(
              ignoring: !_showChrome,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Row(
                    children: [
                      const AppBackButton(),
                      const Spacer(),
                      if (widget.onDownloadImage != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _isDownloadingImage
                                  ? null
                                  : _handleDownloadCurrentImage,
                              borderRadius: BorderRadius.circular(999),
                              child: Ink(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: appColors.overlaySurface,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: appColors.overlayBorder,
                                  ),
                                ),
                                child: Center(
                                  child: _isDownloadingImage
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: appColors.heroForeground,
                                          ),
                                        )
                                      : Icon(
                                          Icons.download_rounded,
                                          color: appColors.heroForeground,
                                          size: 20,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),

                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: appColors.overlaySurface,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: appColors.overlayBorder),
                        ),
                        child: Text(
                          _buildCounterLabel(),
                          style: TextStyle(
                            color: appColors.heroForeground,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (overlay != null && overlay.hasContent)
            Positioned(
              left: 16,
              right: 16,
              bottom: bottomOverlayOffset,
              child: AnimatedOpacity(
                opacity: _showChrome ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: IgnorePointer(
                  ignoring: !_showChrome,
                  child: _ImageViewerOverlay(
                    overlay: overlay,
                    onSellerTap: widget.onSellerTap,
                    onSellerMessageTap: widget.onSellerMessageTap,
                    onDescriptionTap: _toggleDescription,
                    onCommentTap: _showCommentsSheet,
                    onShareTap: _showShareSuggestions,
                    isDescriptionExpanded: _isDescriptionExpanded,
                    commentCountLabel: _commentCount.toString(),
                    indexLabel: _buildCounterLabel(),
                  ),
                ),
              ),
            ),
          if (isOffline) const AppOfflineBanner(bottomOffset: 18),
        ],
      ),
    );
  }

  void _toggleDescription() {
    setState(() => _isDescriptionExpanded = !_isDescriptionExpanded);
  }

  Future<void> _handleDownloadCurrentImage() async {
    final onDownloadImage = widget.onDownloadImage;
    if (onDownloadImage == null || _isDownloadingImage) {
      return;
    }

    final activeEntry = _entries[_currentEntryIndex];
    if (activeEntry.imageUrls.isEmpty) {
      return;
    }

    final imageIndex = _safeImageIndex(_currentEntryIndex);
    final imageUrl = activeEntry.imageUrls[imageIndex].trim();
    if (imageUrl.isEmpty) {
      return;
    }

    setState(() => _isDownloadingImage = true);
    try {
      await onDownloadImage(imageUrl);
    } finally {
      if (mounted) {
        setState(() => _isDownloadingImage = false);
      }
    }
  }

  int _safeImageIndex(int entryIndex) {
    final entry = _entries[entryIndex];
    if (entry.imageUrls.isEmpty) {
      return 0;
    }
    final candidateIndex = _entryImageIndexes[entryIndex] ?? entry.initialIndex;
    return candidateIndex.clamp(0, entry.imageUrls.length - 1);
  }

  void _handleEntryPageChanged(int entryIndex) {
    final nextEntry = _entries[entryIndex];
    final nextImageIndex = _safeImageIndex(entryIndex);
    final nextCommentCount = _parseCompactCount(
      nextEntry.overlay?.commentsCount,
    );

    setState(() {
      _currentEntryIndex = entryIndex;
      _currentIndex = nextImageIndex;
      _isDescriptionExpanded = false;
      _commentCount = nextCommentCount ?? 64;
    });

    _prefetchViewerNeighborhood(entryIndex, nextImageIndex);
  }

  void _prefetchViewerNeighborhood(int entryIndex, int imageIndex) {
    final entry = _entries[entryIndex];
    if (entry.imageUrls.isEmpty) {
      return;
    }

    final urls = <String>{};
    final indexes = <int>{imageIndex, imageIndex - 1, imageIndex + 1};
    for (final index in indexes) {
      if (index < 0 || index >= entry.imageUrls.length) {
        continue;
      }
      urls.add(CloudinaryImageUrl.forViewer(entry.imageUrls[index]));
    }

    for (final url in urls) {
      unawaited(ChatMediaCacheService.instance.prefetch(url));
    }
  }

  String _buildCounterLabel() {
    final activeEntry = _entries[_currentEntryIndex];
    final imageCount = activeEntry.imageUrls.length;
    if (imageCount == 0) {
      return _entries.length > 1
          ? 'Produit ${_currentEntryIndex + 1}/${_entries.length}'
          : 'Image';
    }

    if (_entries.length <= 1) {
      return '${_currentIndex + 1}/$imageCount';
    }

    return 'Produit ${_currentEntryIndex + 1}/${_entries.length}';
  }

  Widget _buildEntryPage(BuildContext context, int entryIndex) {
    final entry = _entries[entryIndex];
    final images = entry.imageUrls
        .map(CloudinaryImageUrl.forViewer)
        .toList(growable: false);
    final appColors = Theme.of(context).appColors;

    if (images.isEmpty) {
      return Center(
        child: Icon(
          Icons.broken_image,
          color: appColors.heroForegroundMuted,
          size: 80,
        ),
      );
    }

    return _ImageViewerEntryPage(
      entry: entry,
      entryIndex: entryIndex,
      images: images,
      initialImageIndex: _safeImageIndex(entryIndex),
      isInitiallySelectedEntry: entryIndex == widget.initialEntryIndex,
      onImageChanged: (imageIndex) {
        _entryImageIndexes[entryIndex] = imageIndex;
        if (entryIndex != _currentEntryIndex) {
          return;
        }
        setState(() => _currentIndex = imageIndex);
      },
      buildImage:
          ({required imageUrl, required heroTag, required isInitialHero}) =>
              _buildZoomableImage(
                imageUrl: imageUrl,
                heroTag: heroTag,
                isInitialHero: isInitialHero,
              ),
    );
  }

  Widget _buildZoomableImage({
    required String imageUrl,
    required String? heroTag,
    required bool isInitialHero,
  }) {
    final appColors = Theme.of(context).appColors;

    Widget image = ChatMediaCachedImage(
      imageUrl: imageUrl,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorChild: Icon(
        Icons.broken_image,
        color: appColors.heroForegroundMuted,
        size: 80,
      ),
    );

    if (heroTag != null && isInitialHero) {
      image = Hero(tag: heroTag, child: image);
    }

    return _ZoomableViewer(
      onTap: () {
        setState(() => _showChrome = !_showChrome);
      },
      child: Center(child: image),
    );
  }

  void _showCommentsSheet() {
    showAppCommentsSheet(
      context,
      currentCommentCount: _commentCount,
      comments: _comments,
      onCommentCountChanged: (value) {
        if (!mounted) return;
        setState(() => _commentCount = value);
      },
    );
  }

  int? _parseCompactCount(String? rawValue) {
    if (rawValue == null) return null;
    final digits = rawValue.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return int.tryParse(digits);
  }

  void _showShareSuggestions() {
    showAppShareSheet(context);
  }
}

class _ImageViewerEntryPage extends StatefulWidget {
  final ImageViewerEntry entry;
  final int entryIndex;
  final List<String> images;
  final int initialImageIndex;
  final bool isInitiallySelectedEntry;
  final ValueChanged<int> onImageChanged;
  final Widget Function({
    required String imageUrl,
    required String? heroTag,
    required bool isInitialHero,
  })
  buildImage;

  const _ImageViewerEntryPage({
    required this.entry,
    required this.entryIndex,
    required this.images,
    required this.initialImageIndex,
    required this.isInitiallySelectedEntry,
    required this.onImageChanged,
    required this.buildImage,
  });

  @override
  State<_ImageViewerEntryPage> createState() => _ImageViewerEntryPageState();
}

class _ImageViewerEntryPageState extends State<_ImageViewerEntryPage> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialImageIndex);
  }

  @override
  void didUpdateWidget(covariant _ImageViewerEntryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialImageIndex != widget.initialImageIndex &&
        _pageController.hasClients) {
      _pageController.jumpToPage(widget.initialImageIndex);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.length == 1) {
      return widget.buildImage(
        imageUrl: widget.images.first,
        heroTag: widget.entry.heroTag,
        isInitialHero:
            widget.isInitiallySelectedEntry && widget.entry.initialIndex == 0,
      );
    }

    return PageView.builder(
      controller: _pageController,
      key: ValueKey('viewer-entry-${widget.entryIndex}'),
      itemCount: widget.images.length,
      onPageChanged: widget.onImageChanged,
      itemBuilder: (context, imageIndex) {
        return widget.buildImage(
          imageUrl: widget.images[imageIndex],
          heroTag: widget.entry.heroTag,
          isInitialHero:
              widget.isInitiallySelectedEntry &&
              imageIndex == widget.entry.initialIndex &&
              widget.initialImageIndex == widget.entry.initialIndex,
        );
      },
    );
  }
}

class _ZoomableViewer extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _ZoomableViewer({required this.child, this.onTap});

  @override
  State<_ZoomableViewer> createState() => _ZoomableViewerState();
}

class _ZoomableViewerState extends State<_ZoomableViewer> {
  final TransformationController _transformationController =
      TransformationController();
  TapDownDetails? _doubleTapDetails;
  bool _isZoomed = false;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final details = _doubleTapDetails;
    if (details == null) return;

    if (_isZoomed) {
      _transformationController.value = Matrix4.identity();
      setState(() => _isZoomed = false);
      return;
    }

    const zoomScale = 3.0;
    final position = details.localPosition;
    final zoomedMatrix = Matrix4.identity()
      ..translateByDouble(
        -position.dx * (zoomScale - 1),
        -position.dy * (zoomScale - 1),
        0,
        1,
      )
      ..scaleByDouble(zoomScale, zoomScale, 1, 1);

    _transformationController.value = zoomedMatrix;
    setState(() => _isZoomed = true);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 1,
        maxScale: 5,
        boundaryMargin: const EdgeInsets.all(24),
        clipBehavior: Clip.none,
        onInteractionEnd: (_) {
          final currentScale = _transformationController.value
              .getMaxScaleOnAxis();
          if (_isZoomed && currentScale <= 1.01) {
            setState(() => _isZoomed = false);
          }
        },
        child: widget.child,
      ),
    );
  }
}

class _ImageViewerOverlay extends StatelessWidget {
  final ImageViewerOverlayData overlay;
  final String indexLabel;
  final String commentCountLabel;
  final bool isDescriptionExpanded;
  final VoidCallback? onSellerTap;
  final VoidCallback? onSellerMessageTap;
  final VoidCallback? onDescriptionTap;
  final VoidCallback? onCommentTap;
  final VoidCallback? onShareTap;

  const _ImageViewerOverlay({
    required this.overlay,
    required this.indexLabel,
    required this.commentCountLabel,
    required this.isDescriptionExpanded,
    this.onSellerTap,
    this.onSellerMessageTap,
    this.onDescriptionTap,
    this.onCommentTap,
    this.onShareTap,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).appColors;
    final showSeller =
        (overlay.sellerName?.trim().isNotEmpty ?? false) ||
        (overlay.sellerAvatarUrl?.trim().isNotEmpty ?? false);
    final showTitle =
        !overlay.isUserProfileImage &&
        (overlay.title?.trim().isNotEmpty ?? false);
    final showDescription =
        !overlay.isUserProfileImage &&
        (overlay.description?.trim().isNotEmpty ?? false);
    final showInfoCard = showTitle || showDescription;
    final sellerAvatarUrl = overlay.sellerAvatarUrl?.trim();
    final sellerUserId = overlay.sellerUserId?.trim();
    final title = overlay.title?.trim();
    final description = overlay.description?.trim();
    final postedAtLabel = overlay.postedAtLabel?.trim();
    final likesCount = overlay.likesCount?.trim();
    final sharesCount = overlay.sharesCount?.trim();
    final isSellerOnline = _isOnlineStatus(overlay.sellerBadge, postedAtLabel);
    final showMessageAction = !overlay.isUserProfileImage;
    final showLikeAction = !overlay.isUserProfileImage;
    final showCommentAction = !overlay.isUserProfileImage;
    final actionLikes = likesCount?.isNotEmpty == true ? likesCount! : '6 374';
    final actionComments = commentCountLabel;
    final actionShares = sharesCount?.isNotEmpty == true
        ? sharesCount!
        : 'Partager';

    return Row(
      mainAxisAlignment: showInfoCard
          ? MainAxisAlignment.start
          : MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (showInfoCard)
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onDescriptionTap,
                borderRadius: BorderRadius.circular(22),
                child: Ink(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDescriptionExpanded
                        ? appColors.scrimSoft
                        : appColors.overlaySurface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: appColors.overlayBorder),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showTitle)
                        Text(
                          title ?? '',
                          maxLines: isDescriptionExpanded ? null : 2,
                          overflow: isDescriptionExpanded
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.18,
                          ),
                        ),
                      if (showTitle && showDescription)
                        const SizedBox(height: 8),
                      if (showDescription)
                        Text(
                          description ?? '',
                          maxLines: null,
                          overflow: TextOverflow.visible,
                          style: TextStyle(
                            color: appColors.heroForegroundMuted,
                            fontSize: 13.5,
                            height: 1.35,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (showSeller) ...[
          if (showInfoCard) const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 82,
                child: Center(
                  child: GestureDetector(
                    onTap: onSellerTap,
                    child: _SellerStatusAvatar(
                      sellerUserId: sellerUserId,
                      sellerAvatarUrl: sellerAvatarUrl,
                      isOnline: isSellerOnline,
                    ),
                  ),
                ),
              ),
              if (showLikeAction) ...[
                const SizedBox(height: 8),
                _ViewerSocialActionCard(
                  icon: Icons.favorite,
                  label: actionLikes,
                  iconColor: appColors.favoriteAccent,
                ),
              ],
              if (showCommentAction) ...[
                const SizedBox(height: 8),
                _ViewerSocialActionCard(
                  icon: Icons.chat_bubble,
                  label: actionComments,
                  iconColor: appColors.heroForeground,
                  onTap: onCommentTap,
                ),
              ],
              const SizedBox(height: 8),
              _ViewerSocialActionCard(
                icon: Icons.reply_rounded,
                label: actionShares,
                iconColor: appColors.heroForeground,
                onTap: onShareTap,
              ),
              if (showMessageAction) ...[
                const SizedBox(height: 8),
                _MessageActionCard(onTap: onSellerMessageTap),
              ],
            ],
          ),
        ],
      ],
    );
  }

  bool _isOnlineStatus(String? badge, String? postedAtLabel) {
    final badgeText = (badge ?? '').toLowerCase();
    final postedText = (postedAtLabel ?? '').toLowerCase();
    return badgeText.contains('ligne') ||
        badgeText.contains('online') ||
        badgeText.contains('actif') ||
        postedText.contains('ligne');
  }
}

class _ViewerSocialActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback? onTap;

  const _ViewerSocialActionCard({
    required this.icon,
    required this.label,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).appColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: 82,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
          decoration: BoxDecoration(
            color: appColors.overlaySurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: appColors.overlayBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: appColors.heroForeground,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageActionCard extends StatelessWidget {
  final VoidCallback? onTap;

  const _MessageActionCard({this.onTap});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).appColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: 82,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
          decoration: BoxDecoration(
            color: appColors.overlaySurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: appColors.overlayBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.send_rounded,
                size: 20,
                color: appColors.heroForeground,
              ),
              const SizedBox(height: 4),
              Text(
                'Message',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: appColors.heroForeground,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SellerStatusAvatar extends StatelessWidget {
  final String? sellerUserId;
  final String? sellerAvatarUrl;
  final bool isOnline;

  const _SellerStatusAvatar({
    this.sellerUserId,
    this.sellerAvatarUrl,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).appColors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 50,
          height: 50,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: appColors.heroSurface,
            border: Border.all(color: appColors.heroBorder),
          ),
          child: sellerAvatarUrl?.isNotEmpty == true
              ? AppCircleNetworkAvatar(
                  radius: 23,
                  imageUrl: sellerAvatarUrl!,
                  userId: sellerUserId,
                )
              : Container(
                  decoration: BoxDecoration(
                    color: appColors.heroSurface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person, color: appColors.heroForeground),
                ),
        ),
      ],
    );
  }
}
