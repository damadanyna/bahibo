export 'image_viewer_page.dart' show ImageViewerEntry, ImageViewerOverlayData;

import 'dart:async';

import 'package:banay/component/app_back_button.dart';
import 'package:banay/component/app_page_refresh.dart';
import 'package:banay/component/app_page_skeletons.dart';
import 'package:banay/component/chat_media_cached_image.dart';
import 'package:banay/page/image_viewer_page.dart'
    show ImageViewerEntry, ImageViewerOverlayData;
import 'package:banay/services/chat_media_cache_service.dart';
import 'package:banay/services/cloudinary_image_url.dart';
import 'package:banay/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';

class PrivateImageViewerPage extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final int initialEntryIndex;
  final String? heroTag;
  final ImageViewerOverlayData? overlay;
  final List<ImageViewerEntry>? entries;
  final VoidCallback? onSellerTap;
  final VoidCallback? onSellerMessageTap;
  final Future<void> Function(String imageUrl)? onDownloadImage;

  const PrivateImageViewerPage({
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
  State<PrivateImageViewerPage> createState() => _PrivateImageViewerPageState();
}

class _PrivateImageViewerPageState extends State<PrivateImageViewerPage>
    with AppPageRefreshMixin<PrivateImageViewerPage> {
  late final PageController _entryPageController;
  late final List<ImageViewerEntry> _entries;
  final Map<int, int> _entryImageIndexes = <int, int>{};
  late int _currentEntryIndex;
  late int _currentIndex;
  bool _showEntrySkeleton = true;
  bool _showChrome = true;
  bool _isDownloadingImage = false;

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
    _entryPageController = PageController(initialPage: _currentEntryIndex);
    _prefetchViewerNeighborhood(_currentEntryIndex, _currentIndex);
    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) {
        return;
      }
      setState(() => _showEntrySkeleton = false);
    });
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
    if (!mounted) {
      return;
    }
    setState(() => _showEntrySkeleton = false);
  }

  @override
  Widget build(BuildContext context) {
    final activeEntry = _entries[_currentEntryIndex];
    final images = activeEntry.imageUrls
        .map(CloudinaryImageUrl.forViewer)
        .toList(growable: false);
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
                return _PrivateImageViewerEntryPage(
                  entry: _entries[entryIndex],
                  entryIndex: entryIndex,
                  images: _entries[entryIndex].imageUrls
                      .map(CloudinaryImageUrl.forViewer)
                      .toList(growable: false),
                  initialImageIndex: _safeImageIndex(entryIndex),
                  isInitiallySelectedEntry:
                      entryIndex == widget.initialEntryIndex,
                  onImageChanged: (imageIndex) {
                    _entryImageIndexes[entryIndex] = imageIndex;
                    if (entryIndex != _currentEntryIndex) {
                      return;
                    }
                    setState(() => _currentIndex = imageIndex);
                  },
                  buildImage:
                      ({
                        required imageUrl,
                        required heroTag,
                        required isInitialHero,
                      }) => _buildZoomableImage(
                        imageUrl: imageUrl,
                        heroTag: heroTag,
                        isInitialHero: isInitialHero,
                      ),
                );
              },
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
          if (isOffline) const AppOfflineBanner(bottomOffset: 18),
        ],
      ),
    );
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
    final nextImageIndex = _safeImageIndex(entryIndex);
    setState(() {
      _currentEntryIndex = entryIndex;
      _currentIndex = nextImageIndex;
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

    return _PrivateZoomableViewer(
      onTap: () {
        setState(() => _showChrome = !_showChrome);
      },
      child: Center(child: image),
    );
  }
}

class _PrivateImageViewerEntryPage extends StatefulWidget {
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

  const _PrivateImageViewerEntryPage({
    required this.entry,
    required this.entryIndex,
    required this.images,
    required this.initialImageIndex,
    required this.isInitiallySelectedEntry,
    required this.onImageChanged,
    required this.buildImage,
  });

  @override
  State<_PrivateImageViewerEntryPage> createState() =>
      _PrivateImageViewerEntryPageState();
}

class _PrivateImageViewerEntryPageState
    extends State<_PrivateImageViewerEntryPage> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialImageIndex);
  }

  @override
  void didUpdateWidget(covariant _PrivateImageViewerEntryPage oldWidget) {
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
      key: ValueKey('private-viewer-entry-${widget.entryIndex}'),
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

class _PrivateZoomableViewer extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _PrivateZoomableViewer({required this.child, this.onTap});

  @override
  State<_PrivateZoomableViewer> createState() => _PrivateZoomableViewerState();
}

class _PrivateZoomableViewerState extends State<_PrivateZoomableViewer> {
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
    if (details == null) {
      return;
    }

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
