import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:banay/theme/app_theme_extensions.dart';

const Color _BANAYPrimary = Color.fromARGB(255, 0, 174, 70);
const Color _BANAYPrimarySoft = Color(0xFF63B27D);
const Color _BANAYSecondary = Color.fromARGB(255, 200, 4, 26);
const Color _BANAYSuccess = Color(0xFF2F7D4E);
const Color _BANAYFacebook = Color(0xFF4267B2);
const Color _BANAYWhatsApp = Color(0xFF25D366);
const Color _BANAYProductCardBackgroundLight = Color.fromARGB(
  84,
  219,
  219,
  219,
);
const Color _BANAYProductCardBackgroundDark = Color.fromARGB(41, 22, 22, 22);


class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadThemeFromPrefs();
  }

  Future<void> _loadThemeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey);
    final savedThemeMode =
        themeIndex != null &&
            themeIndex >= 0 &&
            themeIndex < ThemeMode.values.length
        ? ThemeMode.values[themeIndex]
        : ThemeMode.dark;
    _themeMode = savedThemeMode == ThemeMode.system
        ? ThemeMode.dark
        : savedThemeMode;
    notifyListeners();
  }

  Future<void> _saveThemeToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, _themeMode.index);
  }

  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.light;
    }
    _saveThemeToPrefs();
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode == ThemeMode.system ? ThemeMode.dark : mode;
    _saveThemeToPrefs();
    notifyListeners();
  }

  static ThemeData get lightTheme {
    return _buildTheme(
      brightness: Brightness.light,
      colorScheme: _lightColorScheme,
      appColors: const AppThemeColors(
        backgroundBase: Color(0xFFFFFCFB),
        authBackground: Color(0xFFFFFCFB),
        panelBackground: Color(0xFFFFFFFF),
        panelBackground_: Color(0xFFFFFFFF),
        productCardBackground: _BANAYProductCardBackgroundLight,
        panelMuted: Color(0xFFE7EFEA),
        borderColor: Color(0xFFD7DEDA),
        inputFill: Color(0xFFF2F4F1),
        inputBorder: Color(0xFFD7DEDA),
        mutedText: Color(0xFF6C736F),
        success: _BANAYSuccess,
        placeholderFill: Color(0x4DB4BAB6),
        placeholderIcon: Color(0xFF919893),
        heroAccent: _BANAYPrimary,
        heroForeground: Colors.white,
        heroForegroundMuted: Color(0xFFEAF4EE),
        heroSurface: Color(0x24FFFFFF),
        heroBorder: Color(0x3DFFFFFF),
        viewerBackground: Colors.black,
        scrimSoft: Color(0x50000000),
        scrimStrong: Color(0xC4000000),
        overlaySurface: Color(0x85000000),
        overlayBorder: Color(0x24FFFFFF),
        favoriteAccent: _BANAYSecondary,
        onlineStatus: _BANAYPrimary,
        backButtonFill: Color(0x47000000),
        backButtonBorder: Color(0x3DFFFFFF),
        socialFacebook: _BANAYFacebook,
        socialWhatsApp: _BANAYWhatsApp,
        availableAccent: Color(0xFF159A52),
        unavailableAccent: Color(0xFFD84343),
        liveIndicator: Color(0xFFE53935),
        productCardSurface: Color(0xFFFFFFFF),
        marketplaceBadge: Color(0xFF8F42FF),
      ),
    );
  }

  static ThemeData get darkTheme {
    return _buildTheme(
      brightness: Brightness.dark,
      colorScheme: _darkColorScheme,
      appColors: const AppThemeColors(
        // backgroundBase: Color(0xFF141816),
        backgroundBase: Color.fromARGB(255, 8, 8, 8),
        authBackground: Color.fromARGB(255, 8, 8, 8),
        panelBackground: Color.fromARGB(255, 20, 21, 21),
        // panelBackground_: Color.fromARGB(255, 28, 28, 28),
        panelBackground_: Color.fromARGB(255, 8, 8, 8),
        productCardBackground: _BANAYProductCardBackgroundDark,
        // panelBackground: Color(0xFF1B201D),
        panelMuted: Color(0xFF242B27),
        borderColor: Color.fromARGB(97, 32, 35, 33),
        inputFill: Color(0xFF202622),
        inputBorder: Color(0xFF343C37),
        mutedText: Color(0xFFC8CEC9),
        success: _BANAYSuccess,
        placeholderFill: Color(0x4D929A95),
        placeholderIcon: Color(0xFFA1A8A3),
        heroAccent: _BANAYPrimary,
        heroForeground: Colors.white,
        heroForegroundMuted: Color(0xFFF0F2F1),
        heroSurface: Color(0x24FFFFFF),
        heroBorder: Color(0x3DFFFFFF),
        viewerBackground: Colors.black,
        scrimSoft: Color(0x66000000),
        scrimStrong: Color(0xDE000000),
        overlaySurface: Color(0x94000000),
        overlayBorder: Color(0x24FFFFFF),
        favoriteAccent: _BANAYSecondary,
        onlineStatus: _BANAYPrimarySoft,
        backButtonFill: Color(0x52000000),
        backButtonBorder: Color(0x3DFFFFFF),
        socialFacebook: _BANAYFacebook,
        socialWhatsApp: _BANAYWhatsApp,
        availableAccent: Color(0xFF159A52),
        unavailableAccent: Color(0xFFD84343),
        liveIndicator: Color(0xFFE53935),
        productCardSurface: Color(0xFF101112),
        marketplaceBadge: Color(0xFF8F42FF),
      ),
    );
  }

  static const ColorScheme _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: _BANAYPrimary,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFD9EBDD),
    onPrimaryContainer: Color(0xFF123722),
    secondary: _BANAYSecondary,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFF7D9DE),
    onSecondaryContainer: Color(0xFF4A0F18),
    tertiary: Color(0xFF6C756F),
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFE2E8E3),
    onTertiaryContainer: Color(0xFF27302B),
    error: Color(0xFFB3261E),
    onError: Colors.white,
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),
    surface: Color(0xFFFFFCFB),
    onSurface: Color(0xFF202321),
    surfaceContainerHighest: Color(0xFFEDEFEA),
    onSurfaceVariant: Color(0xFF6C736F),
    outline: Color(0xFFC9D0CC),
    outlineVariant: Color(0xFFE5E9E6),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF2D312F),
    onInverseSurface: Color(0xFFF1F3F0),
    inversePrimary: _BANAYPrimarySoft,
    surfaceTint: _BANAYPrimary,
  );

  static const ColorScheme _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: _BANAYPrimary,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFF214E35),
    onPrimaryContainer: Color(0xFFD9EBDD),
    secondary: _BANAYSecondary,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFF61212A),
    onSecondaryContainer: Color(0xFFF8DBE0),
    tertiary: Color(0xFFA2ABA6),
    onTertiary: Color(0xFF101512),
    tertiaryContainer: Color(0xFF3A433E),
    onTertiaryContainer: Color(0xFFE1E7E2),
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF601410),
    errorContainer: Color(0xFF8C1D18),
    onErrorContainer: Color(0xFFF9DEDC),
    surface: Color(0xFF171C19),
    onSurface: Color(0xFFF2F4F1),
    surfaceContainerHighest: Color(0xFF29302C),
    onSurfaceVariant: Color(0xFFC8CEC9),
    outline: Color(0xFF58615C),
    outlineVariant: Color(0xFF343C37),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE6EAE6),
    onInverseSurface: Color(0xFF2A2F2C),
    inversePrimary: _BANAYPrimary,
    surfaceTint: _BANAYPrimary,
  );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required AppThemeColors appColors,
  }) {
    final isDark = brightness == Brightness.dark;
    final rubikTextTheme = GoogleFonts.rubikTextTheme(
      ThemeData(brightness: brightness).textTheme,
    );

    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      primaryColor: colorScheme.primary,
      scaffoldBackgroundColor: appColors.backgroundBase,
      cardColor: appColors.panelBackground_,
      canvasColor: appColors.backgroundBase,
      textTheme: rubikTextTheme,
      extensions: <ThemeExtension<dynamic>>[appColors],
    );

    return baseTheme.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: appColors.backgroundBase,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? appColors.panelMuted : colorScheme.onSurface,
        contentTextStyle: TextStyle(
          color: isDark ? colorScheme.onSurface : colorScheme.surface,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: appColors.panelBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: appColors.inputFill,
        hintStyle: TextStyle(
          color: appColors.mutedText,
          fontWeight: FontWeight.w600,
        ),
        labelStyle: TextStyle(
          color: appColors.mutedText,
          fontWeight: FontWeight.w600,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: appColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.error, width: 1.6),
        ),
        prefixIconColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return colorScheme.primary;
          }
          return appColors.mutedText;
        }),
        suffixIconColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return colorScheme.primary;
          }
          return appColors.mutedText;
        }),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStatePropertyAll(colorScheme.primary),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStatePropertyAll(colorScheme.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          minimumSize: const Size(64, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.32)),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
