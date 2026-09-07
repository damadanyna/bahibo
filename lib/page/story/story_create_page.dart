import 'dart:async';
import 'dart:io';

import 'package:banay/component/app_network_image.dart';
import 'package:banay/component/upload_water_fill_progress.dart';
import 'package:banay/localization/banay_localizations.dart';
import 'package:banay/services/app_api_client.dart';
import 'package:banay/services/app_logger.dart';
import 'package:banay/services/stories_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Story composer: pick a photo or a short video (gallery or camera),
/// preview it full-screen with an optional caption, publish. The upload
/// shows the app's "liquid" progress fill. Pops `true` on success.
class StoryCreatePage extends StatefulWidget {
  const StoryCreatePage({
    super.key,
    this.currentUserName = '',
    this.currentUserAvatarUrl = '',
  });

  final String currentUserName;
  final String currentUserAvatarUrl;

  @override
  State<StoryCreatePage> createState() => _StoryCreatePageState();
}

class _StoryCreatePageState extends State<StoryCreatePage> {
  static const int _captionMaxLength = 300;

  /// Same caps as the backend (`STORY_VIDEO_MAX_SECONDS`,
  /// `STORY_UPLOAD_MAX_BYTES`). The weight is checked here because the
  /// media goes straight to Cloudinary, which no longer enforces it.
  static const int _videoMaxSeconds = 60;
  static const int _videoMaxMegabytes = 60;
  static const String _tag = 'StoryCreatePage';

  final ImagePicker _imagePicker = ImagePicker();
  final StoriesApiService _storiesApiService = StoriesApiService();
  final TextEditingController _captionController = TextEditingController();

  File? _mediaFile;
  StoryMediaType _mediaType = StoryMediaType.image;
  VideoPlayerController? _previewController;
  int? _videoDurationSeconds;
  bool _isPublishing = false;
  double _uploadProgress = 0;

  @override
  void dispose() {
    // Safety net: a successful publish pops the page while the lock is on.
    unawaited(WakelockPlus.disable());
    _captionController.dispose();
    final controller = _previewController;
    _previewController = null;
    if (controller != null) {
      unawaited(_disposeQuietly(controller));
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Picking
  // ---------------------------------------------------------------------

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Same downscale as product/avatar pickers: keeps the upload light
      // on mobile data, Cloudinary re-encodes for the viewer anyway.
      final file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1800,
      );
      if (file == null || !mounted) {
        return;
      }
      await _disposePreview();
      if (!mounted) {
        return;
      }
      setState(() {
        _mediaFile = File(file.path);
        _mediaType = StoryMediaType.image;
        _videoDurationSeconds = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar(context.tr(BanayLocalizationKeys.homeStoryImagePickFailed));
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    XFile? file;
    try {
      // maxDuration is enforced by the camera; gallery picks are checked
      // below once the preview player knows the real length.
      file = await _imagePicker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: _videoMaxSeconds),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar(context.tr(BanayLocalizationKeys.homeStoryImagePickFailed));
      return;
    }
    if (file == null || !mounted) {
      return;
    }
    await _setVideoFile(File(file.path));
  }

  Future<void> _setVideoFile(File file) async {
    final controller = VideoPlayerController.file(file);
    try {
      await controller.initialize();
    } catch (error) {
      // MissingPluginException here means the app was hot-reloaded after
      // adding video_player: a full rebuild is needed.
      AppLogger.warning(_tag, 'Video preview failed: ${file.path}', error);
      await _disposeQuietly(controller);
      if (!mounted) {
        return;
      }
      _showSnackBar(
        context.tr(BanayLocalizationKeys.homeStoryVideoPreviewFailed),
      );
      return;
    }
    if (!mounted) {
      await _disposeQuietly(controller);
      return;
    }

    final durationMs = controller.value.duration.inMilliseconds;
    final durationSeconds = (durationMs / 1000).ceil();
    if (durationSeconds > _videoMaxSeconds) {
      await _disposeQuietly(controller);
      if (!mounted) {
        return;
      }
      _showSnackBar(
        context.tr(
          BanayLocalizationKeys.homeStoryVideoTooLong,
          params: {'seconds': '$_videoMaxSeconds'},
        ),
      );
      return;
    }

    final fileBytes = await file.length();
    if (fileBytes > _videoMaxMegabytes * 1024 * 1024) {
      await _disposeQuietly(controller);
      if (!mounted) {
        return;
      }
      _showSnackBar(
        context.tr(
          BanayLocalizationKeys.homeStoryVideoTooLarge,
          params: {'size': '$_videoMaxMegabytes'},
        ),
      );
      return;
    }

    await _disposePreview();
    if (!mounted) {
      await _disposeQuietly(controller);
      return;
    }
    await controller.setLooping(true);
    await controller.play();
    setState(() {
      _mediaFile = file;
      _mediaType = StoryMediaType.video;
      _previewController = controller;
      _videoDurationSeconds = durationSeconds;
    });
  }

  Future<void> _disposePreview() async {
    final controller = _previewController;
    _previewController = null;
    if (controller != null) {
      await _disposeQuietly(controller);
    }
  }

  /// A player whose native side never came up (plugin missing, decoder
  /// error) can throw again on dispose; the snackbar must still show.
  static Future<void> _disposeQuietly(VideoPlayerController controller) async {
    try {
      await controller.dispose();
    } catch (error) {
      AppLogger.warning(_tag, 'Video controller dispose failed', error);
    }
  }

  Future<void> _clearMedia() async {
    await _disposePreview();
    if (!mounted) {
      return;
    }
    setState(() {
      _mediaFile = null;
      _mediaType = StoryMediaType.image;
      _videoDurationSeconds = null;
    });
  }

  // ---------------------------------------------------------------------
  // Publishing
  // ---------------------------------------------------------------------

  Future<void> _publish() async {
    final mediaFile = _mediaFile;
    if (mediaFile == null || _isPublishing) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isPublishing = true;
      _uploadProgress = 0;
    });
    // A locked screen would pause the app and stall the transfer.
    unawaited(WakelockPlus.enable());
    // Keep the preview still while the file is streamed out.
    await _previewController?.pause();

