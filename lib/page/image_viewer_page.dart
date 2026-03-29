import 'package:flutter/material.dart';
import 'package:bahibo/component/app_back_button.dart';
import 'package:bahibo/component/app_comments_sheet.dart';
import 'package:bahibo/component/app_network_image.dart';
import 'package:bahibo/component/app_page_skeletons.dart';
import 'package:bahibo/component/app_page_refresh.dart';
import 'package:bahibo/component/app_share_sheet.dart';
import 'package:bahibo/theme/app_theme_extensions.dart';

class ImageViewerOverlayData {
  final String? title;
  final String? description;
  final String? sellerName;
  final String? sellerAvatarUrl;
  final String? sellerBadge;
  final String? sellerHandle;
  final String? musicLabel;
  final String? postedAtLabel;
  final String? likesCount;
  final String? commentsCount;
  final String? sharesCount;

  const ImageViewerOverlayData({
    this.title,
    this.description,
    this.sellerName,
    this.sellerAvatarUrl,
    this.sellerBadge,
    this.sellerHandle,
    this.musicLabel,
    this.postedAtLabel,
    this.likesCount,
    this.commentsCount,
    this.sharesCount,
  });

  bool get hasContent =>
      (title != null && title!.trim().isNotEmpty) ||
      (description != null && description!.trim().isNotEmpty) ||
      (sellerName != null && sellerName!.trim().isNotEmpty) ||
      (sellerAvatarUrl != null && sellerAvatarUrl!.trim().isNotEmpty) ||
      (sellerBadge != null && sellerBadge!.trim().isNotEmpty) ||
      (sellerHandle != null && sellerHandle!.trim().isNotEmpty) ||
      (musicLabel != null && musicLabel!.trim().isNotEmpty) ||
      (postedAtLabel != null && postedAtLabel!.trim().isNotEmpty) ||
      (likesCount != null && likesCount!.trim().isNotEmpty) ||
      (commentsCount != null && commentsCount!.trim().isNotEmpty) ||
      (sharesCount != null && sharesCount!.trim().isNotEmpty);
}

class ImageViewerPage extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final String? heroTag;
  final ImageViewerOverlayData? overlay;
  final VoidCallback? onSellerTap;
  final VoidCallback? onSellerMessageTap;

  const ImageViewerPage({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.heroTag,
    this.overlay,
    this.onSellerTap,
    this.onSellerMessageTap,
  });

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage>
    with AppPageRefreshMixin<ImageViewerPage> {
  late final PageController _pageController;
  late int _currentIndex;
  int _commentCount = 64;
  bool _showEntrySkeleton = true;
  bool _showChrome = true;
  bool _isDescriptionExpanded = false;
  final List<AppCommentItem> _comments = defaultAppComments();

  @override
  void initState() {
    super.initState();
    initializePageRefresh();
    _currentIndex = widget.initialIndex.clamp(
      0,
      widget.imageUrls.isEmpty ? 0 : widget.imageUrls.length - 1,
    );
    _commentCount = _parseCompactCount(widget.overlay?.commentsCount) ?? 64;
    _pageController = PageController(initialPage: _currentIndex);
    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() => _showEntrySkeleton = false);
    });
  }

  @override
  void didUpdateWidget(covariant ImageViewerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final updatedCount = _parseCompactCount(widget.overlay?.commentsCount);
    if (updatedCount != null && updatedCount != _commentCount) {
      _commentCount = updatedCount;
    }
  }

  @override
  void dispose() {
    disposePageRefresh();
    _pageController.dispose();
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
    final images = widget.imageUrls;
    final overlay = widget.overlay;
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
              controller: _pageController,
              itemCount: images.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                Widget image = AppNetworkImage(
                  imageUrl: images[index],
                  fit: BoxFit.contain,
                  errorChild: Icon(
                    Icons.broken_image,
                    color: appColors.heroForegroundMuted,
                    size: 80,
                  ),
                );

                if (widget.heroTag != null && index == widget.initialIndex) {
                  image = Hero(tag: widget.heroTag!, child: image);
                }

                return _ZoomableViewer(
                  onTap: () {
                    setState(() => _showChrome = !_showChrome);
                  },
                  child: Center(child: image),
                );
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
                          images.isEmpty
                              ? 'Image'
                              : '${_currentIndex + 1}/${images.length}',
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
                    indexLabel: images.isEmpty
                        ? 'Image'
                        : '${_currentIndex + 1}/${images.length}',
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
      ..translate(
        -position.dx * (zoomScale - 1),
        -position.dy * (zoomScale - 1),
      )
      ..scale(zoomScale);

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
    final showTitle = overlay.title?.trim().isNotEmpty ?? false;
    final showDescription = overlay.description?.trim().isNotEmpty ?? false;
    final sellerAvatarUrl = overlay.sellerAvatarUrl?.trim();
    final title = overlay.title?.trim();
    final description = overlay.description?.trim();
    final postedAtLabel = overlay.postedAtLabel?.trim();
    final likesCount = overlay.likesCount?.trim();
    final sharesCount = overlay.sharesCount?.trim();
    final isSellerOnline = _isOnlineStatus(overlay.sellerBadge, postedAtLabel);
    final actionLikes = likesCount?.isNotEmpty == true ? likesCount! : '6 374';
    final actionComments = commentCountLabel;
    final actionShares = sharesCount?.isNotEmpty == true
        ? sharesCount!
        : 'Partager';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
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
                    if (showTitle && showDescription) const SizedBox(height: 8),
                    if (showDescription)
                      Text(
                        description ?? '',
                        maxLines: isDescriptionExpanded ? null : 3,
                        overflow: isDescriptionExpanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: TextStyle(
                          color: appColors.heroForegroundMuted,
                          fontSize: 13.5,
                          height: 1.35,
                        ),
                      ),
                    if (showDescription) const SizedBox(height: 6),
                    if (showDescription)
                      Text(
                        isDescriptionExpanded ? 'Voir moins' : 'Voir plus',
                        style: TextStyle(
                          color: appColors.onlineStatus,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showSeller) ...[
          const SizedBox(width: 10),
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
                      sellerAvatarUrl: sellerAvatarUrl,
                      isOnline: isSellerOnline,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _ViewerSocialActionCard(
                icon: Icons.favorite,
                label: actionLikes,
                iconColor: appColors.favoriteAccent,
              ),
              const SizedBox(height: 8),
              _ViewerSocialActionCard(
                icon: Icons.chat_bubble,
                label: actionComments,
                iconColor: appColors.heroForeground,
                onTap: onCommentTap,
              ),
              const SizedBox(height: 8),
              _ViewerSocialActionCard(
                icon: Icons.reply_rounded,
                label: actionShares,
                iconColor: appColors.heroForeground,
                onTap: onShareTap,
              ),
              const SizedBox(height: 8),
              _MessageActionCard(onTap: onSellerMessageTap),
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
  final String? sellerAvatarUrl;
  final bool isOnline;

  const _SellerStatusAvatar({this.sellerAvatarUrl, required this.isOnline});

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
              ? AppCircleNetworkAvatar(radius: 23, imageUrl: sellerAvatarUrl!)
              : Container(
                  decoration: BoxDecoration(
                    color: appColors.heroSurface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person, color: appColors.heroForeground),
                ),
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: isOnline ? appColors.onlineStatus : appColors.mutedText,
              shape: BoxShape.circle,
              border: Border.all(color: appColors.heroForeground, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
