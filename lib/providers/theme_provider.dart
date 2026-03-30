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
            seedColor: const Color(0xFF2F7D4E),
            brightness: Brightness.light,
          ).copyWith(
            primary: const Color(0xFF2F7D4E),
            onPrimary: Colors.white,
            secondary: const Color(0xFFBE2D3E),
            tertiary: const Color(0xFF6C756F),
            error: const Color(0xFFB3261E),
            surface: const Color(0xFFFFFCFB),
            onSurface: const Color(0xFF202321),
            onSurfaceVariant: const Color(0xFF6C736F),
            outline: const Color(0xFFC9D0CC),
            outlineVariant: const Color(0xFFE5E9E6),
            surfaceContainer: const Color(0xFFF5F6F4),
            surfaceContainerHighest: const Color(0xFFEDEFEA),
          ),
      appColors: const AppThemeColors(
        backgroundBase: Color(0xFFFFFCFB),
        authBackground: Color(0xFFFFFCFB),
        panelBackground: Color(0xFFFFFFFF),
        panelMuted: Color(0xFFE7EFEA),
        borderColor: Color(0xFFD7DEDA),
        inputFill: Color(0xFFF2F4F1),
        inputBorder: Color(0xFFD7DEDA),
        mutedText: Color(0xFF6C736F),
        success: Color(0xFFBE2D3E),
        placeholderFill: Color(0x4DB4BAB6),
        placeholderIcon: Color(0xFF919893),
        heroAccent: Color(0xFF2F7D4E),
        heroForeground: Colors.white,
        heroForegroundMuted: Color(0xFFEAF4EE),
        heroSurface: Color(0x24FFFFFF),
        heroBorder: Color(0x3DFFFFFF),
        viewerBackground: Colors.black,
        scrimSoft: Color(0x50000000),
        scrimStrong: Color(0xC4000000),
        overlaySurface: Color(0x85000000),
        overlayBorder: Color(0x24FFFFFF),
        favoriteAccent: Color(0xFFBE2D3E),
        onlineStatus: Color(0xFF2F7D4E),
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
            seedColor: const Color(0xFF63B27D),
            brightness: Brightness.dark,
          ).copyWith(
            primary: const Color.fromARGB(255, 3, 148, 23),
            onPrimary: const Color(0xFF0F2014),
            secondary: const Color.fromARGB(255, 194, 19, 36),
            tertiary: const Color(0xFFA2ABA6),
            error: const Color.fromARGB(255, 169, 16, 2),
            surface: const Color(0xFF171C19),
            onSurface: const Color(0xFFF2F4F1),
            onSurfaceVariant: const Color(0xFFC8CEC9),
            outline: const Color(0xFF58615C),
            outlineVariant: const Color(0xFF343C37),
            surfaceContainer: const Color(0xFF1F2521),
            surfaceContainerHighest: const Color(0xFF29302C),
          ),
      appColors: const AppThemeColors(
        backgroundBase: Color.fromARGB(255, 22, 22, 22),
        authBackground: Color.fromARGB(255, 22, 22, 22),
        panelBackground: Color.fromARGB(255, 26, 26, 26),
        panelMuted: Color(0xFF2B322D),
        borderColor: Color(0xFF343C37),
        inputFill: Color(0xFF202622),
        inputBorder: Color(0xFF343C37),
        mutedText: Color(0xFFC8CEC9),
        success: Color.fromARGB(255, 195, 7, 26),
        placeholderFill: Color(0x4D929A95),
        placeholderIcon: Color(0xFFA1A8A3),
        heroAccent: Color(0xFF2C8B52),
        heroForeground: Colors.white,
        heroForegroundMuted: Color(0xFFF0F2F1),
        heroSurface: Color(0x24FFFFFF),
        heroBorder: Color(0x3DFFFFFF),
        viewerBackground: Colors.black,
        scrimSoft: Color(0x66000000),
        scrimStrong: Color(0xDE000000),
        overlaySurface: Color(0x94000000),
        overlayBorder: Color(0x24FFFFFF),
        favoriteAccent: Color.fromARGB(255, 207, 18, 37),
        onlineStatus: Color(0xFF63B27D),
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