    try {
      await _storiesApiService.publishStory(
        mediaFile: mediaFile,
        mediaType: _mediaType,
        caption: _captionController.text,
        durationSeconds: _videoDurationSeconds,
        onUploadProgress: (sentBytes, totalBytes) {
          if (!mounted || totalBytes <= 0) {
            return;
          }
          final next = (sentBytes / totalBytes).clamp(0.0, 1.0);
          // One repaint per percent, not per network chunk.
          if (next >= 1 || (next - _uploadProgress) >= 0.01) {
            setState(() => _uploadProgress = next);
          }
        },
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on AppApiException catch (error) {
      if (!mounted) {
        return;
      }
      _endPublishing();
      _showSnackBar(error.message);
      await _previewController?.play();
    } catch (_) {
      if (!mounted) {
        return;
      }
      _endPublishing();
      _showSnackBar(context.tr(BanayLocalizationKeys.homeStoryPublishFailed));
      await _previewController?.play();
    }
  }

  void _endPublishing() {
    unawaited(WakelockPlus.disable());
    setState(() => _isPublishing = false);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final mediaFile = _mediaFile;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        canPop: !_isPublishing,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: mediaFile == null
              ? _buildPicker(context)
              : _buildPreview(context, mediaFile),
        ),
      ),
    );
  }

  Widget _buildPicker(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final name = widget.currentUserName.trim().isEmpty
        ? context.tr(BanayLocalizationKeys.homeDefaultStoreName)
        : widget.currentUserName.trim();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded),
                  color: Colors.white,
                ),
                Expanded(
                  child: Text(
                    context.tr(BanayLocalizationKeys.homeStoryCreateTitle),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                AppCircleNetworkAvatar(
                  imageUrl: normalizeAvatarUrl(widget.currentUserAvatarUrl),
                  radius: 24,
                  showPresenceBadge: false,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      const SizedBox(height: 2),
                      Text(
                        context.tr(
                          BanayLocalizationKeys.homeStoryCreateSubtitle,
                        ),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StoryOptionCard(
                          icon: Icons.photo_library_rounded,
                          title: context.tr(
                            BanayLocalizationKeys.homeStoryPickGallery,
                          ),
                          subtitle: context.tr(
                            BanayLocalizationKeys.homeStoryPickGallerySubtitle,
                          ),
                          colors: [primary, const Color(0xFF7C3AED)],
                          onTap: () => _pickImage(ImageSource.gallery),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StoryOptionCard(
                          icon: Icons.photo_camera_rounded,
                          title: context.tr(
                            BanayLocalizationKeys.homeStoryPickCamera,
                          ),
                          subtitle: context.tr(
                            BanayLocalizationKeys.homeStoryPickCameraSubtitle,
                          ),
                          colors: const [Color(0xFF0EA5E9), Color(0xFF14B8A6)],
                          onTap: () => _pickImage(ImageSource.camera),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StoryOptionCard(
                          icon: Icons.video_library_rounded,
                          title: context.tr(
                            BanayLocalizationKeys.homeStoryPickVideoGallery,
                          ),
                          subtitle: context.tr(
                            BanayLocalizationKeys.homeStoryPickGallerySubtitle,
                          ),
                          colors: const [Color(0xFFF97316), Color(0xFFEF4444)],
                          onTap: () => _pickVideo(ImageSource.gallery),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StoryOptionCard(
                          icon: Icons.videocam_rounded,
                          title: context.tr(
                            BanayLocalizationKeys.homeStoryPickVideoCamera,
                          ),
                          subtitle: context.tr(
                            BanayLocalizationKeys.homeStoryPickCameraSubtitle,
                          ),
                          colors: const [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                          onTap: () => _pickVideo(ImageSource.camera),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context, File mediaFile) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildPreviewMedia(mediaFile),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.18, 0.65, 1.0],
                colors: [
                  Color(0x8A000000),
                  Colors.transparent,
                  Colors.transparent,
                  Color(0xB3000000),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(
                  onPressed: _isPublishing ? null : _clearMedia,
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: Colors.white,
                ),
                const Spacer(),
                if (_mediaType == StoryMediaType.video &&
                    _videoDurationSeconds != null)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.videocam_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_videoDurationSeconds}s',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                IconButton(
                  onPressed: _isPublishing
                      ? null
                      : () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded),
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _captionController,
                    enabled: !_isPublishing,
                    minLines: 1,
                    maxLines: 3,
                    maxLength: _captionMaxLength,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: context.tr(
                        BanayLocalizationKeys.homeStoryCaptionHint,
                      ),
                      hintStyle: const TextStyle(color: Colors.white60),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.14),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isPublishing ? null : _publish,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: primary.withValues(alpha: 0.6),
                        disabledForegroundColor: Colors.white70,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        context.tr(
                          BanayLocalizationKeys.homeStoryPublishAction,
                        ),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isPublishing)
          _UploadProgressOverlay(
            progress: _uploadProgress,
            primary: primary,
            label: context.tr(BanayLocalizationKeys.homeStoryUploading),
            finalizingLabel: context.tr(
              BanayLocalizationKeys.homeStoryFinalizing,
            ),
          ),
      ],
    );
  }

  Widget _buildPreviewMedia(File mediaFile) {
    final controller = _previewController;
    if (_mediaType == StoryMediaType.video &&
        controller != null &&
        controller.value.isInitialized) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _isPublishing
            ? null
            : () {
                if (controller.value.isPlaying) {
                  controller.pause();
                } else {
                  controller.play();
                }
              },
        child: Center(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio <= 0
                ? 9 / 16
                : controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
        ),
      );
    }

    return Image.file(
      mediaFile,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}

