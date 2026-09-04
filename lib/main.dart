import 'dart:async';

import 'package:banay/auth/session_gate.dart';
import 'package:banay/localization/banay_localizations.dart';
import 'package:banay/providers/app_language_provider.dart';
import 'package:banay/services/app_auth_service.dart';
import 'package:banay/services/app_event_log_sync_service.dart';
import 'package:banay/services/api_config.dart';
import 'package:banay/services/feature_flags_service.dart';
import 'package:banay/services/banay_tls_override.dart';
import 'package:banay/services/battery_optimization_service.dart';
import 'package:banay/services/chat_realtime_service.dart';
import 'package:banay/services/location_permission_service.dart';
import 'package:banay/providers/theme_provider.dart';
import 'package:banay/services/push_notification_service.dart';
import 'package:banay/services/session_storage.dart';
import 'package:banay/services/share_intent_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

void main() {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp();

      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      final appLanguageProvider = await AppLanguageProvider.bootstrap();
      await ApiConfig.initialize();
      configureBanayTlsOverride(ApiConfig.baseUrl);
      await PushNotificationService.initialize();
      unawaited(FeatureFlagsService.instance.initialize());
      unawaited(ShareIntentService.instance.initialize());

      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      runApp(MyApp(appLanguageProvider: appLanguageProvider));
    },
    (error, stack) =>
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.appLanguageProvider});

  final AppLanguageProvider appLanguageProvider;

  @override
  Widget build(BuildContext context) {
    return _AppLifecycleBootstrap(appLanguageProvider: appLanguageProvider);
  }
}

class _AppLifecycleBootstrap extends StatefulWidget {
  const _AppLifecycleBootstrap({required this.appLanguageProvider});

  final AppLanguageProvider appLanguageProvider;

  @override
  State<_AppLifecycleBootstrap> createState() => _AppLifecycleBootstrapState();
}

