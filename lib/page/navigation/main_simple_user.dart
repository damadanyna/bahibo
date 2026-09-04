import 'dart:async';
import 'dart:io';

import 'package:banay/component/app_network_image.dart';
import 'package:banay/component/profile_models.dart';
import 'package:banay/component/seller_profile_page.dart';
import 'package:banay/component/ui/dinamic_followed_people_h_list.dart';
import 'package:banay/component/ui/dinamic_icon_button.dart';
import 'package:banay/component/user_profile_page.dart';
import 'package:banay/localization/banay_localizations.dart';
import 'package:banay/page/image_viewer_page.dart';
import 'package:banay/page/qa_event_log_page.dart';
import 'package:banay/services/app_api_client.dart';
import 'package:banay/services/app_auth_service.dart';
import 'package:banay/services/catalog_api_service.dart';
import 'package:banay/services/chat_realtime_service.dart';
import 'package:banay/theme/app_theme_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

enum _EditableImageTarget { cover, avatar }

enum _LocationAccessBlocker {
  servicesDisabled,
  permissionDenied,
  permissionDeniedForever,
  preciseLocationRequired,
}

enum _SimpleUserTab { following, location, about }

const List<(String, double, double)> _madagascarCities = [
  ('Antananarivo', -18.9137, 47.5361),
  ('Toamasina', -18.1492, 49.4023),
  ('Antsirabe', -19.8659, 47.0337),
  ('Fianarantsoa', -21.4527, 47.0863),
  ('Mahajanga', -15.7162, 46.3200),
  ('Toliara', -23.3533, 43.6830),
  ('Antsiranana', -12.3520, 49.2968),
];

class MainSimpleUser extends StatefulWidget {
  const MainSimpleUser({super.key});

  @override
  State<MainSimpleUser> createState() => _MainSimpleUserState();
}

class _MainSimpleUserState extends State<MainSimpleUser> {
  final AppAuthService _authService = AppAuthService();
  final CatalogApiService _catalogApiService = CatalogApiService();
  final ImagePicker _imagePicker = ImagePicker();
  StreamSubscription<Map<String, dynamic>>? _realtimeEventsSubscription;

  bool _isLoading = true;
  bool _isUploadingAvatarImage = false;
  bool _isUploadingCoverImage = false;
  bool _isUpdatingDisplayName = false;
  bool _isSubmittingShopRequest = false;
  bool _isLoadingLocation = true;
  bool _isSavingLocation = false;
  bool _isLoadingFollowedPeople = true;
  _LocationAccessBlocker? _locationAccessBlocker;
  _SimpleUserTab _selectedTab = _SimpleUserTab.following;
  String? _profileLoadError;
  String? _locationLabel;
  DateTime? _displayNameChangedAt;
  DateTime? _nextDisplayNameChangeAt;
  String _displayName = '';
  String _avatarUrl = '';
  String _coverImageUrl = '';
  String? _currentUserId;
  String _userRole = 'CUSTOMER';
  String _shopRequestStatus = 'NONE';
  List<Map<String, dynamic>> _followedPeople = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadCurrentLocation();
    _loadFollowedPeople();
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
      final displayNameChangedAt = _parseApiDateTime(
        user['displayNameChangedAt'],
      );
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

