import 'package:flutter/material.dart';

@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color backgroundBase;
  final Color authBackground;
  final Color panelBackground;
  final Color panelBackground_;
  final Color productCardBackground;
  final Color panelMuted;
  final Color borderColor;
  final Color inputFill;
  final Color inputBorder;
  final Color mutedText;
  final Color success;
  final Color placeholderFill;
  final Color placeholderIcon;
  final Color heroAccent;
  final Color heroForeground;
  final Color heroForegroundMuted;
  final Color heroSurface;
  final Color heroBorder;
  final Color viewerBackground;
  final Color scrimSoft;
  final Color scrimStrong;
  final Color overlaySurface;
  final Color overlayBorder;
  final Color favoriteAccent;
  final Color onlineStatus;
  final Color backButtonFill;
  final Color backButtonBorder;
  final Color socialFacebook;
  final Color socialWhatsApp;

  // --- Product-specific semantic colors ---
  /// Green indicator for an available product (availability badge/border).
  final Color availableAccent;

  /// Red indicator for an unavailable product (badge, overlay, gradient).
  final Color unavailableAccent;

  /// Red indicator for a live broadcast card/button.
  final Color liveIndicator;

  /// Intentionally dark surface for editorial product cards (always dark,
  /// independent of theme brightness).
  final Color productCardSurface;

  /// Purple accent for marketplace / featured-product badge.
  final Color marketplaceBadge;

  const AppThemeColors({
    required this.backgroundBase,
    required this.authBackground,
    required this.panelBackground,
    required this.panelBackground_,
    required this.productCardBackground,
    required this.panelMuted,
    required this.borderColor,
    required this.inputFill,
    required this.inputBorder,
    required this.mutedText,
    required this.success,
    required this.placeholderFill,
    required this.placeholderIcon,
    required this.heroAccent,
    required this.heroForeground,
    required this.heroForegroundMuted,
    required this.heroSurface,
    required this.heroBorder,
    required this.viewerBackground,
    required this.scrimSoft,
    required this.scrimStrong,
    required this.overlaySurface,
    required this.overlayBorder,
    required this.favoriteAccent,
    required this.onlineStatus,
    required this.backButtonFill,
    required this.backButtonBorder,
    required this.socialFacebook,
    required this.socialWhatsApp,
    required this.availableAccent,
    required this.unavailableAccent,
    required this.liveIndicator,
    required this.productCardSurface,
    required this.marketplaceBadge,
  });

  @override
  AppThemeColors copyWith({
    Color? backgroundBase,
    Color? authBackground,
    Color? panelBackground,
    Color? productCardBackground,
    Color? panelMuted,
    Color? borderColor,
    Color? inputFill,
    Color? inputBorder,
    Color? mutedText,
    Color? success,
    Color? placeholderFill,
    Color? placeholderIcon,
    Color? heroAccent,
    Color? heroForeground,
    Color? heroForegroundMuted,
    Color? heroSurface,
    Color? heroBorder,
    Color? viewerBackground,
    Color? scrimSoft,
    Color? scrimStrong,
    Color? overlaySurface,
    Color? overlayBorder,
    Color? favoriteAccent,
    Color? onlineStatus,
    Color? backButtonFill,
    Color? backButtonBorder,
    Color? socialFacebook,
    Color? socialWhatsApp,
    Color? availableAccent,
    Color? unavailableAccent,
    Color? liveIndicator,
    Color? productCardSurface,
    Color? marketplaceBadge,
  }) {
    return AppThemeColors(
      backgroundBase: backgroundBase ?? this.backgroundBase,
      authBackground: authBackground ?? this.authBackground,
      panelBackground: panelBackground ?? this.panelBackground,
      panelBackground_: panelBackground ?? this.panelBackground,
      productCardBackground:
          productCardBackground ?? this.productCardBackground,
      panelMuted: panelMuted ?? this.panelMuted,
      borderColor: borderColor ?? this.borderColor,
      inputFill: inputFill ?? this.inputFill,
      inputBorder: inputBorder ?? this.inputBorder,
      mutedText: mutedText ?? this.mutedText,
      success: success ?? this.success,
      placeholderFill: placeholderFill ?? this.placeholderFill,
      placeholderIcon: placeholderIcon ?? this.placeholderIcon,
      heroAccent: heroAccent ?? this.heroAccent,
      heroForeground: heroForeground ?? this.heroForeground,
      heroForegroundMuted: heroForegroundMuted ?? this.heroForegroundMuted,
      heroSurface: heroSurface ?? this.heroSurface,
      heroBorder: heroBorder ?? this.heroBorder,
      viewerBackground: viewerBackground ?? this.viewerBackground,
      scrimSoft: scrimSoft ?? this.scrimSoft,
      scrimStrong: scrimStrong ?? this.scrimStrong,
      overlaySurface: overlaySurface ?? this.overlaySurface,
      overlayBorder: overlayBorder ?? this.overlayBorder,
      favoriteAccent: favoriteAccent ?? this.favoriteAccent,
      onlineStatus: onlineStatus ?? this.onlineStatus,
      backButtonFill: backButtonFill ?? this.backButtonFill,
      backButtonBorder: backButtonBorder ?? this.backButtonBorder,
      socialFacebook: socialFacebook ?? this.socialFacebook,
      socialWhatsApp: socialWhatsApp ?? this.socialWhatsApp,
      availableAccent: availableAccent ?? this.availableAccent,
      unavailableAccent: unavailableAccent ?? this.unavailableAccent,
      liveIndicator: liveIndicator ?? this.liveIndicator,
      productCardSurface: productCardSurface ?? this.productCardSurface,
      marketplaceBadge: marketplaceBadge ?? this.marketplaceBadge,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) {
      return this;
    }

    return AppThemeColors(
      backgroundBase: Color.lerp(backgroundBase, other.backgroundBase, t)!,
      authBackground: Color.lerp(authBackground, other.authBackground, t)!,
      panelBackground: Color.lerp(panelBackground, other.panelBackground, t)!,
      panelBackground_: Color.lerp(panelBackground, other.panelBackground, t)!,
      productCardBackground: Color.lerp(
        productCardBackground,
        other.productCardBackground,
        t,
      )!,
      panelMuted: Color.lerp(panelMuted, other.panelMuted, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      success: Color.lerp(success, other.success, t)!,
      placeholderFill: Color.lerp(placeholderFill, other.placeholderFill, t)!,
      placeholderIcon: Color.lerp(placeholderIcon, other.placeholderIcon, t)!,
      heroAccent: Color.lerp(heroAccent, other.heroAccent, t)!,
      heroForeground: Color.lerp(heroForeground, other.heroForeground, t)!,
      heroForegroundMuted: Color.lerp(
        heroForegroundMuted,
        other.heroForegroundMuted,
        t,
      )!,
      heroSurface: Color.lerp(heroSurface, other.heroSurface, t)!,
      heroBorder: Color.lerp(heroBorder, other.heroBorder, t)!,
      viewerBackground: Color.lerp(
        viewerBackground,
        other.viewerBackground,
        t,
      )!,
      scrimSoft: Color.lerp(scrimSoft, other.scrimSoft, t)!,
      scrimStrong: Color.lerp(scrimStrong, other.scrimStrong, t)!,
      overlaySurface: Color.lerp(overlaySurface, other.overlaySurface, t)!,
      overlayBorder: Color.lerp(overlayBorder, other.overlayBorder, t)!,
      favoriteAccent: Color.lerp(favoriteAccent, other.favoriteAccent, t)!,
      onlineStatus: Color.lerp(onlineStatus, other.onlineStatus, t)!,
      backButtonFill: Color.lerp(backButtonFill, other.backButtonFill, t)!,
      backButtonBorder: Color.lerp(
        backButtonBorder,
        other.backButtonBorder,
        t,
      )!,
      socialFacebook: Color.lerp(socialFacebook, other.socialFacebook, t)!,
      socialWhatsApp: Color.lerp(socialWhatsApp, other.socialWhatsApp, t)!,
      availableAccent: Color.lerp(availableAccent, other.availableAccent, t)!,
      unavailableAccent: Color.lerp(
        unavailableAccent,
        other.unavailableAccent,
        t,
      )!,
      liveIndicator: Color.lerp(liveIndicator, other.liveIndicator, t)!,
      productCardSurface: Color.lerp(
        productCardSurface,
        other.productCardSurface,
        t,
      )!,
      marketplaceBadge: Color.lerp(marketplaceBadge, other.marketplaceBadge, t)!,
    );
  }
}

extension AppThemeColorsX on ThemeData {
  AppThemeColors get appColors => extension<AppThemeColors>()!;
}
