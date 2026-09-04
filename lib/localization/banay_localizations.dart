import 'package:banay/localization/banay_localization_account.dart';
import 'package:banay/localization/banay_localization_account_keys.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:banay/localization/banay_localization_auth.dart';
import 'package:banay/localization/banay_localization_auth_keys.dart';
import 'package:banay/localization/banay_localization_common.dart';
import 'package:banay/localization/banay_localization_common_keys.dart';
import 'package:banay/localization/banay_localization_home.dart';
import 'package:banay/localization/banay_localization_home_keys.dart';
import 'package:banay/localization/banay_localization_search.dart';
import 'package:banay/localization/banay_localization_search_keys.dart';

abstract final class BanayLocalizationKeys {
  static const languagePageTitle = BanayAuthLocalizationKeys.languagePageTitle;
  static const languagePageSubtitle =
      BanayAuthLocalizationKeys.languagePageSubtitle;
  static const accountDefaultDisplayName =
      BanayAccountLocalizationKeys.defaultDisplayName;
  static const accountDayRemainingOne =
      BanayAccountLocalizationKeys.dayRemainingOne;
  static const accountDaysRemainingMany =
      BanayAccountLocalizationKeys.daysRemainingMany;
  static const accountDisplayNamePolicyFirstChange =
      BanayAccountLocalizationKeys.displayNamePolicyFirstChange;
  static const accountDisplayNamePolicyReady =
      BanayAccountLocalizationKeys.displayNamePolicyReady;
  static const accountDisplayNamePolicyCooldown =
      BanayAccountLocalizationKeys.displayNamePolicyCooldown;
  static const accountDisplayNameEditBlockedTitle =
      BanayAccountLocalizationKeys.displayNameEditBlockedTitle;
  static const accountDisplayNameEditBlockedBody =
      BanayAccountLocalizationKeys.displayNameEditBlockedBody;
  static const accountCloseAction = BanayAccountLocalizationKeys.closeAction;
  static const accountDisplayNameNextChangeHintFirst =
      BanayAccountLocalizationKeys.displayNameNextChangeHintFirst;
  static const accountDisplayNameNextChangeHintAfter =
      BanayAccountLocalizationKeys.displayNameNextChangeHintAfter;
  static const accountDisplayNameEditTitle =
      BanayAccountLocalizationKeys.displayNameEditTitle;
  static const accountDisplayNameFieldLabel =
      BanayAccountLocalizationKeys.displayNameFieldLabel;
  static const accountDisplayNameFieldHint =
      BanayAccountLocalizationKeys.displayNameFieldHint;
  static const accountCancelAction = BanayAccountLocalizationKeys.cancelAction;
  static const accountSaveAction = BanayAccountLocalizationKeys.saveAction;
  static const accountDisplayNameUpdated =
      BanayAccountLocalizationKeys.displayNameUpdated;
  static const accountDisplayNameUpdatedCooldown =
      BanayAccountLocalizationKeys.displayNameUpdatedCooldown;
  static const accountLocationUnavailable =
      BanayAccountLocalizationKeys.locationUnavailable;
  static const accountLocationServicesDisabledTitle =
      BanayAccountLocalizationKeys.locationServicesDisabledTitle;
  static const accountLocationPermissionDeniedTitle =
      BanayAccountLocalizationKeys.locationPermissionDeniedTitle;
  static const accountLocationPermissionRequiredTitle =
      BanayAccountLocalizationKeys.locationPermissionRequiredTitle;
  static const accountLocationPreciseRequiredTitle =
      BanayAccountLocalizationKeys.locationPreciseRequiredTitle;
  static const accountLocationServicesDisabledMessage =
      BanayAccountLocalizationKeys.locationServicesDisabledMessage;
  static const accountLocationPermissionDeniedMessage =
      BanayAccountLocalizationKeys.locationPermissionDeniedMessage;
  static const accountLocationPermissionDeniedForeverMessage =
      BanayAccountLocalizationKeys.locationPermissionDeniedForeverMessage;
  static const accountLocationPreciseRequiredMessage =
      BanayAccountLocalizationKeys.locationPreciseRequiredMessage;
  static const accountOpenLocationSettings =
      BanayAccountLocalizationKeys.openLocationSettings;
  static const accountAllowNow = BanayAccountLocalizationKeys.allowNow;
  static const accountOpenAppSettings =
      BanayAccountLocalizationKeys.openAppSettings;
  static const accountRetryAction = BanayAccountLocalizationKeys.retryAction;
  static const accountReplaceCoverImage =
      BanayAccountLocalizationKeys.replaceCoverImage;
  static const accountReplaceAvatar =
      BanayAccountLocalizationKeys.replaceAvatar;
  static const accountTakePhoto = BanayAccountLocalizationKeys.takePhoto;
  static const accountChooseFromGallery =
      BanayAccountLocalizationKeys.chooseFromGallery;
  static const accountCoverImageUpdated =
      BanayAccountLocalizationKeys.coverImageUpdated;
  static const accountAvatarUpdated =
      BanayAccountLocalizationKeys.avatarUpdated;
  static const accountShopConfirmTitle =
      BanayAccountLocalizationKeys.shopConfirmTitle;
  static const accountShopConfirmBody =
      BanayAccountLocalizationKeys.shopConfirmBody;
  static const accountSendAction = BanayAccountLocalizationKeys.sendAction;
  static const accountShopRequestSent =
      BanayAccountLocalizationKeys.shopRequestSent;
  static const accountShopStatusActiveTitle =
      BanayAccountLocalizationKeys.shopStatusActiveTitle;
  static const accountShopStatusPendingTitle =
      BanayAccountLocalizationKeys.shopStatusPendingTitle;
  static const accountShopStatusApprovedTitle =
      BanayAccountLocalizationKeys.shopStatusApprovedTitle;
  static const accountShopStatusRejectedTitle =
      BanayAccountLocalizationKeys.shopStatusRejectedTitle;
  static const accountShopStatusDefaultTitle =
      BanayAccountLocalizationKeys.shopStatusDefaultTitle;
  static const accountShopStatusActiveDescription =
      BanayAccountLocalizationKeys.shopStatusActiveDescription;
  static const accountShopStatusPendingDescription =
      BanayAccountLocalizationKeys.shopStatusPendingDescription;
  static const accountShopStatusApprovedDescription =
      BanayAccountLocalizationKeys.shopStatusApprovedDescription;
  static const accountShopStatusRejectedDescription =
      BanayAccountLocalizationKeys.shopStatusRejectedDescription;
  static const accountShopStatusDefaultDescription =
      BanayAccountLocalizationKeys.shopStatusDefaultDescription;
  static const accountShopButtonActive =
      BanayAccountLocalizationKeys.shopButtonActive;
  static const accountShopButtonPending =
      BanayAccountLocalizationKeys.shopButtonPending;
  static const accountShopButtonApproved =
      BanayAccountLocalizationKeys.shopButtonApproved;
  static const accountShopButtonRejected =
      BanayAccountLocalizationKeys.shopButtonRejected;
  static const accountShopButtonDefault =
      BanayAccountLocalizationKeys.shopButtonDefault;
  static const accountProfileLoading =
      BanayAccountLocalizationKeys.profileLoading;
  static const accountImageUpdating =
      BanayAccountLocalizationKeys.imageUpdating;
  static const accountEditAction = BanayAccountLocalizationKeys.editAction;
  static const accountViewRuleAction =
      BanayAccountLocalizationKeys.viewRuleAction;
  static const accountLocationLoading =
      BanayAccountLocalizationKeys.locationLoading;
  static const continueAction = BanayCommonLocalizationKeys.continueAction;
  static const edit = BanayCommonLocalizationKeys.edit;
  static const yes = BanayCommonLocalizationKeys.yes;
  static const later = BanayCommonLocalizationKeys.later;
  static const allow = BanayCommonLocalizationKeys.allow;
  static const openSettings = BanayCommonLocalizationKeys.openSettings;
  static const navigationHome = BanayCommonLocalizationKeys.navigationHome;
  static const navigationSearch = BanayCommonLocalizationKeys.navigationSearch;
  static const navigationMessages =
      BanayCommonLocalizationKeys.navigationMessages;
  static const navigationAccount =
      BanayCommonLocalizationKeys.navigationAccount;
  static const backAgainToExit = BanayCommonLocalizationKeys.backAgainToExit;
  static const homeDefaultStoreName =
      BanayHomeLocalizationKeys.defaultStoreName;
  static const homeLiveUnavailable = BanayHomeLocalizationKeys.liveUnavailable;
  static const homeFollowedTitle = BanayHomeLocalizationKeys.followedTitle;
  static const homeFollowedEmptyTitle =
      BanayHomeLocalizationKeys.followedEmptyTitle;
  static const homeFollowedEmptyMessage =
      BanayHomeLocalizationKeys.followedEmptyMessage;
  static const homeNotificationsTooltip =
      BanayHomeLocalizationKeys.notificationsTooltip;
  static const homeLivekitConfigIncomplete =
      BanayHomeLocalizationKeys.livekitConfigIncomplete;
  static const homeCannotStartLive = BanayHomeLocalizationKeys.cannotStartLive;
  static const homeLiveDefaultTitle =
      BanayHomeLocalizationKeys.liveDefaultTitle;
  static const homeLiveDefaultCategory =
      BanayHomeLocalizationKeys.liveDefaultCategory;
  static const homeCreateLiveTitle = BanayHomeLocalizationKeys.createLiveTitle;
  static const homeCreateLiveSubtitle =
      BanayHomeLocalizationKeys.createLiveSubtitle;
  static const homeLiveTitleHint = BanayHomeLocalizationKeys.liveTitleHint;
  static const homeLiveCategoryHint =
      BanayHomeLocalizationKeys.liveCategoryHint;
  static const homeLiveTitleRequired =
      BanayHomeLocalizationKeys.liveTitleRequired;
  static const homeLiveCategoryRequired =
      BanayHomeLocalizationKeys.liveCategoryRequired;
  static const homeLaunchLive = BanayHomeLocalizationKeys.launchLive;
  static const homeStartLive = BanayHomeLocalizationKeys.startLive;
  static const homeNoMoreProducts = BanayHomeLocalizationKeys.noMoreProducts;
  static const homeFollowedMemberFallback =
      BanayHomeLocalizationKeys.followedMemberFallback;
  static const homeFollowedSubtitleFallback =
      BanayHomeLocalizationKeys.followedSubtitleFallback;
  static const homeFollowedSellerBadge =
      BanayHomeLocalizationKeys.followedSellerBadge;
  static const homeFollowedProfileBadge =
      BanayHomeLocalizationKeys.followedProfileBadge;
  static const homeFollowedLiveNow = BanayHomeLocalizationKeys.followedLiveNow;
  static const homeFollowedViewLive =
      BanayHomeLocalizationKeys.followedViewLive;
  static const homeFollowedViewProfile =
      BanayHomeLocalizationKeys.followedViewProfile;
  static const searchTitle = BanaySearchLocalizationKeys.searchTitle;
  static const searchHint = BanaySearchLocalizationKeys.searchHint;
  static const searchHideHistoryDialogTitle =
      BanaySearchLocalizationKeys.hideHistoryDialogTitle;
  static const searchHideHistoryDialogBody =
      BanaySearchLocalizationKeys.hideHistoryDialogBody;
  static const searchCancel = BanaySearchLocalizationKeys.cancel;
  static const searchDelete = BanaySearchLocalizationKeys.delete;
  static const searchNoSuggestions = BanaySearchLocalizationKeys.noSuggestions;
  static const searchSuggestionsTitle =
      BanaySearchLocalizationKeys.suggestionsTitle;
  static const searchAction = BanaySearchLocalizationKeys.searchAction;
  static const searchHistoryTitle = BanaySearchLocalizationKeys.historyTitle;
  static const searchHideHistoryTooltip =
      BanaySearchLocalizationKeys.hideHistoryTooltip;
  static const searchNoResults = BanaySearchLocalizationKeys.noResults;
  static const searchResultsFromDatabase =
      BanaySearchLocalizationKeys.resultsFromDatabase;
  static const searchResultsForQuery =
      BanaySearchLocalizationKeys.resultsForQuery;
  static const searchResultsSummary =
      BanaySearchLocalizationKeys.resultsSummary;
  static const searchTypeProduct = BanaySearchLocalizationKeys.typeProduct;
  static const searchTypeUser = BanaySearchLocalizationKeys.typeUser;
  static const searchTypeCategory = BanaySearchLocalizationKeys.typeCategory;
  static const searchTypeLocation = BanaySearchLocalizationKeys.typeLocation;
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
}

