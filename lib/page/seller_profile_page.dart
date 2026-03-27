import 'package:flutter/material.dart';
import 'package:bahibo/component/ProductCard.dart';
import 'package:bahibo/page/image_viewer_page.dart';
import 'package:bahibo/page/seller_chat_page.dart';
import 'package:bahibo/page/user_list_page.dart';

class SellerProfilePage extends StatelessWidget {
  const SellerProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryGreen = theme.colorScheme.primary;
    final softGreen = isDark
        ? const Color(0xFF173328)
        : const Color(0xFFE8F5EC);
    final deepGreen = isDark
        ? const Color(0xFF7DFFB0)
        : const Color(0xFF1E8E3E);
    const sellerImageUrl =
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=600';
    const coverImageUrl =
        'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=1600';
    final List<Map<String, dynamic>> sellerProducts = [
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
    ];
    final backgroundColor = isDark
        ? const Color(0xFF0E1712)
        : const Color(0xFFF2F8F3);
    final surfaceColor = isDark ? const Color(0xFF171C22) : Colors.white;
    final mutedColor = isDark
        ? Colors.white70
        : const Color.fromARGB(255, 125, 92, 93);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
            children: [
              _buildProfileHeader(
                context,
                sellerImageUrl: sellerImageUrl,
                coverImageUrl: coverImageUrl,
                surfaceColor: surfaceColor,
                mutedColor: mutedColor,
                primaryGreen: primaryGreen,
                softGreen: softGreen,
                deepGreen: deepGreen,
              ),
              const SizedBox(height: 16),
              _buildQuickStats(context, surfaceColor, mutedColor, primaryGreen),
              const SizedBox(height: 16),
              _buildAboutCard(surfaceColor, mutedColor),
              const SizedBox(height: 16),
              _buildFilterRow(isDark),
              const SizedBox(height: 12),
              _buildSectionHeader('Annonces publiees', '12 annonces'),
              const SizedBox(height: 8),
              ProductCard(product: sellerProducts[0]),
              const SizedBox(height: 10),
              ProductCard(product: sellerProducts[1]),
            ],
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(999),
                child: Ink(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.28),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('Madagascar', hasArrow: true, isDark: isDark),
          const SizedBox(width: 8),
          _filterChip('Disponible', isDark: isDark),
          const SizedBox(width: 8),
          _filterChip('Reconditionne', isDark: isDark),
          const SizedBox(width: 8),
          _filterChip('Livraison', isDark: isDark),
        ],
      ),
    );
  }

  Widget _filterChip(
    String text, {
    bool hasArrow = false,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFB7F5CA) : const Color(0xFF256B3C),
            ),
          ),
          if (hasArrow) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 14,
              color: isDark ? const Color(0xFFB7F5CA) : const Color(0xFF256B3C),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context, {
    required String sellerImageUrl,
    required String coverImageUrl,
    required Color surfaceColor,
    required Color mutedColor,
    required Color primaryGreen,
    required Color softGreen,
    required Color deepGreen,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.25)
                : const Color(0x14000000),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: SizedBox(
                  height: 170,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(coverImageUrl, fit: BoxFit.cover),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              primaryGreen.withOpacity(0.12),
                              const Color(0xFF0F2F1B).withOpacity(0.70),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                bottom: -38,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ImageViewerPage(
                          imageUrls: [sellerImageUrl],
                          initialIndex: 0,
                          heroTag: 'seller-avatar-profile',
                        ),
                      ),
                    );
                  },
                  child: Hero(
                    tag: 'seller-avatar-profile',
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 42,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: NetworkImage(sellerImageUrl),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.photo_camera_outlined,
                        color: Colors.white,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Galerie',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'John Rakoto',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: softGreen,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified,
                                      size: 16,
                                      color: deepGreen,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Vendeur certifie',
                                      style: TextStyle(
                                        color: deepGreen,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: softGreen,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Repond vite',
                                  style: TextStyle(
                                    color: deepGreen,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Marketplace mobile · Antananarivo · En ligne aujourd\'hui',
                            style: TextStyle(
                              color: mutedColor,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2ECC71),
                        shape: BoxShape.circle,
                        border: Border.all(color: surfaceColor, width: 2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SellerChatPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.message_outlined, size: 18),
                        label: const Text('Message'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.person_add_alt_1, size: 18),
                        label: const Text("S'abonner"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white : Colors.black,
                          side: BorderSide(
                            color: isDark
                                ? Colors.grey.shade700
                                : Colors.grey.shade300,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(
    BuildContext context,
    Color surfaceColor,
    Color mutedColor,
    Color primaryGreen,
  ) {
    const followers = [
      UserListItemData(
        name: 'Miora Andrianiaina',
        subtitle: 'Suit la boutique depuis 8 mois',
        imageUrl:
            'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200',
        trailingText: 'Abonne',
      ),
      UserListItemData(
        name: 'Toky Rajaonarison',
        subtitle: 'Acheteur regulier',
        imageUrl:
            'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200',
        trailingText: 'Abonne',
      ),
      UserListItemData(
        name: 'Aina Ravelona',
        subtitle: 'Suit les nouveautes smartphone',
        imageUrl:
            'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=200',
        trailingText: 'Abonne',
      ),
    ];
    const visitors = [
      UserListItemData(
        name: 'Feno Nantenaina',
        subtitle: 'A visite le profil aujourd\'hui',
        imageUrl:
            'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=200',
        trailingText: 'Aujourd\'hui',
      ),
      UserListItemData(
        name: 'Sarah R.',
        subtitle: 'A consulte 3 annonces cette semaine',
        imageUrl:
            'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=200',
        trailingText: '3 vues',
      ),
      UserListItemData(
        name: 'Kevin M.',
        subtitle: 'Interessé par les iPhone',
        imageUrl:
            'https://images.unsplash.com/photo-1504593811423-6dd665756598?w=200',
        trailingText: 'Recurrent',
      ),
    ];
    const ratings = [
      UserListItemData(
        name: 'Nadia',
        subtitle: 'Transaction rapide et produit conforme',
        imageUrl:
            'https://images.unsplash.com/photo-1488426862026-3ee34a7d66df?w=200',
        trailingText: '5.0',
      ),
      UserListItemData(
        name: 'Bryan',
        subtitle: 'Tres bon vendeur, communication claire',
        imageUrl:
            'https://images.unsplash.com/photo-1504257432389-52343af06ae3?w=200',
        trailingText: '4.8',
      ),
      UserListItemData(
        name: 'Elinah',
        subtitle: 'Telephone nickel, recommande',
        imageUrl:
            'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=200',
        trailingText: '4.9',
      ),
    ];

    return Row(
      children: [
        Expanded(
          child: _statCard(
            context: context,
            surfaceColor: surfaceColor,
            label: 'Abonnes',
            value: '12.4k',
            icon: Icons.groups_2_outlined,
            accent: primaryGreen,
            mutedColor: mutedColor,
            pageTitle: 'Abonnes',
            users: followers,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            context: context,
            surfaceColor: surfaceColor,
            label: 'Visiteurs',
            value: '248',
            icon: Icons.sell_outlined,
            accent: const Color(0xFF2ECC71),
            mutedColor: mutedColor,
            pageTitle: 'Visiteurs',
            users: visitors,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            context: context,
            surfaceColor: surfaceColor,
            label: 'Note',
            value: '4.9',
            icon: Icons.star_outline,
            accent: const Color(0xFF66BB6A),
            mutedColor: mutedColor,
            pageTitle: 'Avis et notes',
            users: ratings,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required BuildContext context,
    required Color surfaceColor,
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
    required Color mutedColor,
    required String pageTitle,
    required List<UserListItemData> users,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserListPage(title: pageTitle, users: users),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: mutedColor, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutCard(Color surfaceColor, Color mutedColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'A propos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            'Specialiste des smartphones premium et reconditionnes. Je teste chaque appareil avant vente et je peux envoyer des photos/video supplementaires sur demande.',
            style: TextStyle(height: 1.5, color: mutedColor),
          ),
          const SizedBox(height: 14),
          _infoRow(
            Icons.location_on_outlined,
            'Antananarivo, Madagascar',
            mutedColor,
          ),
          const SizedBox(height: 10),
          _infoRow(
            Icons.schedule_outlined,
            'Repond generalement en moins de 15 min',
            mutedColor,
          ),
          const SizedBox(height: 10),
          _infoRow(
            Icons.verified_user_outlined,
            'Profil actif depuis 2022',
            mutedColor,
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, Color mutedColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TextStyle(color: mutedColor, height: 1.4)),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String meta) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const Spacer(),
        Text(
          meta,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.green,
          ),
        ),
      ],
    );
  }
}