class _AppLifecycleBootstrapState extends State<_AppLifecycleBootstrap>
    with WidgetsBindingObserver {
  final AppAuthService _authService = AppAuthService();
  final SessionStorage _sessionStorage = SessionStorage();
  bool _isSyncingCurrentLocation = false;

  String _buildLocationLabel(Position position, List<Placemark> placemarks) {
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

    if (parts.isEmpty) {
      return '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
    }

    return parts.take(2).join(', ');
  }

  bool _shouldUpdateStoredLocation({
    required String currentLabel,
    required double? currentLatitude,
    required double? currentLongitude,
    required String nextLabel,
    required double nextLatitude,
    required double nextLongitude,
  }) {
    final normalizedCurrentLabel = currentLabel.trim().toLowerCase();
    final normalizedNextLabel = nextLabel.trim().toLowerCase();
    if (normalizedCurrentLabel.isEmpty) {
      return true;
    }

    if (currentLatitude == null || currentLongitude == null) {
      return true;
    }

    final distanceMeters = Geolocator.distanceBetween(
      currentLatitude,
      currentLongitude,
      nextLatitude,
      nextLongitude,
    );

    return normalizedCurrentLabel != normalizedNextLabel ||
        distanceMeters > 150;
  }

  Future<void> _syncCurrentUserLocationOnLaunch() async {
    if (_isSyncingCurrentLocation || kIsWeb) {
      return;
    }

    _isSyncingCurrentLocation = true;

    try {
      final hasValidSession = await _sessionStorage.hasValidSession();
      if (!hasValidSession) {
        return;
      }

      final permission =
          await LocationPermissionService.checkPermissionStatus();
      final servicesEnabled = await Geolocator.isLocationServiceEnabled();
      if (!servicesEnabled ||
          permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
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
      final nextLabel = _buildLocationLabel(position, placemarks);
      final currentUser = await _authService.fetchCurrentUser();

      final currentLabel = (currentUser['locationLabel'] as String?) ?? '';
      final currentLatitude = (currentUser['locationLatitude'] as num?)
          ?.toDouble();
      final currentLongitude = (currentUser['locationLongitude'] as num?)
          ?.toDouble();

      if (!_shouldUpdateStoredLocation(
        currentLabel: currentLabel,
        currentLatitude: currentLatitude,
        currentLongitude: currentLongitude,
        nextLabel: nextLabel,
        nextLatitude: position.latitude,
        nextLongitude: position.longitude,
      )) {
        return;
      }

      await _authService.updateCurrentLocation(
        locationLabel: nextLabel,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
    } finally {
      _isSyncingCurrentLocation = false;
    }
  }

  Future<void> _requestLocationPermissionOnLaunch() async {
    // Ask the OS directly (no custom explanation screen). When the permission
    // is denied forever the system won't show anything; the user can still
    // enable it later from the location picker / account settings.
    await LocationPermissionService.ensurePermissionRequestedOnLaunch();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrapLocationFlow());
    });
  }

  Future<void> _bootstrapLocationFlow() async {
    await _requestLocationPermissionOnLaunch();
    await _syncCurrentUserLocationOnLaunch();
    await _showBatteryOptimizationPromptIfNeeded();
  }

  Future<void> _showBatteryOptimizationPromptIfNeeded() async {
    if (!await BatteryOptimizationService.shouldShowPrompt()) {
      return;
    }

    await BatteryOptimizationService.markPromptShown();

    if (!mounted) {
      return;
    }

    await BatteryOptimizationService.requestIgnoreBatteryOptimizations();
    await BatteryOptimizationService.openManufacturerAutostartSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ChatRealtimeService.instance.handleAppLifecycleStateChanged(state);
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncCurrentUserLocationOnLaunch());
      unawaited(FeatureFlagsService.instance.refresh());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(AppEventLogSyncService.instance.flushPendingEvents());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider<AppLanguageProvider>.value(
          value: widget.appLanguageProvider,
        ),
      ],
      child: Consumer2<ThemeProvider, AppLanguageProvider>(
        builder: (context, themeProvider, appLanguageProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            navigatorKey: PushNotificationService.navigatorKey,
            navigatorObservers: [PushNotificationService.routeObserver],
            home: const SessionGatePage(),
            theme: ThemeProvider.lightTheme,
            darkTheme: ThemeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            locale: appLanguageProvider.locale,
            localizationsDelegates: [
              BanayLocalizations.delegate,
              const _FallbackMaterialLocalizationsDelegate(),
              GlobalWidgetsLocalizations.delegate,
              const _FallbackCupertinoLocalizationsDelegate(),
            ],
            supportedLocales: BanayLocalizations.supportedLocales,
            // Layouts across the app assume a fixed text scale — the OS
            // "large font" accessibility setting can push buttons and other
            // controls off-screen (e.g. an action button in a bottom sheet
            // becoming unreachable), blocking the user entirely. Pin it
            // instead of chasing every screen individually.
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.0)),
                child: child!,
              );
            },
          );
        },
      ),
    );
  }
}

class _FallbackMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _FallbackMaterialLocalizationsDelegate();

  static const _fallback = Locale('fr');

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    final effective = GlobalMaterialLocalizations.delegate.isSupported(locale)
        ? locale
        : _fallback;
    return GlobalMaterialLocalizations.delegate.load(effective);
  }

  @override
  bool shouldReload(
    covariant LocalizationsDelegate<MaterialLocalizations> old,
  ) => false;
}

class _FallbackCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _FallbackCupertinoLocalizationsDelegate();

  static const _fallback = Locale('fr');

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    final effective =
        GlobalCupertinoLocalizations.delegate.isSupported(locale)
            ? locale
            : _fallback;
    return GlobalCupertinoLocalizations.delegate.load(effective);
  }

  @override
  bool shouldReload(
    covariant LocalizationsDelegate<CupertinoLocalizations> old,
  ) => false;
}
