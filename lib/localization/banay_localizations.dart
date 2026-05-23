import 'package:flutter/material.dart';

import 'package:banay/localization/banay_localization_auth.dart';
import 'package:banay/localization/banay_localization_auth_keys.dart';
import 'package:banay/localization/banay_localization_common.dart';
import 'package:banay/localization/banay_localization_common_keys.dart';
import 'package:banay/localization/banay_localization_location.dart';
import 'package:banay/localization/banay_localization_location_keys.dart';

abstract final class BanayLocalizationKeys {
  static const languagePageTitle = BanayAuthLocalizationKeys.languagePageTitle;
  static const languagePageSubtitle =
      BanayAuthLocalizationKeys.languagePageSubtitle;
  static const continueAction = BanayCommonLocalizationKeys.continueAction;
  static const edit = BanayCommonLocalizationKeys.edit;
  static const yes = BanayCommonLocalizationKeys.yes;
  static const later = BanayCommonLocalizationKeys.later;
  static const allow = BanayCommonLocalizationKeys.allow;
  static const openSettings = BanayCommonLocalizationKeys.openSettings;
  static const phonePageTitle = BanayAuthLocalizationKeys.phonePageTitle;
  static const phonePageSubtitleLine1 =
      BanayAuthLocalizationKeys.phonePageSubtitleLine1;
  static const phonePageSubtitleLine2 =
      BanayAuthLocalizationKeys.phonePageSubtitleLine2;
  static const country = BanayAuthLocalizationKeys.country;
  static const chooseCountryTooltip =
      BanayAuthLocalizationKeys.chooseCountryTooltip;
  static const phoneNumber = BanayAuthLocalizationKeys.phoneNumber;
  static const simDetectionInProgress =
      BanayAuthLocalizationKeys.simDetectionInProgress;
  static const useSimNumber = BanayAuthLocalizationKeys.useSimNumber;
  static const detectedNumber = BanayAuthLocalizationKeys.detectedNumber;
  static const sendingOtp = BanayAuthLocalizationKeys.sendingOtp;
  static const simNumberUnavailable =
      BanayAuthLocalizationKeys.simNumberUnavailable;
  static const simNumberDetected = BanayAuthLocalizationKeys.simNumberDetected;
  static const invalidPhoneNumber =
      BanayAuthLocalizationKeys.invalidPhoneNumber;
  static const confirmNumber = BanayAuthLocalizationKeys.confirmNumber;
  static const otpSmsSent = BanayAuthLocalizationKeys.otpSmsSent;
  static const verifyNumberTitle = BanayAuthLocalizationKeys.verifyNumberTitle;
  static const enterCodeMessage = BanayAuthLocalizationKeys.enterCodeMessage;
  static const autodetectUnavailable =
      BanayAuthLocalizationKeys.autodetectUnavailable;
  static const devModeCurrentOtp = BanayAuthLocalizationKeys.devModeCurrentOtp;
  static const resendAvailableIn = BanayAuthLocalizationKeys.resendAvailableIn;
  static const requestNewOtpNow = BanayAuthLocalizationKeys.requestNewOtpNow;
  static const verifying = BanayAuthLocalizationKeys.verifying;
  static const verifyOtp = BanayAuthLocalizationKeys.verifyOtp;
  static const resending = BanayAuthLocalizationKeys.resending;
  static const resendCode = BanayAuthLocalizationKeys.resendCode;
  static const otpAutoDetectionTitle =
      BanayAuthLocalizationKeys.otpAutoDetectionTitle;
  static const otpVerifyingInProgress =
      BanayAuthLocalizationKeys.otpVerifyingInProgress;
  static const newOtpSent = BanayAuthLocalizationKeys.newOtpSent;
  static const addValidName = BanayAuthLocalizationKeys.addValidName;
  static const almostThere = BanayAuthLocalizationKeys.almostThere;
  static const addNamePicture = BanayAuthLocalizationKeys.addNamePicture;
  static const yourName = BanayAuthLocalizationKeys.yourName;
  static const connecting = BanayAuthLocalizationKeys.connecting;
  static const locationPermissionBlockedTitle =
      BanayLocationLocalizationKeys.locationPermissionBlockedTitle;
  static const enableLocationTitle =
      BanayLocationLocalizationKeys.enableLocationTitle;
  static const locationPermissionBlockedBody =
      BanayLocationLocalizationKeys.locationPermissionBlockedBody;
  static const locationPermissionBody =
      BanayLocationLocalizationKeys.locationPermissionBody;
  static const locationInfoNearby =
      BanayLocationLocalizationKeys.locationInfoNearby;
  static const locationInfoDelivery =
      BanayLocationLocalizationKeys.locationInfoDelivery;
  static const locationInfoBlocked =
      BanayLocationLocalizationKeys.locationInfoBlocked;
  static const locationInfoUsage =
      BanayLocationLocalizationKeys.locationInfoUsage;
}

class BanayLocalizations {
  BanayLocalizations(this.locale);

  final Locale locale;

  static const List<Locale> supportedLocales = [
    Locale('mg'),
    Locale('en'),
    Locale('fr'),
    Locale('zh'),
    Locale('hi'),
    Locale('es'),
    Locale('ar'),
  ];

  static BanayLocalizations of(BuildContext context) {
    final localizations = Localizations.of<BanayLocalizations>(
      context,
      BanayLocalizations,
    );
    return localizations ?? BanayLocalizations(const Locale('en'));
  }

  String tr(String key, {Map<String, String>? params}) {
    final languageCode = locale.languageCode;
    final values = _localizedValues[languageCode] ?? _localizedValues['en']!;
    var text = values[key] ?? _localizedValues['en']![key] ?? key;

    params?.forEach((paramKey, paramValue) {
      text = text.replaceAll('{$paramKey}', paramValue);
    });

    return text;
  }

  static final Map<String, Map<String, String>> _localizedValues =
      _buildLocalizedValues();

  static Map<String, Map<String, String>> _buildLocalizedValues() {
    final localeCodes = <String>{
      ...banayCommonLocalizedValues.keys,
      ...banayAuthLocalizedValues.keys,
      ...banayLocationLocalizedValues.keys,
    };

    return {
      for (final localeCode in localeCodes)
        localeCode: {
          ...?banayCommonLocalizedValues[localeCode],
          ...?banayAuthLocalizedValues[localeCode],
          ...?banayLocationLocalizedValues[localeCode],
        },
    };
  }
}

extension BanayLocalizationContext on BuildContext {
  String tr(String key, {Map<String, String>? params}) {
    return BanayLocalizations.of(this).tr(key, params: params);
  }
}
