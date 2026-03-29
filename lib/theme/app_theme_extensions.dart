import 'package:flutter/material.dart';

@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color backgroundBase;
  final Color panelBackground;
  final Color panelMuted;
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

  const AppThemeColors({
    required this.backgroundBase,
    required this.panelBackground,
    required this.panelMuted,
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
  });

  @override
  AppThemeColors copyWith({
    Color? backgroundBase,
    Color? panelBackground,
    Color? panelMuted,
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
  }) {
    return AppThemeColors(
      backgroundBase: backgroundBase ?? this.backgroundBase,
      panelBackground: panelBackground ?? this.panelBackground,
      panelMuted: panelMuted ?? this.panelMuted,
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
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) {
      return this;
    }

    return AppThemeColors(
      backgroundBase: Color.lerp(backgroundBase, other.backgroundBase, t)!,
      panelBackground: Color.lerp(panelBackground, other.panelBackground, t)!,
      panelMuted: Color.lerp(panelMuted, other.panelMuted, t)!,
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
    );
  }
}

extension AppThemeColorsX on ThemeData {
  AppThemeColors get appColors => extension<AppThemeColors>()!;
}
