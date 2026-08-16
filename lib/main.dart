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

enum _LocationPermissionDialogAction { later, continueRequest }

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

  Future<void> _showLocationPermissionPreDialog() async {
    while (mounted) {
      final permission =
          await LocationPermissionService.checkPermissionStatus();
      if (!mounted) {
        return;
      }

      if (!LocationPermissionService.shouldExplainOnLaunch(permission)) {
        return;
      }

      final dialogContext = PushNotificationService.navigatorKey.currentContext;
      if (dialogContext == null || !dialogContext.mounted) {
        return;
      }
      final isDeniedForever = permission == LocationPermission.deniedForever;
      final action = await showDialog<_LocationPermissionDialogAction>(
        context: dialogContext,
        barrierDismissible: false,
        builder: (context) {
          return _LocationPermissionDialog(isDeniedForever: isDeniedForever);
        },
      );
      if (!mounted) {
        return;
      }

      if (action != _LocationPermissionDialogAction.continueRequest) {
        await Future<void>.delayed(const Duration(milliseconds: 220));
        continue;
      }

      if (isDeniedForever) {
        await LocationPermissionService.openAppSettingsForPermission();
      } else {
        await LocationPermissionService.requestPermissionAfterExplanation();
      }

      if (!mounted) {
        return;
      }
    }
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
    await _showLocationPermissionPreDialog();
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

class _LocationPermissionDialog extends StatelessWidget {
  final bool isDeniedForever;

  const _LocationPermissionDialog({required this.isDeniedForever});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final blockedTitle = context.tr(
      BanayLocalizationKeys.locationPermissionBlockedTitle,
    );
    final enableTitle = context.tr(BanayLocalizationKeys.enableLocationTitle);
    final blockedBody = context.tr(
      BanayLocalizationKeys.locationPermissionBlockedBody,
    );
    final enabledBody = context.tr(
      BanayLocalizationKeys.locationPermissionBody,
    );
    final surfaceTint = isDeniedForever
        ? colors.error.withValues(alpha: 0.18)
        : colors.primary.withValues(alpha: 0.18);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.18),
              blurRadius: 30,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: [
                      surfaceTint,
                      colors.surfaceContainerHighest.withValues(alpha: 0.88),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: isDeniedForever ? colors.error : colors.primary,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Icon(
                        isDeniedForever
                            ? Icons.settings_suggest_rounded
                            : Icons.location_searching_rounded,
                        color: colors.onPrimary,
                        size: 34,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isDeniedForever ? blockedTitle : enableTitle,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isDeniedForever ? blockedBody : enabledBody,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurface.withValues(alpha: 0.76),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _PermissionInfoRow(
                icon: Icons.storefront_rounded,
                label: context.tr(BanayLocalizationKeys.locationInfoNearby),
                tint: colors.primary,
              ),
              const SizedBox(height: 10),
              _PermissionInfoRow(
                icon: Icons.local_shipping_rounded,
                label: context.tr(BanayLocalizationKeys.locationInfoDelivery),
                tint: colors.secondary,
              ),
              const SizedBox(height: 10),
              _PermissionInfoRow(
                icon: Icons.shield_moon_rounded,
                label: isDeniedForever
                    ? context.tr(BanayLocalizationKeys.locationInfoBlocked)
                    : context.tr(BanayLocalizationKeys.locationInfoUsage),
                tint: isDeniedForever ? colors.error : colors.tertiary,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(_LocationPermissionDialogAction.later),
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text(context.tr(BanayLocalizationKeys.later)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(_LocationPermissionDialogAction.continueRequest),
                      icon: Icon(
                        isDeniedForever
                            ? Icons.open_in_new_rounded
                            : Icons.my_location_rounded,
                      ),
                      label: Text(
                        isDeniedForever
                            ? context.tr(BanayLocalizationKeys.openSettings)
                            : context.tr(BanayLocalizationKeys.allow),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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

class _PermissionInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color tint;

  const _PermissionInfoRow({
    required this.icon,
    required this.label,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: tint, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.onSurface.withValues(alpha: 0.84),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