/// The chat's liquid upload fill, centered over the dimmed preview. Once
/// every byte is out the fill is replaced by a plain spinner and
/// [finalizingLabel]: the server is then pushing the file to Cloudinary,
/// and a percentage stuck at 100 would look frozen.
class _UploadProgressOverlay extends StatelessWidget {
  const _UploadProgressOverlay({
    required this.progress,
    required this.primary,
    required this.label,
    required this.finalizingLabel,
  });

  static const TextStyle _labelStyle = TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );

  final double progress;
  final Color primary;
  final String label;
  final String finalizingLabel;

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    final isFinalizing = clampedProgress >= 1;

    return Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: Colors.black54,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: isFinalizing
                  ? _buildFinalizing()
                  : _buildUploading(clampedProgress),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFinalizing() {
    return Column(
      key: const ValueKey('story-upload-finalizing'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 34,
          height: 34,
          child: CircularProgressIndicator(
            strokeWidth: 2.6,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(finalizingLabel, style: _labelStyle),
      ],
    );
  }

  Widget _buildUploading(double clampedProgress) {
    final percent = (clampedProgress * 100).round().clamp(1, 100);

    return Column(
      key: const ValueKey('story-upload-progress'),
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: SizedBox(
            width: 132,
            height: 132,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: Colors.white.withValues(alpha: 0.1)),
                WaterFillProgressLayer(
                  progress: clampedProgress,
                  primary: primary,
                  visualState: WaterFillVisualState.uploading,
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_upload_outlined,
                        color: Colors.white,
                        size: 30,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$percent%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(label, style: _labelStyle),
      ],
    );
  }
}

class _StoryOptionCard extends StatelessWidget {
  const _StoryOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 150,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
