class UserProfileData {
  final String? userId;
  final String name;
  final String avatarUrl;
  final String coverImageUrl;
  final String roleLabel;
  final String responseLabel;
  final String headline;
  final String about;
  final String followerCount;
  final String visitorCount;
  final String productCount;
  final String totalLikesCount;
  final String rating;
  final List<Map<String, dynamic>> products;

  const UserProfileData({
    this.userId,
    required this.name,
    required this.avatarUrl,
    required this.coverImageUrl,
    required this.roleLabel,
    required this.responseLabel,
    required this.headline,
    required this.about,
    required this.followerCount,
    required this.visitorCount,
    this.productCount = '0',
    this.totalLikesCount = '0',
    required this.rating,
    required this.products,
  });
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

  String about = 'Boutique Bahibo active sur la plateforme.';
  String displayLabel = displayName;
  String followerCount = '0';
  String visitorCount = '0';
  String productCount = '0';
  String totalLikesCount = '0';

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
        name: displayLabel.isNotEmpty ? displayLabel : 'Boutique Bahibo',
        avatarUrl: avatarUrl,
        coverImageUrl: coverImageUrl,
        roleLabel: 'Vendeur certifie',
        responseLabel: 'Profil actif',
        headline: locationLabel.isNotEmpty
            ? locationLabel
            : 'Boutique Bahibo active',
        about: about,
        followerCount: followerCount,
        visitorCount: visitorCount,
        productCount: productCount,
        totalLikesCount: totalLikesCount,
        rating: '0.0',
        products: sellerProducts
            .whereType<Map>()
            .map((product) => Map<String, dynamic>.from(product))
            .toList(),
      );
    }
  }

  if (sellerStats is Map) {
    followerCount = '${sellerStats['followerCount'] ?? 0}';
    visitorCount = '${sellerStats['profileViewCount'] ?? 0}';
    productCount = '${sellerStats['productCount'] ?? 0}';
    totalLikesCount = '${sellerStats['totalLikesCount'] ?? 0}';
  }

  return UserProfileData(
    userId: user['id'] as String?,
    name: displayLabel.isNotEmpty ? displayLabel : 'Boutique Bahibo',
    avatarUrl: avatarUrl,
    coverImageUrl: coverImageUrl,
    roleLabel: 'Vendeur certifie',
    responseLabel: 'Profil actif',
    headline: locationLabel.isNotEmpty
        ? locationLabel
        : 'Boutique Bahibo active',
    about: about,
    followerCount: followerCount,
    visitorCount: visitorCount,
    productCount: productCount,
    totalLikesCount: totalLikesCount,
    rating: '0.0',
    products: const [],
  );
}

UserProfileData defaultSellerProfileData() {
  return UserProfileData(
    name: 'John Rakoto',
    avatarUrl:
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=600',
    coverImageUrl:
        'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=1600',
    roleLabel: 'Vendeur certifie',
    responseLabel: 'Repond vite',
    headline: 'Marketplace mobile · Antananarivo · En ligne aujourd\'hui',
    about:
        'Specialiste des smartphones premium et reconditionnes. Je teste chaque appareil avant vente et je peux envoyer des photos/video supplementaires sur demande.',
    followerCount: '12.4k',
    visitorCount: '248',
    productCount: '2',
    totalLikesCount: '9.2k',
    rating: '4.9',
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
    name: name,
    avatarUrl: avatarUrl,
    coverImageUrl:
        'https://images.unsplash.com/photo-1520607162513-77705c0f0d4a?w=1600',
    roleLabel: 'Membre verifie',
    responseLabel: 'Profil actif',
    headline: subtitle,
    about:
        '$name consulte regulierement les annonces mobiles et interagit avec la communaute Bahibo.',
    followerCount: '1.2k',
    visitorCount: '86',
    productCount: '2',
    totalLikesCount: '0',
    rating: '4.7',
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
