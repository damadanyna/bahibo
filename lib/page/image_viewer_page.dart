import 'package:flutter/material.dart';
import 'package:bahibo/component/app_network_image.dart';
import 'package:bahibo/component/app_page_skeletons.dart';
import 'package:bahibo/component/app_page_refresh.dart';

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

  const ImageViewerPage({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.heroTag,
    this.overlay,
    this.onSellerTap,
  });

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage>
    with AppPageRefreshMixin<ImageViewerPage> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _showEntrySkeleton = true;

  @override
  void initState() {
    super.initState();
    initializePageRefresh();
    _currentIndex = widget.initialIndex.clamp(
      0,
      widget.imageUrls.isEmpty ? 0 : widget.imageUrls.length - 1,
    );
    _pageController = PageController(initialPage: _currentIndex);
    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() => _showEntrySkeleton = false);
    });
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (images.isEmpty)
            const Center(
              child: Icon(Icons.broken_image, color: Colors.white54, size: 80),
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
                  errorChild: const Icon(
                    Icons.broken_image,
                    color: Colors.white54,
                    size: 80,
                  ),
                );

                if (widget.heroTag != null && index == widget.initialIndex) {
                  image = Hero(tag: widget.heroTag!, child: image);
                }

                return _ZoomableViewer(child: Center(child: image));
              },
            ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.36),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.84),
                    ],
                    stops: const [0, 0.18, 0.52, 1],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(
                children: [
                  Material(
                    color: Colors.black.withOpacity(0.34),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).maybePop(),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        children: [
                          const TextSpan(text: 'Following'),
                          TextSpan(
                            text: '  |  ',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const TextSpan(text: 'For You'),
                        ],
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
                      color: Colors.black.withOpacity(0.34),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withOpacity(0.14)),
                    ),
                    child: Text(
                      images.isEmpty
                          ? 'Image'
                          : '${_currentIndex + 1}/${images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (overlay != null && overlay.hasContent)
            Positioned(
              left: 16,
              right: 16,
              bottom: bottomOverlayOffset,
              child: _ImageViewerOverlay(
                overlay: overlay,
                onSellerTap: widget.onSellerTap,
                indexLabel: images.isEmpty
                    ? 'Image'
                    : '${_currentIndex + 1}/${images.length}',
              ),
            ),
          if (isOffline) const AppOfflineBanner(bottomOffset: 18),
        ],
      ),
    );
  }
}

class _ZoomableViewer extends StatefulWidget {
  final Widget child;

  const _ZoomableViewer({required this.child});

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
  final VoidCallback? onSellerTap;

  const _ImageViewerOverlay({
    required this.overlay,
    required this.indexLabel,
    this.onSellerTap,
  });

  @override
  Widget build(BuildContext context) {
    final showSeller =
        (overlay.sellerName?.trim().isNotEmpty ?? false) ||
        (overlay.sellerAvatarUrl?.trim().isNotEmpty ?? false);
    final showTitle = overlay.title?.trim().isNotEmpty ?? false;
    final showDescription = overlay.description?.trim().isNotEmpty ?? false;
    final showBadge = overlay.sellerBadge?.trim().isNotEmpty ?? false;
    final sellerAvatarUrl = overlay.sellerAvatarUrl?.trim();
    final sellerName = overlay.sellerName?.trim();
    final sellerBadge = overlay.sellerBadge?.trim();
    final title = overlay.title?.trim();
    final description = overlay.description?.trim();
    final sellerHandle = overlay.sellerHandle?.trim();
    final musicLabel = overlay.musicLabel?.trim();
    final postedAtLabel = overlay.postedAtLabel?.trim();
    final likesCount = overlay.likesCount?.trim() ?? '6 374';
    final commentsCount = overlay.commentsCount?.trim() ?? '64';
    final sharesCount = overlay.sharesCount?.trim() ?? 'Partager';
    final handle = sellerHandle?.isNotEmpty == true
        ? sellerHandle!
        : '@${(sellerName?.isNotEmpty == true ? sellerName! : 'bahibo').toLowerCase().replaceAll(' ', '')}';
    final infoLine = postedAtLabel?.isNotEmpty == true
        ? '$handle · $postedAtLabel'
        : '$handle · 1-25';
    final musicText = musicLabel?.isNotEmpty == true
        ? musicLabel!
        : 'Music name here - Artist Name';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.18),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    infoLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (showTitle)
                    Text(
                      title ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.18,
                      ),
                    ),
                  if (showTitle && showDescription) const SizedBox(height: 8),
                  if (showDescription)
                    Text(
                      description ?? '',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.88),
                        fontSize: 13.5,
                        height: 1.35,
                      ),
                    ),
                  if (showBadge) const SizedBox(height: 10),
                  if (showBadge)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D8E4B).withOpacity(0.82),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        sellerBadge ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.music_note_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          musicText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.92),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSeller)
              GestureDetector(
                onTap: onSellerTap,
                child: _ProfileActionCluster(
                  sellerAvatarUrl: sellerAvatarUrl,
                  sellerName: sellerName,
                ),
              ),
            if (showSeller) const SizedBox(height: 12),
            IgnorePointer(
              child: _OverlayActionBadge(
                icon: Icons.favorite,
                label: likesCount,
                accentColor: const Color(0xFFFF4D6D),
              ),
            ),
            const SizedBox(height: 10),
            IgnorePointer(
              child: _OverlayActionBadge(
                icon: Icons.chat_bubble,
                label: commentsCount,
              ),
            ),
            const SizedBox(height: 10),
            IgnorePointer(
              child: _OverlayActionBadge(
                icon: Icons.reply_rounded,
                label: sharesCount,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileActionCluster extends StatelessWidget {
  final String? sellerAvatarUrl;
  final String? sellerName;

  const _ProfileActionCluster({
    required this.sellerAvatarUrl,
    required this.sellerName,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.22),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: sellerAvatarUrl?.isNotEmpty == true
              ? AppCircleNetworkAvatar(radius: 22, imageUrl: sellerAvatarUrl!)
              : Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: Colors.white),
                ),
        ),
        Positioned(
          right: -4,
          bottom: -4,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFFFF2851),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.6),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 14),
          ),
        ),
      ],
    );
  }
}

class _SellerPresenceAvatar extends StatelessWidget {
  final String? sellerAvatarUrl;

  const _SellerPresenceAvatar({this.sellerAvatarUrl});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 54,
          height: 54,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.10),
            border: Border.all(color: Colors.white.withOpacity(0.22)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.28),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: sellerAvatarUrl?.isNotEmpty == true
              ? AppCircleNetworkAvatar(radius: 25, imageUrl: sellerAvatarUrl!)
              : Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: Colors.white),
                ),
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFF57D163),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _OverlayActionBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? accentColor;

  const _OverlayActionBadge({
    required this.icon,
    required this.label,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accentColor ?? Colors.white, size: 20),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