class BanayLocalizations {
  BanayLocalizations(this.locale);

  final Locale locale;

    static const LocalizationsDelegate<BanayLocalizations> delegate =
            _BanayLocalizationsDelegate();

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
      ...banayAccountLocalizedValues.keys,
      ...banayHomeLocalizedValues.keys,
      ...banaySearchLocalizedValues.keys,
      ...banayAuthLocalizedValues.keys,
    };

    return {
      for (final localeCode in localeCodes)
        localeCode: {
          ...?banayCommonLocalizedValues[localeCode],
          ...?banayAccountLocalizedValues[localeCode],
          ...?banayHomeLocalizedValues[localeCode],
          ...?banaySearchLocalizedValues[localeCode],
          ...?banayAuthLocalizedValues[localeCode],
        },
    };
  }
}

class _BanayLocalizationsDelegate
        extends LocalizationsDelegate<BanayLocalizations> {
    const _BanayLocalizationsDelegate();

    @override
    bool isSupported(Locale locale) {
        return BanayLocalizations.supportedLocales.any(
            (supportedLocale) => supportedLocale.languageCode == locale.languageCode,
        );
    }

    @override
    Future<BanayLocalizations> load(Locale locale) {
        return SynchronousFuture<BanayLocalizations>(BanayLocalizations(locale));
    }

    @override
    bool shouldReload(covariant LocalizationsDelegate<BanayLocalizations> old) {
        return false;
    }
}

extension BanayLocalizationContext on BuildContext {
  String tr(String key, {Map<String, String>? params}) {
    return BanayLocalizations.of(this).tr(key, params: params);
  }
}
