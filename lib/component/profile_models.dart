class UserProfileData {
  final String? userId;
  final String? sellerProfileId;
  final String? profileCreatedAt;
  final String? accountCreatedAt;
  final String? lastSeenAt;
  final String name;
  final String avatarUrl;
  final String coverImageUrl;
  final String roleLabel;
  final String responseLabel;
  final String headline;
  final String about;
  final String? phoneE164;
  final String followerCount;
  final String visitorCount;
  final String productCount;
  final String totalLikesCount;
  final String rating;
  final bool isFollowing;
  final bool isVerified;
  final bool isSellerCertified;
  final String sellerVerificationRequestStatus;
  final String? sellerVerificationRequestedAt;
  final String? sellerVerificationReviewedAt;
  final List<Map<String, dynamic>> products;

  const UserProfileData({
    this.userId,
    this.sellerProfileId,
    this.profileCreatedAt,
    this.accountCreatedAt,
    this.lastSeenAt,
    required this.name,
    required this.avatarUrl,
    required this.coverImageUrl,
    required this.roleLabel,
    required this.responseLabel,
    required this.headline,
    required this.about,
    this.phoneE164,
    required this.followerCount,
    required this.visitorCount,
    this.productCount = '0',
    this.totalLikesCount = '0',
    required this.rating,
    this.isFollowing = false,
    this.isVerified = false,
    this.isSellerCertified = false,
    this.sellerVerificationRequestStatus = 'NONE',
    this.sellerVerificationRequestedAt,
    this.sellerVerificationReviewedAt,
    required this.products,
  });
}

UserProfileData buildSellerProfileFromApi(Map<String, dynamic> data) {
  final owner = Map<String, dynamic>.from(
    (data['owner'] as Map?) ?? const <String, dynamic>{},
  );
  final sellerStats = Map<String, dynamic>.from(
    (data['sellerStats'] as Map?) ?? const <String, dynamic>{},
  );
  final products = ((data['products'] as List?) ?? const [])
      .whereType<Map>()
      .map((product) => Map<String, dynamic>.from(product))
      .toList();
  final city = (data['city'] as String?)?.trim() ?? '';
  final country = (data['country'] as String?)?.trim() ?? '';
  final headlineParts = [
    city,
    country,
  ].where((value) => value.isNotEmpty).toList();
  final exactLocationLabel = (owner['locationLabel'] as String?)?.trim() ?? '';
  final phoneE164 = (owner['phoneE164'] as String?)?.trim() ?? '';
  final isSellerCertified = data['isSellerCertified'] as bool? ?? false;

  return UserProfileData(
    userId: owner['userId'] as String?,
    sellerProfileId: data['id'] as String?,
    profileCreatedAt: data['createdAt'] as String?,
    accountCreatedAt: owner['createdAt'] as String?,
    lastSeenAt: owner['lastSeenAt'] as String?,
    name: (data['studioName'] as String?)?.trim().isNotEmpty == true
        ? (data['studioName'] as String).trim()
        : ((owner['displayName'] as String?)?.trim().isNotEmpty == true
              ? (owner['displayName'] as String).trim()
              : 'Boutique BANAY'),
    avatarUrl: (owner['avatarUrl'] as String?) ?? '',
    coverImageUrl: (owner['coverImageUrl'] as String?) ?? '',
    roleLabel: isSellerCertified ? 'Vendeur certifie' : 'Vendeur',
    responseLabel: 'Profil actif',
    headline: exactLocationLabel.isNotEmpty
        ? exactLocationLabel
        : (headlineParts.isNotEmpty
              ? headlineParts.join(', ')
              : 'Boutique BANAY active'),
    about: (data['description'] as String?)?.trim().isNotEmpty == true
        ? (data['description'] as String).trim()
        : 'Boutique BANAY active sur la plateforme.',
    phoneE164: phoneE164.isNotEmpty ? phoneE164 : null,
    followerCount: '${sellerStats['followerCount'] ?? 0}',
    visitorCount: '${sellerStats['profileViewCount'] ?? 0}',
    productCount: '${sellerStats['productCount'] ?? products.length}',
    totalLikesCount: '${sellerStats['totalLikesCount'] ?? 0}',
    rating: '0.0',
    isFollowing: data['isFollowing'] as bool? ?? false,
    isVerified: data['isVerified'] as bool? ?? false,
    isSellerCertified: isSellerCertified,
    products: products,
  );
}