  Future<void> _loadFollowedPeople() async {
    try {
      final followedPeople = await _catalogApiService
          .fetchCurrentUserFollowing();
      if (!mounted) return;
      followedPeople.sort(
        (a, b) => _personFollowingScore(b).compareTo(_personFollowingScore(a)),
      );
      setState(() {
        _followedPeople = followedPeople;
        _isLoadingFollowedPeople = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingFollowedPeople = false);
    }
  }

  bool _resolvePersonCertified(Map<String, dynamic> person) {
    final candidates = <Object?>[
      person['isCertified'],
      person['isSellerCertified'],
      person['isVerified'],
      person['sellerCertified'],
    ];
    for (final c in candidates) {
      if (c is bool && c) return true;
      final s = c?.toString().trim().toLowerCase() ?? '';
      if (s == 'true' || s == '1' || s == 'yes') return true;
    }
    return false;
  }

  int _resolvePersonUnreadCount(Map<String, dynamic> person) {
    final candidates = <Object?>[
      person['unreadCount'],
      person['unreadNotifications'],
      person['newPublicationsCount'],
    ];
    for (final c in candidates) {
      if (c is int && c > 0) return c;
      final n = int.tryParse(c?.toString().trim() ?? '');
      if (n != null && n > 0) return n;
    }
    return 0;
  }

  int _resolvePersonProductCount(Map<String, dynamic> person) {
    final candidates = <Object?>[
      person['productCount'],
      person['publicationCount'],
      person['productsCount'],
    ];
    for (final c in candidates) {
      if (c is int && c >= 0) return c;
      final n = int.tryParse(c?.toString().trim() ?? '');
      if (n != null && n >= 0) return n;
    }
    return 0;
  }

  int _personFollowingScore(Map<String, dynamic> person) {
    return (_resolvePersonCertified(person) ? 1000 : 0) +
        (_resolvePersonUnreadCount(person) * 10) +
        _resolvePersonProductCount(person).clamp(0, 9);
  }

  Future<void> _onRefresh() async {
    await Future.wait([_loadProfile(), _loadFollowedPeople()]);
  }

  Future<void> _openFollowedPerson(Map<String, dynamic> person) async {
    final role = person['role']?.toString().trim().toUpperCase() ?? '';
    final sellerProfileId = person['sellerProfileId']?.toString().trim() ?? '';
    final userId =
        person['userId']?.toString().trim() ??
        person['id']?.toString().trim() ??
        '';

    if (role == 'SELLER' && sellerProfileId.isNotEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FutureBuilder<Map<String, dynamic>>(
            future: _catalogApiService.fetchSellerProfile(sellerProfileId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Scaffold(
                  backgroundColor: Theme.of(context).appColors.backgroundBase,
                  body: const Center(child: CircularProgressIndicator()),
                );
              }
              return SellerProfilePage(
                profile: buildSellerProfileFromApi(snapshot.data!),
              );
            },
          ),
        ),
      );
      return;
    }

    if (userId.isEmpty) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FutureBuilder<Map<String, dynamic>>(
          future: _catalogApiService.fetchUserProfile(userId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Scaffold(
                backgroundColor: Theme.of(context).appColors.backgroundBase,
                body: const Center(child: CircularProgressIndicator()),
              );
            }
            return UserProfilePage(
              profile: buildPublicUserProfileFromApi(snapshot.data!),
            );
          },
        ),
      ),
    );
  }

  void _bindRealtimeProfileUpdates() {
    ChatRealtimeService.instance.ensureConnected();
    _realtimeEventsSubscription?.cancel();
    _realtimeEventsSubscription = ChatRealtimeService.instance.events.listen((
      event,
    ) {
      if (event['type'] != 'profile:shop-request-updated' &&
          event['type'] != 'profile:updated') {
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

  int? get _displayNameCooldownDaysRemaining {
    final nextChangeAt = _nextDisplayNameChangeAt;
    if (nextChangeAt == null) {
      return null;
    }

    final remainingMilliseconds =
        nextChangeAt.millisecondsSinceEpoch -
        DateTime.now().millisecondsSinceEpoch;
    if (remainingMilliseconds <= 0) {
      return 0;
    }

    return (remainingMilliseconds / Duration.millisecondsPerDay).ceil();
  }

  String _formatRemainingDaysLabel(int remainingDays) {
    return remainingDays > 1
        ? context.tr(
            BanayLocalizationKeys.accountDaysRemainingMany,
            params: {'days': '$remainingDays'},
          )
        : context.tr(BanayLocalizationKeys.accountDayRemainingOne);
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day/$month/$year';
  }

  String get _resolvedDisplayName => _displayName.trim().isNotEmpty
      ? _displayName
      : context.tr(BanayLocalizationKeys.accountDefaultDisplayName);

  Future<void> _showDisplayNameEditor() async {
    final nextChangeAt = _nextDisplayNameChangeAt;
    if (!_canUpdateDisplayName) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(
              dialogContext.tr(
                BanayLocalizationKeys.accountDisplayNameEditBlockedTitle,
              ),
            ),
            content: Text(
              dialogContext.tr(
                BanayLocalizationKeys.accountDisplayNameEditBlockedBody,
                params: {
                  'remainingDays': _formatRemainingDaysLabel(
                    _displayNameCooldownDaysRemaining ?? 0,
                  ),
                  'nextDate': _formatDate(nextChangeAt!),
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  dialogContext.tr(BanayLocalizationKeys.accountCloseAction),
                ),
              ),
            ],
          );
        },
      );
      return;
    }

    final controller = TextEditingController(text: _displayName);
    final nextChangeHint = _displayNameChangedAt == null
        ? context.tr(
            BanayLocalizationKeys.accountDisplayNameNextChangeHintFirst,
          )
        : context.tr(
            BanayLocalizationKeys.accountDisplayNameNextChangeHintAfter,
          );

    final nextName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            dialogContext.tr(BanayLocalizationKeys.accountDisplayNameEditTitle),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                maxLength: 120,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: dialogContext.tr(
                    BanayLocalizationKeys.accountDisplayNameFieldLabel,
                  ),
                  hintText: dialogContext.tr(
                    BanayLocalizationKeys.accountDisplayNameFieldHint,
                  ),
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
              child: Text(
                dialogContext.tr(BanayLocalizationKeys.accountCancelAction),
              ),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: Text(
                dialogContext.tr(BanayLocalizationKeys.accountSaveAction),
              ),
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

  Future<void> _openQaEventLogPage() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const QaEventLogPage()));
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
            (updatedProfile['displayName'] as String?)?.trim().isNotEmpty ==
                true
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
                ? context.tr(BanayLocalizationKeys.accountDisplayNameUpdated)
                : context.tr(
                    BanayLocalizationKeys.accountDisplayNameUpdatedCooldown,
                    params: {
                      'remainingDays': _formatRemainingDaysLabel(
                        _displayNameCooldownDaysRemaining ?? 7,
                      ),
                      'nextDate': _formatDate(_nextDisplayNameChangeAt!),
                    },
                  ),
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
          _locationAccessBlocker = null;
          _isLoadingLocation = false;
          _locationLabel = context.tr(
            BanayLocalizationKeys.accountLocationUnavailable,
          );
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingLocation = true;
        _locationAccessBlocker = null;
      });
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationAccessBlocker(_LocationAccessBlocker.servicesDisabled);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showLocationAccessBlocker(
          permission == LocationPermission.deniedForever
              ? _LocationAccessBlocker.permissionDeniedForever
              : _LocationAccessBlocker.permissionDenied,
        );
        return;
      }

      final hasPreciseLocation = await _ensurePreciseLocationAccess();
      if (!hasPreciseLocation) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
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

      final geocodedLabel = parts.isEmpty
          ? '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}'
          : parts.take(2).join(', ');
      final label =
          _nearestMadagascarCity(position.latitude, position.longitude) ??
          geocodedLabel;

      if (!mounted) {
        return;
      }

      setState(() {
        _locationAccessBlocker = null;
        _locationLabel = label;
        _isLoadingLocation = false;
      });

      await _persistCurrentLocation(
        locationLabel: label,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on PermissionDeniedException {
      final permission = await Geolocator.checkPermission();
      _showLocationAccessBlocker(
        permission == LocationPermission.deniedForever
            ? _LocationAccessBlocker.permissionDeniedForever
            : _LocationAccessBlocker.permissionDenied,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _locationAccessBlocker = null;
        _locationLabel ??= context.tr(
          BanayLocalizationKeys.accountLocationUnavailable,
        );
        _isLoadingLocation = false;
      });
    }
  }

  void _showLocationAccessBlocker(_LocationAccessBlocker blocker) {
    if (!mounted) {
      return;
    }

    setState(() {
      _locationAccessBlocker = blocker;
      _isLoadingLocation = false;
    });
  }

  Future<bool> _ensurePreciseLocationAccess() async {
    final accuracyStatus = await Geolocator.getLocationAccuracy();
    if (accuracyStatus == LocationAccuracyStatus.precise) {
      return true;
    }

    _showLocationAccessBlocker(_LocationAccessBlocker.preciseLocationRequired);
    return false;
  }

  Future<void> _openLocationSettingsAndRetry() async {
    await Geolocator.openLocationSettings();
    await _loadCurrentLocation();
  }

  Future<void> _openAppSettingsAndRetry() async {
    await Geolocator.openAppSettings();
    await _loadCurrentLocation();
  }

  Future<void> _selectCity(
    String cityName,
    double latitude,
    double longitude,
  ) async {
    if (_isSavingLocation) return;
    setState(() {
      _locationLabel = cityName;
      _locationAccessBlocker = null;
      _isLoadingLocation = false;
    });
    await _persistCurrentLocation(
      locationLabel: cityName,
      latitude: latitude,
      longitude: longitude,
      isManualSelection: true,
    );
  }

  String? _nearestMadagascarCity(double latitude, double longitude) {
    String? nearest;
    double nearestDistance = double.infinity;

    for (final city in _madagascarCities) {
      final distance = Geolocator.distanceBetween(
        latitude,
        longitude,
        city.$2,
        city.$3,
      );
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = city.$1;
      }
    }

    return nearestDistance <= 100000 ? nearest : null;
  }

  Future<void> _persistCurrentLocation({
    required String locationLabel,
    required double latitude,
    required double longitude,
    bool isManualSelection = false,
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
        isManualSelection: isManualSelection,
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
    if (!mounted || _isUploadingAvatarImage || _isUploadingCoverImage) {
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
                      ? sheetContext.tr(
                          BanayLocalizationKeys.accountReplaceCoverImage,
                        )
                      : sheetContext.tr(
                          BanayLocalizationKeys.accountReplaceAvatar,
                        ),
                ),
                subtitle: Text(
                  sheetContext.tr(BanayLocalizationKeys.accountTakePhoto),
                ),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _pickProfileImage(target, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(
                  sheetContext.tr(
                    BanayLocalizationKeys.accountChooseFromGallery,
                  ),
                ),
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
      if (target == _EditableImageTarget.cover) {
        _isUploadingCoverImage = true;
      } else {
        _isUploadingAvatarImage = true;
      }
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
                ? context.tr(BanayLocalizationKeys.accountCoverImageUpdated)
                : context.tr(BanayLocalizationKeys.accountAvatarUpdated),
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
          if (target == _EditableImageTarget.cover) {
            _isUploadingCoverImage = false;
          } else {
            _isUploadingAvatarImage = false;
          }
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
          title: Text(
            dialogContext.tr(BanayLocalizationKeys.accountShopConfirmTitle),
          ),
          content: Text(
            dialogContext.tr(BanayLocalizationKeys.accountShopConfirmBody),
          ),
          actions: [
            DynamicIconButton(
              text: dialogContext.tr(BanayLocalizationKeys.accountCancelAction),
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              expanded: false,
              backgroundColor: dialogTheme.colorScheme.surfaceContainerHighest,
              foregroundColor: dialogTheme.colorScheme.onSurface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              borderRadius: 18,
            ),
            DynamicIconButton(
              text: dialogContext.tr(BanayLocalizationKeys.accountSendAction),
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
        SnackBar(
          content: Text(
            context.tr(BanayLocalizationKeys.accountShopRequestSent),
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
        ? context.tr(BanayLocalizationKeys.accountShopStatusActiveTitle)
        : isPending
        ? context.tr(BanayLocalizationKeys.accountShopStatusPendingTitle)
        : isApproved
        ? context.tr(BanayLocalizationKeys.accountShopStatusApprovedTitle)
        : isRejected
        ? context.tr(BanayLocalizationKeys.accountShopStatusRejectedTitle)
        : context.tr(BanayLocalizationKeys.accountShopStatusDefaultTitle);

    final description = isSeller
        ? context.tr(BanayLocalizationKeys.accountShopStatusActiveDescription)
        : isPending
        ? context.tr(BanayLocalizationKeys.accountShopStatusPendingDescription)
        : isApproved
        ? context.tr(BanayLocalizationKeys.accountShopStatusApprovedDescription)
        : isRejected
        ? context.tr(BanayLocalizationKeys.accountShopStatusRejectedDescription)
        : context.tr(BanayLocalizationKeys.accountShopStatusDefaultDescription);

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
                    ? context.tr(BanayLocalizationKeys.accountShopButtonActive)
                    : isPending
                    ? context.tr(BanayLocalizationKeys.accountShopButtonPending)
                    : isApproved
                    ? context.tr(
                        BanayLocalizationKeys.accountShopButtonApproved,
                      )
                    : isRejected
                    ? context.tr(
                        BanayLocalizationKeys.accountShopButtonRejected,
                      )
                    : context.tr(
                        BanayLocalizationKeys.accountShopButtonDefault,
                      ),
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
    required bool isUploading,
  }) {
    final appColors = theme.appColors;

    return SizedBox(
      width: 38,
      height: 38,
      child: DynamicIconButton(
        text: '',
        icon: isUploading
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
        onPressed: isUploading ? null : onPressed,
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
            sellerName: _resolvedDisplayName,
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
          onRefresh: _onRefresh,
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
                                              color: appColors.placeholderFill,
                                              alignment: Alignment.center,
                                              child: Icon(
                                                Icons.person,
                                                color:
                                                    appColors.placeholderIcon,
                                                size: 44,
                                              ),
                                            ),
                                          )
                                        : Container(
                                            color: appColors.placeholderFill,
                                            alignment: Alignment.center,
                                            child: Icon(
                                              Icons.person,
                                              color: appColors.placeholderIcon,
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
                                        appColors.scrimSoft.withValues(
                                          alpha: 0.18,
                                        ),
                                        appColors.scrimStrong.withValues(
                                          alpha: 0.26,
                                        ),
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
                                isUploading: _isUploadingCoverImage,
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
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color:
                                                      appColors.placeholderFill,
                                                ),
                                                child: Icon(
                                                  Icons.person_rounded,
                                                  color:
                                                      appColors.placeholderIcon,
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
                                      isUploading: _isUploadingAvatarImage,
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
                                context.tr(
                                  BanayLocalizationKeys.accountProfileLoading,
                                ),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: subtitleColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            else if (_isUploadingAvatarImage ||
                                _isUploadingCoverImage)
                              Text(
                                context.tr(
                                  BanayLocalizationKeys.accountImageUpdating,
                                ),
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
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onLongPress: _openQaEventLogPage,
                                      child: Text(
                                        _resolvedDisplayName,
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                              color: titleColor,
                                              fontWeight: FontWeight.w900,
                                            ),
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
                                        : const Icon(
                                            Icons.edit_outlined,
                                            size: 18,
                                          ),
                                    label: Text(
                                      _canUpdateDisplayName
                                          ? context.tr(
                                              BanayLocalizationKeys
                                                  .accountEditAction,
                                            )
                                          : context.tr(
                                              BanayLocalizationKeys
                                                  .accountViewRuleAction,
                                            ),
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
                                          ? context.tr(
                                              BanayLocalizationKeys
                                                  .accountLocationLoading,
                                            )
                                          : (_locationLabel ??
                                                context.tr(
                                                  BanayLocalizationKeys
                                                      .accountLocationUnavailable,
                                                )),
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildTabNavigation(theme, appColors),
              const SizedBox(height: 8),
              _buildTabContent(theme, appColors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabNavigation(ThemeData theme, dynamic appColors) {
    final accentColor = theme.colorScheme.primary;
    final mutedColor = theme.appColors.mutedText;

    final tabs = [
      (_SimpleUserTab.following, 'Abonnements', Icons.groups_rounded),
      (_SimpleUserTab.location, 'Localisation', Icons.location_on_rounded),
      (_SimpleUserTab.about, 'A propos', Icons.info_outline_rounded),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: tabs.map((tab) {
          final isSelected = _selectedTab == tab.$1;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => setState(() => _selectedTab = tab.$1),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accentColor.withValues(alpha: 0.10)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(
                              color: accentColor.withValues(alpha: 0.22),
                            )
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            tab.$3,
                            key: ValueKey(isSelected),
                            size: 20,
                            color: isSelected ? accentColor : mutedColor,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          tab.$2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? accentColor : mutedColor,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w500,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabContent(ThemeData theme, dynamic appColors) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: KeyedSubtree(
        key: ValueKey<_SimpleUserTab>(_selectedTab),
        child: switch (_selectedTab) {
          _SimpleUserTab.following => _buildFollowingTab(theme),
          _SimpleUserTab.location => _buildLocationTab(theme),
          _SimpleUserTab.about => _buildShopRequestCard(theme),
        },
      ),
    );
  }

  Widget _buildFollowingTab(ThemeData theme) {
    final appColors = theme.appColors;

    if (_isLoadingFollowedPeople) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_followedPeople.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: appColors.borderColor),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.people_outline_rounded,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Aucun abonnement',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Abonnez-vous a des vendeurs pour les retrouver ici.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: appColors.mutedText,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: _followedPeople.map((person) {
          final name = resolveFollowedPersonName(
            person,
            fallbackName: 'Membre BANAY',
          );
          final avatarUrl = resolveFollowedPersonAvatarUrl(person);
          final userId = resolveFollowedPersonUserId(person);
          final role = person['role']?.toString().trim().toUpperCase() ?? '';
          final isSeller = role == 'SELLER';
          final subtitle = resolveFollowedPersonSubtitle(
            person,
            fallbackSubtitle: 'Membre BANAY',
          );
          final isCertified = _resolvePersonCertified(person);
          final unreadCount = _resolvePersonUnreadCount(person);
          final productCount = _resolvePersonProductCount(person);

          final badgeLabel = productCount > 0
              ? '$productCount pub.'
              : (isSeller ? 'Vendeur' : 'Membre');

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () => _openFollowedPerson(person),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 64),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCertified
                          ? theme.colorScheme.primary.withValues(alpha: 0.30)
                          : appColors.borderColor,
                      width: isCertified ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AppCircleNetworkAvatar(
                            imageUrl: avatarUrl,
                            radius: 24,
                            userId: userId,
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              right: -1,
                              top: -1,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE53935),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: theme.cardColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                if (isCertified) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.verified_rounded,
                                    size: 14,
                                    color: theme.colorScheme.primary,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: appColors.mutedText,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (unreadCount > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE53935),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '$unreadCount non lu${unreadCount > 1 ? 'es' : 'e'}',
                                    style: const TextStyle(
                                      color: Color(0xFFE53935),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isSeller
                              ? theme.colorScheme.primary.withValues(
                                  alpha: 0.10,
                                )
                              : appColors.panelMuted,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSeller
                                ? theme.colorScheme.primary
                                : appColors.mutedText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLocationTab(ThemeData theme) {
    final appColors = theme.appColors;
    final colorScheme = theme.colorScheme;
    final locationAccessBlocker = _locationAccessBlocker;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: appColors.borderColor),
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
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.location_on_rounded,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ma localisation',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (locationAccessBlocker != null)
              _buildInlineLocationBlocker(theme, locationAccessBlocker)
            else if (_isLoadingLocation)
              Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    context.tr(BanayLocalizationKeys.accountLocationLoading),
                    style: TextStyle(
                      color: appColors.mutedText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 16,
                    color: appColors.mutedText,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _locationLabel ??
                          context.tr(
                            BanayLocalizationKeys.accountLocationUnavailable,
                          ),
                      style: TextStyle(
                        color: appColors.mutedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: DynamicIconButton(
                text: _isLoadingLocation
                    ? context.tr(BanayLocalizationKeys.accountLocationLoading)
                    : context.tr(BanayLocalizationKeys.accountRetryAction),
                icon: _isLoadingLocation
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.1,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.my_location_rounded, size: 18),
                onPressed: _isLoadingLocation ? null : _loadCurrentLocation,
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                borderRadius: 18,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Text(
              'Ou sélectionnez une ville',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: appColors.mutedText,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _madagascarCities.map((city) {
                final isSelected = _locationLabel == city.$1;
                return GestureDetector(
                  onTap: () => _selectCity(city.$1, city.$2, city.$3),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.primary.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Text(
                      city.$1,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? colorScheme.onPrimary
                            : colorScheme.primary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineLocationBlocker(
    ThemeData theme,
    _LocationAccessBlocker blocker,
  ) {
    final colorScheme = theme.colorScheme;
    final appColors = theme.appColors;

    final icon = switch (blocker) {
      _LocationAccessBlocker.servicesDisabled => Icons.location_off_outlined,
      _LocationAccessBlocker.permissionDenied =>
        Icons.location_searching_outlined,
      _LocationAccessBlocker.permissionDeniedForever =>
        Icons.app_settings_alt_outlined,
      _LocationAccessBlocker.preciseLocationRequired =>
        Icons.my_location_outlined,
    };

    final title = switch (blocker) {
      _LocationAccessBlocker.servicesDisabled => context.tr(
        BanayLocalizationKeys.accountLocationServicesDisabledTitle,
      ),
      _LocationAccessBlocker.permissionDenied => context.tr(
        BanayLocalizationKeys.accountLocationPermissionDeniedTitle,
      ),
      _LocationAccessBlocker.permissionDeniedForever => context.tr(
        BanayLocalizationKeys.accountLocationPermissionRequiredTitle,
      ),
      _LocationAccessBlocker.preciseLocationRequired => context.tr(
        BanayLocalizationKeys.accountLocationPreciseRequiredTitle,
      ),
    };

    final message = switch (blocker) {
      _LocationAccessBlocker.servicesDisabled => context.tr(
        BanayLocalizationKeys.accountLocationServicesDisabledMessage,
      ),
      _LocationAccessBlocker.permissionDenied => context.tr(
        BanayLocalizationKeys.accountLocationPermissionDeniedMessage,
      ),
      _LocationAccessBlocker.permissionDeniedForever => context.tr(
        BanayLocalizationKeys.accountLocationPermissionDeniedForeverMessage,
      ),
      _LocationAccessBlocker.preciseLocationRequired => context.tr(
        BanayLocalizationKeys.accountLocationPreciseRequiredMessage,
      ),
    };

    final primaryLabel = switch (blocker) {
      _LocationAccessBlocker.servicesDisabled => context.tr(
        BanayLocalizationKeys.accountOpenLocationSettings,
      ),
      _LocationAccessBlocker.permissionDenied => context.tr(
        BanayLocalizationKeys.accountAllowNow,
      ),
      _LocationAccessBlocker.permissionDeniedForever => context.tr(
        BanayLocalizationKeys.accountOpenAppSettings,
      ),
      _LocationAccessBlocker.preciseLocationRequired => context.tr(
        BanayLocalizationKeys.accountOpenAppSettings,
      ),
    };

    final primaryAction = switch (blocker) {
      _LocationAccessBlocker.servicesDisabled => _openLocationSettingsAndRetry,
      _LocationAccessBlocker.permissionDenied => _loadCurrentLocation,
      _LocationAccessBlocker.permissionDeniedForever =>
        _openAppSettingsAndRetry,
      _LocationAccessBlocker.preciseLocationRequired =>
        _openAppSettingsAndRetry,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: colorScheme.error, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: TextStyle(
            color: appColors.mutedText,
            fontWeight: FontWeight.w500,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: DynamicIconButton(
            text: primaryLabel,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            onPressed: primaryAction,
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            borderRadius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
        ),
      ],
    );
  }
}
