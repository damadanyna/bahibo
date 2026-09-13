import 'package:banay/component/profile_models.dart';
import 'package:banay/component/seller_profile_page.dart';
import 'package:banay/component/user_profile_page.dart';
import 'package:banay/services/catalog_api_service.dart';
import 'package:banay/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';

/// Opens [userId]'s public profile: the seller page when the account is a
/// seller with a shop, the plain user page otherwise. The route shows a
/// spinner while the profile loads, so the tap answers at once.
void pushUserProfileById(
  BuildContext context,
  String userId, {
  CatalogApiService? api,
}) {
  final id = userId.trim();
  if (id.isEmpty) {
    return;
  }
  final catalog = api ?? CatalogApiService();
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => FutureBuilder<Map<String, dynamic>>(
        future: catalog.fetchUserProfile(id),
        builder: (context, snapshot) {
          final theme = Theme.of(context);
          if (snapshot.hasError) {
            return Scaffold(
              backgroundColor: theme.appColors.backgroundBase,
              appBar: AppBar(backgroundColor: Colors.transparent),
              body: Center(
                child: Text(
                  'Profil indisponible pour le moment.',
                  style: TextStyle(
                    color: theme.appColors.mutedText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return Scaffold(
              backgroundColor: theme.appColors.backgroundBase,
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          final data = snapshot.data!;
          final profile = buildPublicUserProfileFromApi(data);
          final role = (data['role'] as String?)?.trim().toUpperCase() ?? '';
          if (role == 'SELLER' &&
              (profile.sellerProfileId?.isNotEmpty == true)) {
            return SellerProfilePage(profile: profile);
          }
          return UserProfilePage(profile: profile);
        },
      ),
    ),
  );
}
