library;

/// 4-point spacing grid.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double section = 28.0;
}

/// Border-radius tokens.
class AppRadius {
  const AppRadius._();

  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 18.0;
  static const double lg = 24.0;
  static const double xl = 28.0;
  static const double pill = 999.0;
}

/// Standard avatar radius values (half the visual diameter).
class AppAvatarRadius {
  const AppAvatarRadius._();

  static const double xs = 13.0;
  static const double sm = 18.0;
  static const double md = 24.0;
  static const double lg = 32.0;
  static const double xl = 44.0;
}

/// Minimum interactive heights.
class AppButtonHeight {
  const AppButtonHeight._();

  static const double sm = 40.0;
  static const double md = 48.0;
  static const double lg = 54.0;
}

/// Input field dimensions.
class AppInputDimensions {
  const AppInputDimensions._();

  static const double height = 48.0;
  static const double borderRadius = AppRadius.md;
}

/// Semantic font-size scale.
///
/// Prefer using Flutter's [TextTheme] (bodySmall, titleMedium, etc.)
/// via [Theme.of(context).textTheme]. Use these constants only when
/// [TextTheme] slots are insufficient (e.g., metric labels, badges).
class AppFontSize {
  const AppFontSize._();

  static const double caption = 11.0;
  static const double labelSm = 12.0;
  static const double labelMd = 13.0;
  static const double labelLg = 14.0;
  static const double body = 15.0;
  static const double bodyLg = 16.0;
  static const double titleSm = 17.0;
  static const double titleMd = 19.0;
  static const double titleLg = 22.0;
  static const double display = 28.0;
}

/// Standard bottom-sheet shape.
class AppSheetShape {
  const AppSheetShape._();

  static const borderRadius = AppRadius.xl;
}

/// Icon sizes used across the app.
class AppIconSize {
  const AppIconSize._();

  static const double sm = 16.0;
  static const double md = 20.0;
  static const double lg = 24.0;
  static const double xl = 28.0;
}
