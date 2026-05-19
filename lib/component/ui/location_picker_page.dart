import 'dart:async';
import 'dart:convert';

import 'package:banay/services/location_permission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as latlng;

const String _googlePlacesApiKey = String.fromEnvironment(
  'BANAY_GOOGLE_PLACES_API_KEY',
);
const bool _enableGoogleMaps = bool.fromEnvironment(
  'BANAY_ENABLE_GOOGLE_MAPS',
  defaultValue: false,
);
const double _targetGpsAccuracyMeters = 50;
const double _warningGpsAccuracyMeters = 120;

class UiLocationSelection {
  final String title;
  final String subtitle;
  final double latitude;
  final double longitude;
  final bool isCurrentLocation;
  final double? distanceMeters;

  const UiLocationSelection({
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
    this.isCurrentLocation = false,
    this.distanceMeters,
  });
}

class UiLocationPickerPage extends StatefulWidget {
  final Color primary;

  const UiLocationPickerPage({super.key, required this.primary});

  @override
  State<UiLocationPickerPage> createState() => _UiLocationPickerPageState();
}

class _UiLocationPickerPageState extends State<UiLocationPickerPage> {
  gmaps.GoogleMapController? _googleMapController;
  final MapController _osmMapController = MapController();

  bool _isLoading = true;
  bool _isRefreshingMap = false;
  String? _errorText;
  String? _mapNotice;
  Position? _devicePosition;
  double? _accuracyMeters;
  gmaps.LatLng? _mapCenter;
  gmaps.LatLng? _pendingCameraTarget;
  UiLocationSelection? _currentLocation;
  UiLocationSelection? _selectedLocation;
  List<UiLocationSelection> _nearbyLocations = const <UiLocationSelection>[];
  Timer? _mapRefreshDebounce;
  double _osmZoom = 17.2;
  int _refreshToken = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadLocations());
  }

  @override
  void dispose() {
    _mapRefreshDebounce?.cancel();
    _googleMapController?.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw const _UiLocationPickerException(
          'Activez la localisation pour choisir une position.',
        );
      }

      var permission = await LocationPermissionService.checkPermissionStatus();
      if (permission == LocationPermission.denied) {
        permission =
            await LocationPermissionService.requestPermissionAfterExplanation();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw _UiLocationPickerException(
          permission == LocationPermission.deniedForever
              ? 'L\'acces a la localisation est bloque dans les reglages.'
              : 'Autorisez la localisation pour choisir une position.',
        );
      }

      final position = await _acquireBestPosition();

      _devicePosition = position;
      _accuracyMeters = position.accuracy;
      final initialCenter = gmaps.LatLng(position.latitude, position.longitude);

      final currentLocation = await _resolveSelection(
        latitude: position.latitude,
        longitude: position.longitude,
        subtitleOverride: _accuracySubtitle(position.accuracy),
        isCurrentLocation: true,
      );

      final selectedLocation = await _resolveSelection(
        latitude: position.latitude,
        longitude: position.longitude,
        subtitleOverride: _selectedLocationSubtitle(
          position.accuracy,
          distanceMeters: 0,
        ),
      );

      final nearbyLocations = await _searchNearbySelections(initialCenter);
      if (!mounted) {
        return;
      }

      setState(() {
        _mapCenter = initialCenter;
        _currentLocation = currentLocation;
        _selectedLocation = selectedLocation;
        _nearbyLocations = nearbyLocations;
        _mapNotice = _buildMapNotice(position.accuracy);
        _isLoading = false;
      });
    } on _UiLocationPickerException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = 'Impossible de charger la localisation pour le moment.';
        _isLoading = false;
      });
    }
  }

  Future<UiLocationSelection> _resolveSelection({
    required double latitude,
    required double longitude,
    required String subtitleOverride,
    bool isCurrentLocation = false,
    double? distanceMeters,
  }) async {
    String title =
        '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
    String subtitle = subtitleOverride;

    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      final placemark = placemarks.isNotEmpty ? placemarks.first : null;
      final titleParts =
          [placemark?.name, placemark?.street, placemark?.locality]
              .whereType<String>()
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList();
      final subtitleParts =
          [
                placemark?.subAdministrativeArea,
                placemark?.administrativeArea,
                placemark?.country,
              ]
              .whereType<String>()
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList();

      if (titleParts.isNotEmpty) {
        title = titleParts.first;
      }
      if (subtitleParts.isNotEmpty) {
        final areaText = subtitleParts.take(2).join(', ');
        subtitle = isCurrentLocation
            ? subtitleOverride
            : [
                areaText,
                subtitleOverride,
              ].where((value) => value.trim().isNotEmpty).join(' • ');
      }
    } catch (_) {}

    return UiLocationSelection(
      title: title,
      subtitle: subtitle,
      latitude: latitude,
      longitude: longitude,
      isCurrentLocation: isCurrentLocation,
      distanceMeters: distanceMeters,
    );
  }

  String _accuracySubtitle(double accuracyMeters) {
    if (accuracyMeters <= _targetGpsAccuracyMeters) {
      return 'Precis a ${accuracyMeters.round()} m';
    }
    if (accuracyMeters <= _warningGpsAccuracyMeters) {
      return 'Precision moyenne ${accuracyMeters.round()} m';
    }
    return 'Precision faible ${accuracyMeters.round()} m';
  }

  String? _buildMapNotice(double accuracyMeters) {
    if (!_enableGoogleMaps) {
      return 'Carte de secours activee. Ajoutez GOOGLE_MAPS_API_KEY puis lancez avec --dart-define=BANAY_ENABLE_GOOGLE_MAPS=true pour Google Maps.';
    }
    if (accuracyMeters > _warningGpsAccuracyMeters) {
      return 'Le GPS est encore peu precis. Activez la localisation precise puis rafraichissez.';
    }
    return null;
  }

  Future<Position> _acquireBestPosition() async {
    Position? bestPosition;

    try {
      bestPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );
      if (bestPosition.accuracy <= _targetGpsAccuracyMeters) {
        return bestPosition;
      }
    } catch (_) {}

    final completer = Completer<Position>();
    late final StreamSubscription<Position> subscription;
    final timeout = Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted && bestPosition != null) {
        completer.complete(bestPosition!);
      }
    });

    subscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 0,
          ),
        ).listen(
          (position) {
            if (bestPosition == null ||
                position.accuracy < bestPosition!.accuracy) {
              bestPosition = position;
            }
            if (position.accuracy <= _targetGpsAccuracyMeters &&
                !completer.isCompleted) {
              completer.complete(position);
            }
          },
          onError: (_) {
            if (!completer.isCompleted && bestPosition != null) {
              completer.complete(bestPosition!);
            }
          },
        );

    try {
      final refinedPosition = await completer.future;
      return refinedPosition;
    } finally {
      timeout.cancel();
      await subscription.cancel();
    }
  }

  String _selectedLocationSubtitle(
    double? accuracyMeters, {
    required double distanceMeters,
  }) {
    final parts = <String>[];
    if (accuracyMeters != null && accuracyMeters > 0) {
      parts.add('Precision GPS ${accuracyMeters.round()} m');
    }
    parts.add(
      distanceMeters <= 1
          ? 'Position actuelle'
          : '${distanceMeters.round()} m du point GPS',
    );
    return parts.join(' • ');
  }

  Future<List<UiLocationSelection>> _searchNearbySelections(
    gmaps.LatLng center,
  ) async {
    if (_googlePlacesApiKey.isNotEmpty) {
      final googleResults = await _searchGooglePlaces(center);
      if (googleResults.isNotEmpty) {
        return googleResults;
      }
    }

    return _searchOverpassFallback(center);
  }

  Future<List<UiLocationSelection>> _searchGooglePlaces(
    gmaps.LatLng center,
  ) async {
    try {
      final queries = <Map<String, String>>[
        <String, String>{'type': 'pharmacy'},
        <String, String>{'type': 'gas_station'},
        <String, String>{'type': 'transit_station', 'keyword': 'bus stop'},
      ];
      final seenKeys = <String>{};
      final results = <UiLocationSelection>[];

      final responses = await Future.wait(
        queries.map((query) {
          final parameters = <String, String>{
            'location': '${center.latitude},${center.longitude}',
            'radius': '500',
            'language': 'fr',
            'key': _googlePlacesApiKey,
            ...query,
          };
          return http.get(
            Uri.https(
              'maps.googleapis.com',
              '/maps/api/place/nearbysearch/json',
              parameters,
            ),
          );
        }),
      );

      for (final response in responses) {
        if (response.statusCode < 200 || response.statusCode >= 300) {
          continue;
        }

        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          continue;
        }
        final places =
            decoded['results'] as List<dynamic>? ?? const <dynamic>[];
        for (final place in places) {
          if (place is! Map<String, dynamic>) {
            continue;
          }

          final geometry = place['geometry'];
          final location = geometry is Map<String, dynamic>
              ? geometry['location'] as Map<String, dynamic>?
              : null;
          final latValue = location?['lat'];
          final lngValue = location?['lng'];
          if (latValue is! num || lngValue is! num) {
            continue;
          }

          final latitude = latValue.toDouble();
          final longitude = lngValue.toDouble();
          final displayName = (place['name']?.toString() ?? '').trim();
          if (displayName.isEmpty) {
            continue;
          }

          final distanceMeters = Geolocator.distanceBetween(
            center.latitude,
            center.longitude,
            latitude,
            longitude,
          );
          final vicinity = (place['vicinity']?.toString() ?? '').trim();
          final types = (place['types'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(growable: false);
          final subtitle = [
            if (vicinity.isNotEmpty) vicinity,
            _googlePlaceDescriptor(types),
            '${distanceMeters.round()} m',
          ].where((value) => value.trim().isNotEmpty).join(' • ');

          final key =
              '${displayName.toLowerCase()}|${latitude.toStringAsFixed(5)}|${longitude.toStringAsFixed(5)}';
          if (!seenKeys.add(key)) {
            continue;
          }

          results.add(
            UiLocationSelection(
              title: displayName,
              subtitle: subtitle,
              latitude: latitude,
              longitude: longitude,
              distanceMeters: distanceMeters,
            ),
          );
        }
      }

      results.sort((left, right) {
        return (left.distanceMeters ?? double.infinity).compareTo(
          right.distanceMeters ?? double.infinity,
        );
      });
      return results.take(8).toList(growable: false);
    } catch (_) {
      return const <UiLocationSelection>[];
    }
  }

  String _googlePlaceDescriptor(List<String> types) {
    if (types.contains('pharmacy')) {
      return 'pharmacie';
    }
    if (types.contains('gas_station')) {
      return 'station-service';
    }
    if (types.contains('bus_station') ||
        types.contains('transit_station') ||
        types.contains('subway_station')) {
      return 'arret de bus';
    }
    return '';
  }

  Future<List<UiLocationSelection>> _searchOverpassFallback(
    gmaps.LatLng center,
  ) async {
    try {
      final query =
          '''
[out:json][timeout:15];
(
  node(around:350,${center.latitude},${center.longitude})[amenity="pharmacy"];
  node(around:350,${center.latitude},${center.longitude})[amenity="fuel"];
  node(around:350,${center.latitude},${center.longitude})[highway="bus_stop"];
  node(around:350,${center.latitude},${center.longitude})[public_transport="platform"];
  node(around:350,${center.latitude},${center.longitude})[public_transport="stop_position"];
  way(around:350,${center.latitude},${center.longitude})[amenity="pharmacy"];
  way(around:350,${center.latitude},${center.longitude})[amenity="fuel"];
  way(around:350,${center.latitude},${center.longitude})[highway="bus_stop"];
  way(around:350,${center.latitude},${center.longitude})[public_transport="platform"];
);
out center 12;
''';

      final response = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        headers: const {
          'Content-Type': 'text/plain; charset=UTF-8',
          'User-Agent': 'BanayLocationPicker/1.0',
        },
        body: query,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const <UiLocationSelection>[];
      }

      final decoded = jsonDecode(response.body);
      final elements = decoded is Map<String, dynamic>
          ? decoded['elements'] as List<dynamic>? ?? const <dynamic>[]
          : const <dynamic>[];

      final results = <UiLocationSelection>[];
      final seenKeys = <String>{};

      for (final element in elements) {
        if (element is! Map<String, dynamic>) {
          continue;
        }
        final tags = element['tags'];
        if (tags is! Map) {
          continue;
        }

        final latValue = element['lat'] ?? (element['center'] as Map?)?['lat'];
        final lonValue = element['lon'] ?? (element['center'] as Map?)?['lon'];
        if (latValue is! num || lonValue is! num) {
          continue;
        }

        final latitude = latValue.toDouble();
        final longitude = lonValue.toDouble();
        final distanceMeters = Geolocator.distanceBetween(
          center.latitude,
          center.longitude,
          latitude,
          longitude,
        );
        final rawName = (tags['name']?.toString() ?? '').trim();
        final displayName = _fallbackLocationTitle(tags, rawName);
        if (displayName.isEmpty) {
          continue;
        }

        final locality =
            tags['addr:city']?.toString() ??
            tags['addr:suburb']?.toString() ??
            tags['addr:street']?.toString() ??
            '';
        final subtitle = [
          if (locality.trim().isNotEmpty) locality.trim(),
          _fallbackLocationDescriptor(tags),
          '${distanceMeters.round()} m',
        ].where((value) => value.trim().isNotEmpty).join(' • ');

        final key =
            '${displayName.toLowerCase()}|${latitude.toStringAsFixed(5)}|${longitude.toStringAsFixed(5)}';
        if (!seenKeys.add(key)) {
          continue;
        }

        results.add(
          UiLocationSelection(
            title: displayName,
            subtitle: subtitle,
            latitude: latitude,
            longitude: longitude,
            distanceMeters: distanceMeters,
          ),
        );
      }

      results.sort((left, right) {
        return (left.distanceMeters ?? double.infinity).compareTo(
          right.distanceMeters ?? double.infinity,
        );
      });
      return results.take(8).toList(growable: false);
    } catch (_) {
      return const <UiLocationSelection>[];
    }
  }

  String _fallbackLocationTitle(Map tags, String fallback) {
    if (fallback.isNotEmpty) {
      return fallback;
    }
    final amenity = (tags['amenity']?.toString() ?? '').trim();
    if (amenity == 'pharmacy') {
      return 'Pharmacie';
    }
    if (amenity == 'fuel') {
      return 'Station-service';
    }
    final highway = (tags['highway']?.toString() ?? '').trim();
    final publicTransport = (tags['public_transport']?.toString() ?? '').trim();
    if (highway == 'bus_stop' ||
        publicTransport == 'platform' ||
        publicTransport == 'stop_position') {
      return 'Arret de bus';
    }
    return '';
  }

  String _fallbackLocationDescriptor(Map tags) {
    final amenity = (tags['amenity']?.toString() ?? '').trim();
    if (amenity == 'pharmacy') {
      return 'pharmacie';
    }
    if (amenity == 'fuel') {
      return 'station-service';
    }
    final highway = (tags['highway']?.toString() ?? '').trim();
    final publicTransport = (tags['public_transport']?.toString() ?? '').trim();
    if (highway == 'bus_stop' ||
        publicTransport == 'platform' ||
        publicTransport == 'stop_position') {
      return 'arret de bus';
    }
    return '';
  }

  Future<void> _refreshMapContext(
    gmaps.LatLng center, {
    bool animated = false,
  }) async {
    final token = ++_refreshToken;
    if (mounted) {
      setState(() {
        _mapCenter = center;
        if (!_isLoading) {
          _isRefreshingMap = true;
        }
      });
    }

    final devicePosition = _devicePosition;
    final distanceMeters = devicePosition == null
        ? 0.0
        : Geolocator.distanceBetween(
            devicePosition.latitude,
            devicePosition.longitude,
            center.latitude,
            center.longitude,
          );

    final selection = await _resolveSelection(
      latitude: center.latitude,
      longitude: center.longitude,
      subtitleOverride: _selectedLocationSubtitle(
        _accuracyMeters,
        distanceMeters: distanceMeters,
      ),
      distanceMeters: distanceMeters,
    );
    final nearbySelections = await _searchNearbySelections(center);

    if (!mounted || token != _refreshToken) {
      return;
    }

    setState(() {
      _selectedLocation = selection;
      _nearbyLocations = nearbySelections;
      _mapNotice = _buildMapNotice(_accuracyMeters ?? 0);
      _isRefreshingMap = false;
    });

    if (animated) {
      if (_enableGoogleMaps) {
        await _googleMapController?.animateCamera(
          gmaps.CameraUpdate.newLatLng(center),
        );
      } else {
        _osmMapController.move(_toOsmLatLng(center), _osmZoom);
      }
    }
  }

  void _scheduleCenterRefresh(gmaps.LatLng center) {
    _mapRefreshDebounce?.cancel();
    _mapRefreshDebounce = Timer(const Duration(milliseconds: 320), () {
      unawaited(_refreshMapContext(center));
    });
  }

  Future<void> _recenterOnCurrentLocation() async {
    final currentLocation = _currentLocation;
    if (currentLocation == null) {
      return;
    }

    final center = gmaps.LatLng(
      currentLocation.latitude,
      currentLocation.longitude,
    );
    if (_enableGoogleMaps) {
      await _googleMapController?.animateCamera(
        gmaps.CameraUpdate.newCameraPosition(
          gmaps.CameraPosition(target: center, zoom: 17.2),
        ),
      );
    } else {
      _osmMapController.move(_toOsmLatLng(center), 17.2);
      _osmZoom = 17.2;
    }
    await _refreshMapContext(center);
  }

  latlng.LatLng _toOsmLatLng(gmaps.LatLng point) {
    return latlng.LatLng(point.latitude, point.longitude);
  }

  @override
  Widget build(BuildContext context) {
    final selectedLocation = _selectedLocation;

    return Scaffold(
      backgroundColor: const Color(0xFF0C1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C1117),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _mapCenter == null
                ? null
                : () => unawaited(_refreshMapContext(_mapCenter!)),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        title: const Text(
          'Envoyer la localisation',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: widget.primary))
            : _errorText != null
            ? _UiLocationPickerErrorView(
                message: _errorText!,
                primary: widget.primary,
                onRetry: _loadLocations,
              )
            : Column(
                children: [
                  _UiLocationMapPreview(
                    useGoogleMaps: _enableGoogleMaps,
                    primary: widget.primary,
                    currentLocation: _currentLocation,
                    selectedLocation: selectedLocation,
                    nearbyLocations: _nearbyLocations,
                    mapCenter: _mapCenter!,
                    osmMapController: _osmMapController,
                    osmZoom: _osmZoom,
                    isRefreshing: _isRefreshingMap,
                    onMapCreated: (controller) {
                      _googleMapController = controller;
                    },
                    onRecenter: () {
                      unawaited(_recenterOnCurrentLocation());
                    },
                    onCameraMove: (center) {
                      _pendingCameraTarget = center;
                    },
                    onCameraIdle: () {
                      final center = _pendingCameraTarget ?? _mapCenter;
                      if (center != null) {
                        _scheduleCenterRefresh(center);
                      }
                    },
                    onOsmPositionChanged: (center, zoom, hasGesture) {
                      _pendingCameraTarget = gmaps.LatLng(
                        center.latitude,
                        center.longitude,
                      );
                      _osmZoom = zoom;
                      if (hasGesture) {
                        _scheduleCenterRefresh(_pendingCameraTarget!);
                      }
                    },
                  ),
                  if (_mapNotice != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Text(
                          _mapNotice!,
                          style: const TextStyle(
                            color: Color(0xFFD1D5DB),
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(0, 10, 0, 24),
                      children: [
                        ListTile(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Le partage en direct sera ajoute bientot.',
                                ),
                              ),
                            );
                          },
                          leading: const CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.white,
                            child: Icon(
                              Icons.radar_rounded,
                              color: Color(0xFF111827),
                            ),
                          ),
                          title: const Text(
                            'Partager localisation en direct',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            _googlePlacesApiKey.isEmpty
                                ? 'Ajoutez BANAY_GOOGLE_PLACES_API_KEY pour les lieux Google Places.'
                                : 'Google Places detecte les lieux autour du point choisi.',
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(18, 14, 18, 8),
                          child: Text(
                            'Lieux proches',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (_currentLocation != null)
                          _UiLocationListTile(
                            selection: _currentLocation!,
                            primary: widget.primary,
                            onTap: () => Navigator.of(
                              context,
                            ).pop<UiLocationSelection>(_currentLocation),
                          ),
                        if (selectedLocation != null &&
                            (_currentLocation == null ||
                                Geolocator.distanceBetween(
                                      _currentLocation!.latitude,
                                      _currentLocation!.longitude,
                                      selectedLocation.latitude,
                                      selectedLocation.longitude,
                                    ) >
                                    6))
                          _UiLocationListTile(
                            selection: UiLocationSelection(
                              title: selectedLocation.title,
                              subtitle:
                                  'Point selectionne • ${selectedLocation.subtitle}',
                              latitude: selectedLocation.latitude,
                              longitude: selectedLocation.longitude,
                              distanceMeters: selectedLocation.distanceMeters,
                            ),
                            primary: widget.primary,
                            onTap: () => Navigator.of(
                              context,
                            ).pop<UiLocationSelection>(selectedLocation),
                          ),
                        if (_nearbyLocations.isEmpty)
                          const Padding(
                            padding: EdgeInsets.fromLTRB(18, 12, 18, 0),
                            child: Text(
                              'Aucun lieu proche trouve pour ce point. Deplacez la carte pour ajuster.',
                              style: TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ..._nearbyLocations.map(
                          (selection) => _UiLocationListTile(
                            selection: selection,
                            primary: widget.primary,
                            onTap: () => Navigator.of(
                              context,
                            ).pop<UiLocationSelection>(selection),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _UiLocationPickerException implements Exception {
  final String message;

  const _UiLocationPickerException(this.message);
}

class _UiLocationPickerErrorView extends StatelessWidget {
  final String message;
  final Color primary;
  final Future<void> Function() onRetry;

  const _UiLocationPickerErrorView({
    required this.message,
    required this.primary,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_rounded, color: primary, size: 38),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: primary),
              child: const Text('Reessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UiLocationMapPreview extends StatelessWidget {
  final bool useGoogleMaps;
  final Color primary;
  final UiLocationSelection? currentLocation;
  final UiLocationSelection? selectedLocation;
  final List<UiLocationSelection> nearbyLocations;
  final gmaps.LatLng mapCenter;
  final MapController osmMapController;
  final double osmZoom;
  final bool isRefreshing;
  final ValueChanged<gmaps.GoogleMapController> onMapCreated;
  final VoidCallback onRecenter;
  final ValueChanged<gmaps.LatLng> onCameraMove;
  final VoidCallback onCameraIdle;
  final void Function(latlng.LatLng center, double zoom, bool hasGesture)
  onOsmPositionChanged;

  const _UiLocationMapPreview({
    required this.useGoogleMaps,
    required this.primary,
    required this.currentLocation,
    required this.selectedLocation,
    required this.nearbyLocations,
    required this.mapCenter,
    required this.osmMapController,
    required this.osmZoom,
    required this.isRefreshing,
    required this.onMapCreated,
    required this.onRecenter,
    required this.onCameraMove,
    required this.onCameraIdle,
    required this.onOsmPositionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final googleMarkers = <gmaps.Marker>{
      if (currentLocation != null)
        gmaps.Marker(
          markerId: const gmaps.MarkerId('current-location'),
          position: gmaps.LatLng(
            currentLocation!.latitude,
            currentLocation!.longitude,
          ),
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
            gmaps.BitmapDescriptor.hueAzure,
          ),
        ),
      ...nearbyLocations.map(
        (location) => gmaps.Marker(
          markerId: gmaps.MarkerId(
            '${location.latitude.toStringAsFixed(5)}-${location.longitude.toStringAsFixed(5)}',
          ),
          position: gmaps.LatLng(location.latitude, location.longitude),
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
            gmaps.BitmapDescriptor.hueGreen,
          ),
          infoWindow: gmaps.InfoWindow(
            title: location.title,
            snippet: location.subtitle,
          ),
        ),
      ),
    };

    final osmMarkers = <Marker>[
      if (currentLocation != null)
        Marker(
          point: latlng.LatLng(
            currentLocation!.latitude,
            currentLocation!.longitude,
          ),
          width: 22,
          height: 22,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ...nearbyLocations.map(
        (location) => Marker(
          point: latlng.LatLng(location.latitude, location.longitude),
          width: 14,
          height: 14,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.4),
            ),
          ),
        ),
      ),
    ];

    return SizedBox(
      height: 288,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: useGoogleMaps
                ? gmaps.GoogleMap(
                    initialCameraPosition: gmaps.CameraPosition(
                      target: mapCenter,
                      zoom: 17.2,
                    ),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    mapToolbarEnabled: false,
                    zoomControlsEnabled: false,
                    compassEnabled: false,
                    markers: googleMarkers,
                    onMapCreated: onMapCreated,
                    onCameraMove: (position) => onCameraMove(position.target),
                    onCameraIdle: onCameraIdle,
                  )
                : FlutterMap(
                    mapController: osmMapController,
                    options: MapOptions(
                      initialCenter: latlng.LatLng(
                        mapCenter.latitude,
                        mapCenter.longitude,
                      ),
                      initialZoom: osmZoom,
                      minZoom: 5,
                      maxZoom: 19,
                      onPositionChanged: (position, hasGesture) {
                        final center = position.center;
                        onOsmPositionChanged(center, position.zoom, hasGesture);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.banay.app',
                      ),
                      MarkerLayer(markers: osmMarkers),
                    ],
                  ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF0C1117).withValues(alpha: 0.14),
                    const Color(0xFF0C1117).withValues(alpha: 0.32),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 14,
            top: 14,
            child: _UiMapControlButton(
              icon: Icons.my_location_rounded,
              onTap: onRecenter,
            ),
          ),
          if (!useGoogleMaps)
            Positioned(
              left: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xCC0C1117),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '© OpenStreetMap contributors',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_pin, color: primary, size: 36),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (selectedLocation != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xCC10161F),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: primary.withValues(alpha: 0.16),
                      child: Icon(
                        Icons.place_rounded,
                        color: primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedLocation!.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            selectedLocation!.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFB6C0CF),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isRefreshing)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UiLocationListTile extends StatelessWidget {
  final UiLocationSelection selection;
  final Color primary;
  final VoidCallback onTap;

  const _UiLocationListTile({
    required this.selection,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final leadingColor = selection.isCurrentLocation
        ? primary.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.08);
    final iconColor = selection.isCurrentLocation ? primary : Colors.white70;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      leading: CircleAvatar(
        radius: 21,
        backgroundColor: leadingColor,
        child: Icon(
          selection.isCurrentLocation
              ? Icons.my_location_rounded
              : Icons.location_on_outlined,
          color: iconColor,
        ),
      ),
      title: Text(
        selection.isCurrentLocation
            ? 'Envoyer votre localisation actuelle'
            : selection.title,
        style: TextStyle(
          color: Colors.white,
          fontWeight: selection.isCurrentLocation
              ? FontWeight.w800
              : FontWeight.w700,
        ),
      ),
      subtitle: Text(
        selection.subtitle,
        style: const TextStyle(
          color: Color(0xFF9CA3AF),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _UiMapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _UiMapControlButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: const Color(0xFF111827), size: 22),
          ),
        ),
      ),
    );
  }
}