UserProfileData buildSellerAccountProfileFromCurrentUser(
  Map<String, dynamic> user,
) {
  final displayName = (user['displayName'] as String?)?.trim() ?? '';
  final avatarUrl = (user['avatarUrl'] as String?)?.trim() ?? '';
  final coverImageUrl = (user['coverImageUrl'] as String?)?.trim() ?? '';
  final locationLabel = (user['locationLabel'] as String?)?.trim() ?? '';
  final sellerProfile = user['sellerProfile'];
  final sellerStats = user['sellerStats'];
  final isVerified = user['isVerified'] as bool? ?? false;
  final isSellerCertified = user['isSellerCertified'] as bool? ?? false;
  final sellerVerificationRequestStatus =
      (user['sellerVerificationRequestStatus'] as String?)?.trim() ?? 'NONE';
  final sellerVerificationRequestedAt =
      user['sellerVerificationRequestedAt'] as String?;
  final sellerVerificationReviewedAt =
      user['sellerVerificationReviewedAt'] as String?;

  String about = 'Boutique BANAY active sur la plateforme.';
  String displayLabel = displayName;
  String followerCount = '0';
  String visitorCount = '0';
  String productCount = '0';
  String totalLikesCount = '0';

  if (sellerStats is Map) {
    followerCount = '${sellerStats['followerCount'] ?? 0}';
    visitorCount = '${sellerStats['profileViewCount'] ?? 0}';
    productCount = '${sellerStats['productCount'] ?? 0}';
    totalLikesCount = '${sellerStats['totalLikesCount'] ?? 0}';
  }

  if (sellerProfile is Map) {
    final sellerStudioName = (sellerProfile['studioName'] as String?)?.trim();
    final sellerDescription = (sellerProfile['description'] as String?)?.trim();
    final sellerProducts = sellerProfile['products'];

    if (sellerStudioName != null && sellerStudioName.isNotEmpty) {
      displayLabel = sellerStudioName;
    }

    if (sellerDescription != null && sellerDescription.isNotEmpty) {
      about = sellerDescription;
    }

    if (sellerProducts is List) {
      return UserProfileData(
        userId: user['id'] as String?,
        sellerProfileId: sellerProfile['id'] as String?,
        profileCreatedAt: sellerProfile['createdAt'] as String?,
        accountCreatedAt: user['createdAt'] as String?,
        lastSeenAt: user['lastSeenAt'] as String?,
        name: displayLabel.isNotEmpty ? displayLabel : 'Boutique BANAY',
        avatarUrl: avatarUrl,
        coverImageUrl: coverImageUrl,
        roleLabel: isSellerCertified ? 'Vendeur certifie' : 'Vendeur',
        responseLabel: 'Profil actif',
        headline: locationLabel.isNotEmpty
            ? locationLabel
            : 'Boutique BANAY active',
        about: about,
        followerCount: followerCount,
        visitorCount: visitorCount,
        productCount: productCount,
        totalLikesCount: totalLikesCount,
        rating: '0.0',
        isFollowing: false,
        isVerified: isVerified,
        isSellerCertified: isSellerCertified,
        sellerVerificationRequestStatus: sellerVerificationRequestStatus,
        sellerVerificationRequestedAt: sellerVerificationRequestedAt,
        sellerVerificationReviewedAt: sellerVerificationReviewedAt,
        products: sellerProducts
            .whereType<Map>()
            .map((product) => Map<String, dynamic>.from(product))
            .toList(),
      );
    }
  }

  return UserProfileData(
    userId: user['id'] as String?,
    sellerProfileId: sellerProfile is Map
        ? sellerProfile['id'] as String?
        : null,
    profileCreatedAt: sellerProfile is Map
        ? sellerProfile['createdAt'] as String?
        : null,
    accountCreatedAt: user['createdAt'] as String?,
    lastSeenAt: user['lastSeenAt'] as String?,
    name: displayLabel.isNotEmpty ? displayLabel : 'Boutique BANAY',
    avatarUrl: avatarUrl,
    coverImageUrl: coverImageUrl,
    roleLabel: isSellerCertified ? 'Vendeur certifie' : 'Vendeur',
    responseLabel: 'Profil actif',
    headline: locationLabel.isNotEmpty
        ? locationLabel
        : 'Boutique BANAY active',
    about: about,
    followerCount: followerCount,
    visitorCount: visitorCount,
    productCount: productCount,
    totalLikesCount: totalLikesCount,
    rating: '0.0',
    isFollowing: false,
    isVerified: isVerified,
    isSellerCertified: isSellerCertified,
    sellerVerificationRequestStatus: sellerVerificationRequestStatus,
    sellerVerificationRequestedAt: sellerVerificationRequestedAt,
    sellerVerificationReviewedAt: sellerVerificationReviewedAt,
    products: const [],
  );
}

