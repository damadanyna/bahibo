import 'dart:async';
import 'dart:io';

import 'package:bahibo/component/app_network_image.dart';
import 'package:bahibo/component/ui/dinamic_icon_button.dart';
import 'package:bahibo/page/image_viewer_page.dart';
import 'package:bahibo/services/app_api_client.dart';
import 'package:bahibo/services/app_auth_service.dart';
import 'package:bahibo/services/chat_realtime_service.dart';
import 'package:bahibo/theme/app_theme_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

enum _EditableImageTarget { cover, avatar }

class MainSimpleUser extends StatefulWidget {
  const MainSimpleUser({super.key});

  @override
  State<MainSimpleUser> createState() => _MainSimpleUserState();
}

class _MainSimpleUserState extends State<MainSimpleUser> {
  final AppAuthService _authService = AppAuthService();
  final ImagePicker _imagePicker = ImagePicker();
  StreamSubscription<Map<String, dynamic>>? _realtimeEventsSubscription;

  bool _isLoading = true;
  bool _isUploadingImage = false;
  bool _isUpdatingDisplayName = false;
  bool _isSubmittingShopRequest = false;
  bool _isLoadingLocation = true;
  bool _isSavingLocation = false;
  String? _profileLoadError;
  String? _locationLabel;
  DateTime? _displayNameChangedAt;
  DateTime? _nextDisplayNameChangeAt;
  String _displayName = 'Utilisateur Bahibo';
  String _avatarUrl = '';
  String _coverImageUrl = '';
  String? _currentUserId;
  String _userRole = 'CUSTOMER';
  String _shopRequestStatus = 'NONE';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadCurrentLocation();
    _bindRealtimeProfileUpdates();
  }

  @override
  void dispose() {
    _realtimeEventsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final user = await _authService.fetchCurrentUser();

      if (!mounted) {
        return;
      }

      final avatarUrl = (user['avatarUrl'] as String?)?.trim() ?? '';
      final coverImageUrl = (user['coverImageUrl'] as String?)?.trim() ?? '';
      final locationLabel = (user['locationLabel'] as String?)?.trim() ?? '';
      final role = (user['role'] as String?)?.trim() ?? 'CUSTOMER';
      final shopRequestStatus =
          (user['shopRequestStatus'] as String?)?.trim() ?? 'NONE';
      final displayNameChangedAt = _parseApiDateTime(user['displayNameChangedAt']);
      final nextDisplayNameChangeAt = _parseApiDateTime(
        user['nextDisplayNameChangeAt'],
      );
      setState(() {
        _currentUserId = user['id']?.toString().trim();
        _displayName =
            (user['displayName'] as String?)?.trim().isNotEmpty == true
            ? (user['displayName'] as String).trim()
            : _displayName;
        _displayNameChangedAt = displayNameChangedAt;
        _nextDisplayNameChangeAt = nextDisplayNameChangeAt;
        _avatarUrl = avatarUrl;
        _coverImageUrl = coverImageUrl;
        _userRole = role;
        _shopRequestStatus = shopRequestStatus;
        if (locationLabel.isNotEmpty) {
          _locationLabel = locationLabel;
          _isLoadingLocation = false;
        }
        _isLoading = false;
        _profileLoadError = null;
      });
    } on AppApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _profileLoadError = error.message;
      });
    }
  }

  void _bindRealtimeProfileUpdates() {
    ChatRealtimeService.instance.ensureConnected();
    _realtimeEventsSubscription?.cancel();
    _realtimeEventsSubscription = ChatRealtimeService.instance.events.listen((
      event,
    ) {
      if (event['type'] != 'profile:shop-request-updated') {
        return;
      }

      if (!mounted) {
        return;
      }

      unawaited(_loadProfile());
    });
  }

  DateTime? _parseApiDateTime(Object? rawValue) {
    if (rawValue is! String || rawValue.trim().isEmpty) {
      return null;
    }

    return DateTime.tryParse(rawValue.trim())?.toLocal();
  }

  bool get _canUpdateDisplayName {
    final nextChangeAt = _nextDisplayNameChangeAt;
    if (nextChangeAt == null) {
      return true;
    }

    return !DateTime.now().isBefore(nextChangeAt);
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day/$month/$year';
  }

  String get _displayNamePolicyLabel {
    final nextChangeAt = _nextDisplayNameChangeAt;
    if (nextChangeAt == null) {
      return 'Vous pouvez modifier votre nom maintenant. Apres chaque modification, le prochain changement sera disponible dans 3 mois.';
    }

    if (_canUpdateDisplayName) {
      return 'Vous pouvez modifier votre nom maintenant. Le nom utilisateur ne peut etre modifie qu\'une fois tous les 3 mois.';
    }

    return 'Le nom utilisateur ne peut etre modifie qu\'une fois tous les 3 mois. Prochaine date autorisee: ${_formatDate(nextChangeAt)}.';
  }

  Future<void> _showDisplayNameEditor() async {
    final nextChangeAt = _nextDisplayNameChangeAt;
    if (!_canUpdateDisplayName) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Modification limitee'),
            content: Text(
              'Le nom utilisateur ne peut etre modifie qu\'une fois tous les 3 mois. Vous pourrez le changer a nouveau a partir du ${_formatDate(nextChangeAt!)}.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Fermer'),
              ),
            ],
          );
        },
      );
      return;
    }

    final controller = TextEditingController(text: _displayName);
    final nextChangeHint = _displayNameChangedAt == null
        ? 'Apres cette modification, vous devrez attendre 3 mois avant de pouvoir rechanger ce nom.'
        : 'Le prochain changement sera disponible 3 mois apres cette modification.';

    final nextName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Modifier le nom'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                maxLength: 120,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nom utilisateur',
                  hintText: 'Entrez votre nouveau nom',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                nextChangeHint,
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (nextName == null || nextName.isEmpty || nextName == _displayName) {
      return;
    }

    await _updateDisplayName(nextName);
  }

  Future<void> _updateDisplayName(String displayName) async {
    if (_isUpdatingDisplayName) {
      return;
    }

    setState(() {
      _isUpdatingDisplayName = true;
    });

    try {
      final updatedProfile = await _authService.updateDisplayName(
        displayName: displayName,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _displayName =
            (updatedProfile['displayName'] as String?)?.trim().isNotEmpty == true
            ? (updatedProfile['displayName'] as String).trim()
            : _displayName;
        _displayNameChangedAt = _parseApiDateTime(
          updatedProfile['displayNameChangedAt'],
        );
        _nextDisplayNameChangeAt = _parseApiDateTime(
          updatedProfile['nextDisplayNameChangeAt'],
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _nextDisplayNameChangeAt == null
                ? 'Nom utilisateur mis a jour.'
                : 'Nom utilisateur mis a jour. Prochain changement possible le ${_formatDate(_nextDisplayNameChangeAt!)}.',
          ),
        ),
      );
    } on AppApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingDisplayName = false;
        });
      }
    }
  }

  Future<void> _loadCurrentLocation() async {
    if (kIsWeb) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _locationLabel = 'Localisation indisponible';
        });
      }
      return;
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _closeApplicationForLocationRefusal();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        await _closeApplicationForLocationRefusal();
        return;
      }

      final accuracyStatus = await Geolocator.getLocationAccuracy();
      final resolvedAccuracy = accuracyStatus == LocationAccuracyStatus.precise
          ? LocationAccuracy.best
          : LocationAccuracy.medium;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: resolvedAccuracy),
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      final placemark = placemarks.isNotEmpty ? placemarks.first : null;
      final parts =
          [
                placemark?.locality,
                placemark?.subAdministrativeArea,
                placemark?.administrativeArea,
                placemark?.country,
              ]
              .whereType<String>()
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList();

      final label = parts.isEmpty
          ? '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}'
          : parts.take(2).join(', ');

      if (!mounted) {
        return;
      }

      setState(() {
        _locationLabel = label;
        _isLoadingLocation = false;
      });

      await _persistCurrentLocation(
        locationLabel: label,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on PermissionDeniedException {
      await _closeApplicationForLocationRefusal();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _locationLabel ??= 'Localisation indisponible';
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _closeApplicationForLocationRefusal() async {
    if (kIsWeb) {
      return;
    }

    await SystemNavigator.pop();

    if (!Platform.isAndroid) {
      exit(0);
    }
  }

  Future<void> _persistCurrentLocation({
    required String locationLabel,
    required double latitude,
    required double longitude,
  }) async {
    if (_isSavingLocation) {
      return;
    }

    _isSavingLocation = true;
    try {
      final updatedProfile = await _authService.updateCurrentLocation(
        locationLabel: locationLabel,
        latitude: latitude,
        longitude: longitude,
      );

      if (!mounted) {
        return;
      }

      final persistedLocation =
          (updatedProfile['locationLabel'] as String?)?.trim() ?? locationLabel;
      setState(() {
        _locationLabel = persistedLocation;
      });
    } catch (_) {
      // Keep the local location label even if persistence fails.
    } finally {
      _isSavingLocation = false;
    }
  }

  Future<void> _pickProfileImage(
    _EditableImageTarget target,
    ImageSource source,
  ) async {
    final file = await _imagePicker.pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 1800,
    );
    if (file == null || !mounted) {
      return;
    }

    await _replaceProfileImage(target, File(file.path));
  }

  Future<void> _showImageSourceSheet(_EditableImageTarget target) async {
    if (!mounted || _isUploadingImage) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(
                  target == _EditableImageTarget.cover
                      ? 'Remplacer l\'image de fond'
                      : 'Remplacer l\'avatar',
                ),
                subtitle: const Text('Prendre une photo'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _pickProfileImage(target, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choisir dans la galerie'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _pickProfileImage(target, ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _replaceProfileImage(
    _EditableImageTarget target,
    File imageFile,
  ) async {
    setState(() {
      _isUploadingImage = true;
    });

    try {
      final imageUrl = target == _EditableImageTarget.cover
          ? await _authService.uploadCoverImage(imageFile: imageFile)
          : await _authService.uploadAvatarImage(imageFile: imageFile);

      if (!mounted) {
        return;
      }

      setState(() {
        if (target == _EditableImageTarget.cover) {
          _coverImageUrl = imageUrl;
        } else {
          _avatarUrl = imageUrl;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            target == _EditableImageTarget.cover
                ? 'Image de fond mise a jour.'
                : 'Avatar mis a jour.',
          ),
        ),
      );
    } on AppApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  Future<void> _submitShopRequest() async {
    if (_isSubmittingShopRequest || _userRole == 'SELLER') {
      return;
    }

    final dialogTheme = Theme.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Transformer en boutique'),
          content: const Text(
            'Envoyer une demande pour que l\'administrateur valide la creation de votre boutique ?',
          ),
          actions: [
            DynamicIconButton(
              text: 'Annuler',
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              expanded: false,
              backgroundColor: dialogTheme.colorScheme.surfaceContainerHighest,
              foregroundColor: dialogTheme.colorScheme.onSurface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              borderRadius: 18,
            ),
            DynamicIconButton(
              text: 'Envoyer',
              icon: const Icon(Icons.verified_outlined, size: 18),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              expanded: false,
              backgroundColor: dialogTheme.colorScheme.primary,
              foregroundColor: dialogTheme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              borderRadius: 18,
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isSubmittingShopRequest = true;
    });

    try {
      final updatedProfile = await _authService.submitShopRequest();

      if (!mounted) {
        return;
      }

      setState(() {
        _userRole = (updatedProfile['role'] as String?)?.trim() ?? _userRole;
        _shopRequestStatus =
            (updatedProfile['shopRequestStatus'] as String?)?.trim() ??
            'PENDING';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Demande envoyee. Un administrateur doit valider votre boutique.',
          ),
        ),
      );
    } on AppApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingShopRequest = false;
        });
      }
    }
  }

  Widget _buildShopRequestCard(ThemeData theme) {
    final appColors = theme.appColors;
    final isSeller = _userRole == 'SELLER';
    final isPending = _shopRequestStatus == 'PENDING';
    final isApproved = _shopRequestStatus == 'APPROVED';
    final isRejected = _shopRequestStatus == 'REJECTED';

    final title = isSeller
        ? 'Boutique active'
        : isPending
        ? 'Validation en attente'
        : isApproved
        ? 'Validation accordee'
        : isRejected
        ? 'Demande a renvoyer'
        : 'Transforme en boutique';

    final description = isSeller
        ? 'Votre compte est deja configure comme boutique.'
        : isPending
        ? 'La demande a ete envoyee. L\'administrateur doit maintenant verifier votre profil.'
        : isApproved
        ? 'La demande a ete approuvee. L\'activation finale par la plateforme est en cours.'
        : isRejected
        ? 'La plateforme a refuse la precedente demande. Vous pouvez en envoyer une nouvelle.'
        : 'Envoyez une demande pour que l\'administrateur verifie et valide la creation de votre boutique.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.72),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.storefront_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: appColors.mutedText,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: DynamicIconButton(
                text: isSeller
                    ? 'Boutique active'
                    : isPending
                    ? 'En attente de validation'
                    : isApproved
                    ? 'Validation accordee'
                    : isRejected
                    ? 'Renvoyer la demande'
                    : 'Demander la creation de boutique',
                icon: _isSubmittingShopRequest
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.1,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : Icon(
                        isRejected
                            ? Icons.refresh_rounded
                            : Icons.verified_outlined,
                        size: 18,
                      ),
                onPressed:
                    (isSeller ||
                        isPending ||
                        isApproved ||
                        _isLoading ||
                        _isSubmittingShopRequest)
                    ? null
                    : _submitShopRequest,
                backgroundColor:
                    (isSeller || isPending || isApproved || _isLoading)
                    ? theme.colorScheme.primary.withValues(alpha: 0.72)
                    : theme.colorScheme.primary,
                foregroundColor: Colors.white,
                borderRadius: 18,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageActionButton({
    required VoidCallback onPressed,
    required ThemeData theme,
  }) {
    final appColors = theme.appColors;

    return SizedBox(
      width: 38,
      height: 38,
      child: DynamicIconButton(
        text: '',
        icon: _isUploadingImage
            ? Padding(
                padding: const EdgeInsets.all(10),
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: theme.colorScheme.primary,
                ),
              )
            : Icon(
                Icons.photo_camera_rounded,
                size: 19,
                color: appColors.heroForeground,
              ),
        onPressed: _isUploadingImage ? null : onPressed,
        expanded: false,
        spacing: 0,
        padding: EdgeInsets.zero,
        borderRadius: 19,
        backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.9),
        foregroundColor: appColors.heroForeground,
      ),
    );
  }

  void _openImageViewer({required String imageUrl, required String heroTag}) {
    final normalizedUrl = imageUrl.trim();
    if (normalizedUrl.isEmpty) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImageViewerPage(
          imageUrls: [normalizedUrl],
          heroTag: heroTag,
          overlay: ImageViewerOverlayData(
            sellerName: _displayName,
            sellerUserId: _currentUserId,
            sellerAvatarUrl: _avatarUrl,
            isUserProfileImage: true,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final titleColor = theme.colorScheme.onSurface;
    final subtitleColor = appColors.mutedText;

    return Scaffold(
      backgroundColor: appColors.backgroundBase,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProfile,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(32),
                    ),
                    border: Border.all(color: appColors.inputBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 238,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _openImageViewer(
                                imageUrl: _coverImageUrl,
                                heroTag: 'main-simple-user-cover',
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.zero,
                                child: SizedBox(
                                  height: 190,
                                  width: double.infinity,
                                  child: Hero(
                                    tag: 'main-simple-user-cover',
                                    child: _coverImageUrl.isNotEmpty
                                        ? AppNetworkImage(
                                            imageUrl: _coverImageUrl,
                                            fit: BoxFit.cover,
                                            errorChild: Container(
                                              color: const Color(0xFF9E9E9E),
                                              alignment: Alignment.center,
                                              child: const Icon(
                                                Icons.person,
                                                color: Colors.white,
                                                size: 44,
                                              ),
                                            ),
                                          )
                                        : Container(
                                            color: const Color(0xFF9E9E9E),
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons.person,
                                              color: Colors.white,
                                              size: 74,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: 190,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.zero,
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.08),
                                        Colors.black.withValues(alpha: 0.28),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 16,
                              right: 16,
                              child: _buildImageActionButton(
                                onPressed: () {
                                  _showImageSourceSheet(
                                    _EditableImageTarget.cover,
                                  );
                                },
                                theme: theme,
                              ),
                            ),
                            Positioned(
                              left: 24,
                              bottom: 0,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _openImageViewer(
                                      imageUrl: _avatarUrl,
                                      heroTag: 'main-simple-user-avatar',
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: theme.cardColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: appColors.inputBorder,
                                        ),
                                      ),
                                      child: Hero(
                                        tag: 'main-simple-user-avatar',
                                        child: _avatarUrl.isNotEmpty
                                            ? AppCircleNetworkAvatar(
                                                imageUrl: _avatarUrl,
                                                radius: 44,
                                                userId: _currentUserId,
                                              )
                                            : Container(
                                                width: 88,
                                                height: 88,
                                                decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Color(0xFF9E9E9E),
                                                ),
                                                child: const Icon(
                                                  Icons.person_rounded,
                                                  color: Colors.white,
                                                  size: 52,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 4,
                                    bottom: 4,
                                    child: _buildImageActionButton(
                                      onPressed: () {
                                        _showImageSourceSheet(
                                          _EditableImageTarget.avatar,
                                        );
                                      },
                                      theme: theme,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isLoading)
                              Text(
                                'Chargement du profil...',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: subtitleColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            else if (_isUploadingImage)
                              Text(
                                'Mise a jour de l\'image...',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: subtitleColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            else ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _displayName,
                                      style: theme.textTheme.headlineSmall?.copyWith(
                                        color: titleColor,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  TextButton.icon(
                                    onPressed: _isUpdatingDisplayName
                                        ? null
                                        : _showDisplayNameEditor,
                                    icon: _isUpdatingDisplayName
                                        ? SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: theme.colorScheme.primary,
                                            ),
                                          )
                                        : const Icon(Icons.edit_outlined, size: 18),
                                    label: Text(
                                      _canUpdateDisplayName
                                          ? 'Modifier'
                                          : 'Voir la regle',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 16,
                                    color: subtitleColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      _isLoadingLocation
                                          ? 'Localisation en cours...'
                                          : (_locationLabel ??
                                                'Localisation indisponible'),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: subtitleColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _displayNamePolicyLabel,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: subtitleColor,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                            ],
                            if (_profileLoadError != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                _profileLoadError!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _buildShopRequestCard(theme),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
