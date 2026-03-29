import 'package:bahibo/component/ProductCard.dart';
import 'package:bahibo/component/app_back_button.dart';
import 'package:bahibo/component/app_network_image.dart';
import 'package:bahibo/component/app_page_skeletons.dart';
import 'package:bahibo/component/app_page_refresh.dart';
import 'package:bahibo/component/profile_models.dart';
import 'package:bahibo/component/user_list_page.dart';
import 'package:bahibo/page/chat_page.dart';
import 'package:bahibo/page/image_viewer_page.dart';
import 'package:flutter/material.dart';

class SellerProfilePage extends StatefulWidget {
  final UserProfileData profile;

  const SellerProfilePage({super.key, required this.profile});

  @override
  State<SellerProfilePage> createState() => _SellerProfilePageState();
}

class _SellerProfilePageState extends State<SellerProfilePage>
    with AppPageRefreshMixin<SellerProfilePage> {
  bool _showEntrySkeleton = true;

  UserProfileData get profile => widget.profile;

  @override
  void initState() {
    super.initState();
    initializePageRefresh();
    Future.delayed(const Duration(milliseconds: 240), () {
      if (!mounted) return;
      setState(() => _showEntrySkeleton = false);
    });
  }

  @override
  void dispose() {
    disposePageRefresh();
    super.dispose();
  }

  @override
  Future<void> onPageReload() async {
    if (mounted) {
      setState(() => _showEntrySkeleton = true);
    }
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() => _showEntrySkeleton = false);
  }

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
    final backgroundColor = isDark
        ? const Color(0xFF0E1712)
        : const Color(0xFFF2F8F3);
    final surfaceColor = isDark ? const Color(0xFF222120) : Colors.white;
    final elevatedSurfaceColor = isDark
        ? const Color(0xFF111E1A)
        : const Color(0xFFF7FBF8);
    final mutedColor = isDark
        ? Colors.white70
        : const Color.fromARGB(255, 125, 92, 93);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: refreshPageWithDialog,
            child: _showEntrySkeleton
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [SellerProfileSkeleton()],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                    children: [
                      _buildProfileHeader(
                        context,
                        surfaceColor: surfaceColor,
                        elevatedSurfaceColor: elevatedSurfaceColor,
                        mutedColor: mutedColor,
                        primaryGreen: primaryGreen,
                        softGreen: softGreen,
                        deepGreen: deepGreen,
                      ),
                      const SizedBox(height: 16),
                      _buildQuickStats(
                        context,
                        surfaceColor,
                        mutedColor,
                        primaryGreen,
                      ),
                      const SizedBox(height: 18),
                      _buildSectionHeader(
                        'Annonces publiees',
                        '${profile.products.length} annonces',
                      ),
                      const SizedBox(height: 10),
                      _buildFilterRow(isDark),
                      const SizedBox(height: 8),
                      ..._buildProductCards(),
                    ],
                  ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 24,
            child: AppBackButton(onTap: () => _showExitDialog(context)),
          ),
          if (isOffline) const AppOfflineBanner(),
        ],
      ),
    );
  }

  Future<void> _showExitDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF222120) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Quitter ce profil ?',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF12201B),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Vous allez revenir a la page precedente.',
            style: TextStyle(
              color: isDark ? Colors.white70 : const Color(0xFF5D6C66),
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Quitter'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAboutDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF222120) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'A propos',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF12201B),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.about,
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF5D6C66),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              _dialogInfoRow(
                Icons.location_on_outlined,
                'Antananarivo, Madagascar',
                isDark,
              ),
              const SizedBox(height: 10),
              _dialogInfoRow(
                Icons.schedule_outlined,
                'Repond generalement en moins de 15 min',
                isDark,
              ),
              const SizedBox(height: 10),
              _dialogInfoRow(
                Icons.verified_user_outlined,
                'Profil actif depuis 2022',
                isDark,
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  Widget _dialogInfoRow(IconData icon, String text, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: isDark ? Colors.white70 : Colors.black54),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: isDark ? Colors.white70 : const Color(0xFF5D6C66),
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildProductCards() {
    final widgets = <Widget>[];
    for (var index = 0; index < profile.products.length; index++) {
      widgets.add(ProductCard(product: profile.products[index]));
      if (index != profile.products.length - 1) {
        widgets.add(const SizedBox(height: 10));
      }
    }
    return widgets;
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
          _filterChip('Recents', isDark: isDark),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF222120) : Colors.white,
        borderRadius: BorderRadius.circular(999),
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
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFB7F5CA) : const Color(0xFF256B3C),
            ),
          ),
          if (hasArrow) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: isDark ? const Color(0xFFB7F5CA) : const Color(0xFF256B3C),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context, {
    required Color surfaceColor,
    required Color elevatedSurfaceColor,
    required Color mutedColor,
    required Color primaryGreen,
    required Color softGreen,
    required Color deepGreen,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: AppNetworkImage(
                imageUrl: profile.coverImageUrl,
                fit: BoxFit.cover,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF091A14).withOpacity(isDark ? 0.38 : 0.28),
                    const Color(0xFF0E241B).withOpacity(isDark ? 0.82 : 0.68),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ImageViewerPage(
                                  imageUrls: [profile.avatarUrl],
                                  initialIndex: 0,
                                  heroTag: 'profile-avatar-${profile.name}',
                                  onSellerMessageTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const ChatPage(),
                                      ),
                                    );
                                  },
                                  overlay: ImageViewerOverlayData(
                                    title: profile.name,
                                    description: profile.headline,
                                    sellerName: profile.name,
                                    sellerAvatarUrl: profile.avatarUrl,
                                    sellerBadge: profile.roleLabel,
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Hero(
                            tag: 'profile-avatar-${profile.name}',
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.16),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white24),
                              ),
                              child: AppCircleNetworkAvatar(
                                radius: 34,
                                imageUrl: profile.avatarUrl,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      profile.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.circle,
                                          size: 10,
                                          color: Color(0xFF7DFFB0),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'En ligne',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                profile.headline,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.82),
                                  height: 1.35,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildHeaderPill(
                                    icon: Icons.verified_rounded,
                                    label: profile.roleLabel,
                                  ),
                                  _buildHeaderPill(
                                    icon: Icons.flash_on_rounded,
                                    label: profile.responseLabel,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                      child: InkWell(
                        onTap: () => _showAboutDialog(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Ink(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: elevatedSurfaceColor.withOpacity(
                              isDark ? 0.92 : 0.88,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white10
                                  : const Color(0x1A000000),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildFeatureTile(
                                      icon: Icons.location_on_outlined,
                                      label: 'Zone',
                                      value: 'Antananarivo',
                                      valueColor: isDark
                                          ? Colors.white
                                          : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildFeatureTile(
                                      icon: Icons.workspace_premium_outlined,
                                      label: 'Fiabilite',
                                      value: profile.rating,
                                      valueColor: const Color(0xFF7DFFB0),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                profile.about,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.80)
                                      : theme.colorScheme.onSurfaceVariant,
                                  height: 1.45,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ChatPage(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.message_outlined, size: 18),
                            label: const Text('Message'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF184B33),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
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
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.26),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderPill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tileColor = isDark
        ? Colors.white.withOpacity(0.04)
        : theme.colorScheme.surface.withOpacity(0.72);
    final iconBoxColor = isDark
        ? Colors.white.withOpacity(0.08)
        : theme.colorScheme.surfaceContainerHighest.withOpacity(0.9);
    final iconColor = isDark
        ? Colors.white
        : theme.colorScheme.onSurfaceVariant;
    final labelColor = isDark
        ? Colors.white.withOpacity(0.66)
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBoxColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor,
                    fontWeight: FontWeight.w800,
                  ),
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
    final followers = [
      _userItem(
        name: 'Miora Andrianiaina',
        subtitle: 'Suit la boutique depuis 8 mois',
        imageUrl:
            'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200',
        trailingText: 'Abonne',
      ),
      _userItem(
        name: 'Toky Rajaonarison',
        subtitle: 'Acheteur regulier',
        imageUrl:
            'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200',
        trailingText: 'Abonne',
      ),
      _userItem(
        name: 'Aina Ravelona',
        subtitle: 'Suit les nouveautes smartphone',
        imageUrl:
            'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=200',
        trailingText: 'Abonne',
      ),
    ];

    final visitors = [
      _userItem(
        name: 'Feno Nantenaina',
        subtitle: 'A visite le profil aujourd\'hui',
        imageUrl:
            'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=200',
        trailingText: 'Aujourd\'hui',
      ),
      _userItem(
        name: 'Sarah R.',
        subtitle: 'A consulte 3 annonces cette semaine',
        imageUrl:
            'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=200',
        trailingText: '3 vues',
      ),
      _userItem(
        name: 'Kevin M.',
        subtitle: 'Interesse par les iPhone',
        imageUrl:
            'https://images.unsplash.com/photo-1504593811423-6dd665756598?w=200',
        trailingText: 'Recurrent',
      ),
    ];

    final ratings = [
      _userItem(
        name: 'Nadia',
        subtitle: 'Transaction rapide et produit conforme',
        imageUrl:
            'https://images.unsplash.com/photo-1488426862026-3ee34a7d66df?w=200',
        trailingText: '5.0',
      ),
      _userItem(
        name: 'Bryan',
        subtitle: 'Tres bon vendeur, communication claire',
        imageUrl:
            'https://images.unsplash.com/photo-1504257432389-52343af06ae3?w=200',
        trailingText: '4.8',
      ),
      _userItem(
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
            value: profile.followerCount,
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
            value: profile.visitorCount,
            icon: Icons.visibility_outlined,
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
            value: profile.rating,
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

  UserListItemData _userItem({
    required String name,
    required String subtitle,
    required String imageUrl,
    required String trailingText,
  }) {
    final nextProfile = buildProfileFromUser(
      name: name,
      avatarUrl: imageUrl,
      subtitle: subtitle,
    );

    return UserListItemData(
      name: name,
      subtitle: subtitle,
      imageUrl: imageUrl,
      trailingText: trailingText,
      profileData: nextProfile,
      destinationBuilder: (_) => SellerProfilePage(profile: nextProfile),
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
