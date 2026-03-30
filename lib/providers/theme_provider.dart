import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bahibo/theme/app_theme_extensions.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadThemeFromPrefs();
  }

  Future<void> _loadThemeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex =
        prefs.getInt(_themeKey) ?? 0; // 0 = system, 1 = light, 2 = dark
    _themeMode = ThemeMode.values[themeIndex];
    notifyListeners();
  }

  Future<void> _saveThemeToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, _themeMode.index);
  }

  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else if (_themeMode == ThemeMode.dark) {
      _themeMode = ThemeMode.light;
    } else {
      // Si c'est system, on passe en light
      _themeMode = ThemeMode.light;
    }
    _saveThemeToPrefs();
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _saveThemeToPrefs();
    notifyListeners();
  }

  static ThemeData get lightTheme {
    return _buildTheme(
      brightness: Brightness.light,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: const Color(0xFFB86A3C),
            brightness: Brightness.light,
          ).copyWith(
            primary: const Color(0xFFB86A3C),
            onPrimary: Colors.white,
            secondary: const Color(0xFFD39A68),
            tertiary: const Color(0xFF748B61),
            error: const Color(0xFFC85A54),
            surface: const Color(0xFFFFFCF7),
            onSurface: const Color(0xFF221A16),
            onSurfaceVariant: const Color(0xFF6E6A67),
            outline: const Color(0xFFCBBEAF),
            outlineVariant: const Color(0xFFE4D9CC),
            surfaceContainer: const Color(0xFFF8F1E9),
            surfaceContainerHighest: const Color(0xFFF1E4D8),
          ),
      appColors: const AppThemeColors(
        backgroundBase: Color(0xFFFFFCF7),
        authBackground: Color(0xFFFFFCF7),
        panelBackground: Color(0xFFFFFCF7),
        panelMuted: Color(0xFFF4E0D1),
        borderColor: Color(0xFFE4D9CC),
        inputFill: Color(0xFFF8F1E9),
        inputBorder: Color(0xFFE4D9CC),
        mutedText: Color(0xFF6E6A67),
        success: Color(0xFF708B5A),
        placeholderFill: Color(0x4D9E9E9E),
        placeholderIcon: Color(0xFF8A817A),
        heroAccent: Color(0xFF8E5834),
        heroForeground: Colors.white,
        heroForegroundMuted: Color(0xFFDCCFC3),
        heroSurface: Color(0x24FFFFFF),
        heroBorder: Color(0x3DFFFFFF),
        viewerBackground: Colors.black,
        scrimSoft: Color(0x5C000000),
        scrimStrong: Color(0xD6000000),
        overlaySurface: Color(0x85000000),
        overlayBorder: Color(0x24FFFFFF),
        favoriteAccent: Color(0xFFFF4D6D),
        onlineStatus: Color(0xFF708B5A),
        backButtonFill: Color(0x47000000),
        backButtonBorder: Color(0x3DFFFFFF),
        socialFacebook: Color(0xFF4267B2),
        socialWhatsApp: Color(0xFF25D366),
      ),
    );
  }

  static ThemeData get darkTheme {
    return _buildTheme(
      brightness: Brightness.dark,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: const Color(0xFFF0B67F),
            brightness: Brightness.dark,
          ).copyWith(
            primary: const Color(0xFFF0B67F),
            onPrimary: const Color(0xFF21160F),
            secondary: const Color(0xFFBF8357),
            tertiary: const Color(0xFFA7C08F),
            error: const Color(0xFFFF8C82),
            surface: const Color(0xFF1D2027),
            onSurface: const Color(0xFFF5F2EC),
            onSurfaceVariant: const Color(0xFFD1D4DD),
            outline: const Color(0xFF5B616D),
            outlineVariant: const Color(0xFF3E434D),
            surfaceContainer: const Color(0xFF242830),
            surfaceContainerHighest: const Color(0xFF2B303A),
          ),
      appColors: const AppThemeColors(
        backgroundBase: Color(0xFF0C1015),
        authBackground: Color(0xFF0C1015),
        panelBackground: Color(0xFF1D2027),
        panelMuted: Color(0xFF3B3128),
        borderColor: Color(0xFF3E434D),
        inputFill: Color(0xFF232730),
        inputBorder: Color(0xFF3E434D),
        mutedText: Color(0xFFD1D4DD),
        success: Color(0xFFA7C08F),
        placeholderFill: Color(0x4D9E9E9E),
        placeholderIcon: Color(0xFFA6AAB4),
        heroAccent: Color(0xFF6D4429),
        heroForeground: Colors.white,
        heroForegroundMuted: Color(0xFFE3D7CD),
        heroSurface: Color(0x24FFFFFF),
        heroBorder: Color(0x3DFFFFFF),
        viewerBackground: Colors.black,
        scrimSoft: Color(0x66000000),
        scrimStrong: Color(0xDE000000),
        overlaySurface: Color(0x94000000),
        overlayBorder: Color(0x24FFFFFF),
        favoriteAccent: Color(0xFFFF8AA0),
        onlineStatus: Color(0xFFA7C08F),
        backButtonFill: Color(0x52000000),
        backButtonBorder: Color(0x3DFFFFFF),
        socialFacebook: Color(0xFF7EA2FF),
        socialWhatsApp: Color(0xFF63E39C),
      ),
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required AppThemeColors appColors,
  }) {
    final isDark = brightness == Brightness.dark;
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      primaryColor: colorScheme.primary,
      scaffoldBackgroundColor: appColors.backgroundBase,
      cardColor: appColors.panelBackground,
      canvasColor: appColors.backgroundBase,
      dialogBackgroundColor: appColors.panelBackground,
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
        ),
        behavior: SnackBarBehavior.floating,
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
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.32)),
        ),
      ),
    );
  }
}
