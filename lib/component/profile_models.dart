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
    required this.rating,
    required this.products,
  });
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