UserProfileData buildPublicUserProfileFromApi(Map<String, dynamic> data) {
  final sellerStats = Map<String, dynamic>.from(
    (data['sellerStats'] as Map?) ?? const <String, dynamic>{},
  );
  final sellerProfile = data['sellerProfile'];
  final role = (data['role'] as String?)?.trim() ?? 'CUSTOMER';
  final isVerified = data['isVerified'] as bool? ?? false;
  final isSellerCertified = data['isSellerCertified'] as bool? ?? false;
  final locationLabel = (data['locationLabel'] as String?)?.trim() ?? '';
  final phoneE164 = (data['phoneE164'] as String?)?.trim() ?? '';
  final sellerDescription = sellerProfile is Map
      ? (sellerProfile['description'] as String?)?.trim() ?? ''
      : '';

  return UserProfileData(
    userId: data['id'] as String?,
    sellerProfileId: sellerProfile is Map
        ? sellerProfile['id'] as String?
        : null,
    profileCreatedAt: data['createdAt'] as String?,
    accountCreatedAt: data['createdAt'] as String?,
    name: (data['displayName'] as String?)?.trim().isNotEmpty == true
        ? (data['displayName'] as String).trim()
        : 'Utilisateur BANAY',
    avatarUrl: (data['avatarUrl'] as String?) ?? '',
    coverImageUrl: (data['coverImageUrl'] as String?) ?? '',
    roleLabel: role == 'SELLER'
        ? (isSellerCertified ? 'Vendeur certifie' : 'Vendeur')
        : (isVerified ? 'Utilisateur verifie' : 'Utilisateur'),
    responseLabel: 'Profil actif',
    headline: locationLabel.isNotEmpty
        ? locationLabel
        : 'Membre de la communaute BANAY',
    about: sellerDescription.isNotEmpty
        ? sellerDescription
        : 'Membre BANAY actif sur la plateforme.',
    phoneE164: phoneE164.isNotEmpty ? phoneE164 : null,
    followerCount: '${sellerStats['followerCount'] ?? 0}',
    visitorCount: '${sellerStats['profileViewCount'] ?? 0}',
    productCount: '${sellerStats['productCount'] ?? 0}',
    totalLikesCount: '${sellerStats['totalLikesCount'] ?? 0}',
    rating: '0.0',
    isFollowing: false,
    isVerified: isVerified,
    isSellerCertified: isSellerCertified,
    products: const [],
  );
}

UserProfileData defaultSellerProfileData() {
  return UserProfileData(
    sellerProfileId: null,
    name: 'John Rakoto',
    avatarUrl:
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=600',
    coverImageUrl:
        'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=1600',
    roleLabel: 'Vendeur',
    responseLabel: 'Repond vite',
    headline: 'Marketplace mobile · Antananarivo · En ligne aujourd\'hui',
    about:
        'Specialiste des smartphones premium et reconditionnes. Je teste chaque appareil avant vente et je peux envoyer des photos/video supplementaires sur demande.',
    followerCount: '12.4k',
    visitorCount: '248',
    productCount: '2',
    totalLikesCount: '9.2k',
    rating: '4.9',
    isFollowing: false,
    isSellerCertified: false,
    products: [
      {
        'title': 'Samsung Galaxy S20',
        'category': 'Produit Verifie',
        'price': 2375,
        'images': [
          'https://images.unsplash.com/photo-1598327105666-5b89351aff97?w=800',
        ],
        'thumbnail':
            'https://images.unsplash.com/photo-1598327105666-5b89351aff97?w=800',
      },
      {
        'title': 'iPhone XR',
        'category': 'Produit Verifie',
        'price': 1875,
        'images': [
          'https://images.unsplash.com/photo-1556656793-08538906a9f8?w=800',
        ],
        'thumbnail':
            'https://images.unsplash.com/photo-1556656793-08538906a9f8?w=800',
      },
    ],
  );
}

UserProfileData buildProfileFromUser({
  String? userId,
  required String name,
  required String avatarUrl,
  required String subtitle,
}) {
  return UserProfileData(
    userId: userId,
    sellerProfileId: null,
    name: name,
    avatarUrl: avatarUrl,
    lastSeenAt: null,
    coverImageUrl:
        'https://images.unsplash.com/photo-1520607162513-77705c0f0d4a?w=1600',
    roleLabel: 'Membre verifie',
    responseLabel: 'Profil actif',
    headline: subtitle,
    about:
        '$name consulte regulierement les annonces mobiles et interagit avec la communaute BANAY.',
    followerCount: '1.2k',
    visitorCount: '86',
    productCount: '2',
    totalLikesCount: '0',
    rating: '4.7',
    isFollowing: false,
    isVerified: true,
    products: [
      {
        'title': 'iPhone 13 Mini',
        'category': 'Produit Verifie',
        'price': 2100,
        'images': [
          'https://images.unsplash.com/photo-1632661674596-df8be070a5c5?w=800',
        ],
        'thumbnail':
            'https://images.unsplash.com/photo-1632661674596-df8be070a5c5?w=800',
      },
      {
        'title': 'Redmi Note 12',
        'category': 'Disponible',
        'price': 980,
        'images': [
          'https://images.unsplash.com/photo-1678911820864-e552cd9ca9ae?w=800',
        ],
        'thumbnail':
            'https://images.unsplash.com/photo-1678911820864-e552cd9ca9ae?w=800',
      },
    ],
  );
}


