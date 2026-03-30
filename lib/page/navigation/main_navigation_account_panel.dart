import 'dart:io';

import 'package:bahibo/component/ProductCard.dart';
import 'package:bahibo/component/app_network_image.dart';
import 'package:bahibo/component/app_page_refresh.dart';
import 'package:bahibo/component/app_page_skeletons.dart';
import 'package:bahibo/component/profile_models.dart';
import 'package:bahibo/component/ui/dinamic_icon_input.dart';
import 'package:bahibo/page/live/live_preview_page.dart';
import 'package:bahibo/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

enum _EditableProfileImageTarget { avatar, cover }

class MainNavigationAccountPanel extends StatefulWidget {
  final UserProfileData? profile;

  const MainNavigationAccountPanel({super.key, this.profile});

  @override
  State<MainNavigationAccountPanel> createState() =>
      _MainNavigationAccountPanelState();
}

class _MainNavigationAccountPanelState extends State<MainNavigationAccountPanel>
    with AppPageRefreshMixin<MainNavigationAccountPanel> {
  static const List<Map<String, dynamic>> _extraStudioProducts = [
    {
      'title': 'iPhone 13 Pro Max',
      'category': 'Top vente',
      'price': 3150,
      'images': [
        'https://images.unsplash.com/photo-1632661674596-df8be070a5c5?w=800',
      ],
      'thumbnail':
          'https://images.unsplash.com/photo-1632661674596-df8be070a5c5?w=800',
    },
    {
      'title': 'Tecno Camon 20',
      'category': 'Disponible',
      'price': 890,
      'images': [
        'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=800',
      ],
      'thumbnail':
          'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=800',
    },
    {
      'title': 'AirPods Pro 2',
      'category': 'Accessoire',
      'price': 680,
      'images': [
        'https://images.unsplash.com/photo-1606220588913-b3aacb4d2f46?w=800',
      ],
      'thumbnail':
          'https://images.unsplash.com/photo-1606220588913-b3aacb4d2f46?w=800',
    },
    {
      'title': 'Samsung Galaxy S23',
      'category': 'Top vente',
      'price': 2890,
      'images': [
        'https://images.unsplash.com/photo-1610945265064-0e34e5519bbf?w=800',
      ],
      'thumbnail':
          'https://images.unsplash.com/photo-1610945265064-0e34e5519bbf?w=800',
    },
    {
      'title': 'Apple Watch Series 9',
      'category': 'Accessoire',
      'price': 1490,
      'images': [
        'https://images.unsplash.com/photo-1546868871-7041f2a55e12?w=800',
      ],
      'thumbnail':
          'https://images.unsplash.com/photo-1546868871-7041f2a55e12?w=800',
    },
  ];

  bool _showEntrySkeleton = true;
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _searchController = TextEditingController();
  File? _avatarImageFile;
  File? _coverImageFile;
  String _searchQuery = '';
  String _studioName = '';
  String _studioAddress = 'Antananarivo, Madagascar';
  String _studioDescription = '';
  String? _activeLiveTitle;
  String? _activeLiveCategory;
  String? _activeLiveStartedLabel;

  UserProfileData get profile => widget.profile ?? defaultSellerProfileData();

  List<Map<String, dynamic>> get _catalogProducts => [
    ...profile.products,
    ..._extraStudioProducts,
  ];

  List<Map<String, dynamic>> get _filteredProducts {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return _catalogProducts;
    }

    return _catalogProducts.where((product) {
      final title = (product['title'] ?? '').toString().toLowerCase();
      final category = (product['category'] ?? '').toString().toLowerCase();
      return title.contains(query) || category.contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    initializePageRefresh();
    _hydrateStudioFields();
    _searchController.addListener(_handleSearchChanged);
    Future.delayed(const Duration(milliseconds: 240), () {
      if (!mounted) return;
      setState(() => _showEntrySkeleton = false);
    });
  }

  void _handleSearchChanged() {
    final nextQuery = _searchController.text;
    if (nextQuery == _searchQuery) return;
    setState(() => _searchQuery = nextQuery);
  }

  void _hydrateStudioFields() {
    if (_studioName.isEmpty) {
      _studioName = profile.name;
    }
    if (_studioDescription.isEmpty) {
      _studioDescription = profile.about;
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
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

  Future<void> _pickProfileImage(
    _EditableProfileImageTarget target,
    ImageSource source,
  ) async {
    final file = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1800,
    );
    if (file == null || !mounted) return;

    setState(() {
      if (target == _EditableProfileImageTarget.avatar) {
        _avatarImageFile = File(file.path);
      } else {
        _coverImageFile = File(file.path);
      }
    });
  }

  Future<void> _showImageSourceSheet(_EditableProfileImageTarget target) async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Prendre une photo'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _pickProfileImage(target, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choisir dans la galerie'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _pickProfileImage(target, ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showIdentityEditor() async {
    final nameController = TextEditingController(text: _studioName);
    final addressController = TextEditingController(text: _studioAddress);
    final descriptionController = TextEditingController(
      text: _studioDescription,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final accentColor = _accentColor(theme);
        final inputPanelColor = _backgroundColor(theme);
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: Container(
            decoration: _surfaceDecoration(theme, radius: 28, tinted: true),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Modifier la boutique',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                DynamicIconInput(
                  controller: nameController,
                  primary: accentColor,
                  panelColor: inputPanelColor,
                  borderColor: accentColor.withOpacity(0.12),
                  hintText: 'Nom boutique',
                  leadingIcon: Icon(
                    Icons.storefront_outlined,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 12),
                DynamicIconInput(
                  controller: addressController,
                  primary: accentColor,
                  panelColor: inputPanelColor,
                  borderColor: accentColor.withOpacity(0.12),
                  hintText: 'Adresse',
                  leadingIcon: Icon(
                    Icons.location_on_outlined,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 12),
                DynamicIconInput(
                  controller: descriptionController,
                  primary: accentColor,
                  panelColor: inputPanelColor,
                  borderColor: accentColor.withOpacity(0.12),
                  hintText: 'Description',
                  leadingIcon: Icon(Icons.notes_rounded, color: accentColor),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        if (nameController.text.trim().isNotEmpty) {
                          _studioName = nameController.text.trim();
                        }
                        if (addressController.text.trim().isNotEmpty) {
                          _studioAddress = addressController.text.trim();
                        }
                        if (descriptionController.text.trim().isNotEmpty) {
                          _studioDescription = descriptionController.text
                              .trim();
                        }
                      });
                      Navigator.of(sheetContext).pop();
                    },
                    child: const Text('Enregistrer'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showStubAction(String label) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label sera branche ensuite.')));
  }

  Future<void> _openLivePreview(String title, String category) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LivePreviewPage(title: title, category: category),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _activeLiveTitle = null;
      _activeLiveCategory = null;
      _activeLiveStartedLabel = null;
    });
  }

  Future<void> _showLaunchLiveSheet() async {
    final titleController = TextEditingController(
      text: '${_studioName.isEmpty ? profile.name : _studioName} en direct',
    );
    final categoryController = TextEditingController(
      text: 'Presentation produit',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final accentColor = _accentColor(theme);
        final panelColor = _backgroundColor(theme);
        final liveColor = const Color(0xFFE53935);

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: Container(
            decoration: _surfaceDecoration(theme, radius: 28, tinted: true),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: liveColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.live_tv_rounded, color: liveColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Creer un live',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Prepare ton direct et rends-le visible tout de suite.',
                            style: TextStyle(color: theme.appColors.mutedText),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                DynamicIconInput(
                  controller: titleController,
                  primary: accentColor,
                  panelColor: panelColor,
                  borderColor: accentColor.withOpacity(0.12),
                  hintText: 'Titre du live',
                  leadingIcon: Icon(
                    Icons.mic_external_on_outlined,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 12),
                DynamicIconInput(
                  controller: categoryController,
                  primary: accentColor,
                  panelColor: panelColor,
                  borderColor: accentColor.withOpacity(0.12),
                  hintText: 'Theme ou categorie',
                  leadingIcon: Icon(Icons.sell_outlined, color: accentColor),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: liveColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: liveColor.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE53935),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Le live sera lance immediatement apres validation.',
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final liveTitle = titleController.text.trim();
                      final liveCategory = categoryController.text.trim();

                      if (liveTitle.isEmpty) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Ajoute un titre pour lancer le live.',
                            ),
                          ),
                        );
                        return;
                      }

                      final resolvedCategory = liveCategory.isEmpty
                          ? 'Live boutique'
                          : liveCategory;

                      Navigator.of(sheetContext).pop();
                      _openLivePreview(liveTitle, resolvedCategory);
                    },
                    icon: const Icon(Icons.wifi_tethering_rounded),
                    label: const Text('Demarrer le live'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _backgroundColor(ThemeData theme) {
    return theme.appColors.backgroundBase;
  }

  Color _panelColor(ThemeData theme) {
    return theme.appColors.panelBackground;
  }

  Color _mutedColor(ThemeData theme) {
    return theme.appColors.mutedText;
  }

  Color _accentColor(ThemeData theme) {
    if (theme.brightness == Brightness.dark) {
      return Color.lerp(
        theme.colorScheme.primary,
        theme.colorScheme.onSurfaceVariant,
        0.28,
      )!;
    }

    return theme.colorScheme.primary;
  }

  Color _accentSurfaceColor(ThemeData theme) {
    if (theme.brightness == Brightness.dark) {
      return theme.colorScheme.primary.withValues(alpha: 0.14);
    }

    return theme.appColors.panelMuted;
  }

  Color _supportAccentColor(ThemeData theme) {
    if (theme.brightness == Brightness.dark) {
      return theme.colorScheme.tertiary;
    }

    return theme.colorScheme.primary;
  }

  Color _panelBorderColor(ThemeData theme) {
    final base = theme.appColors.borderColor;
    return theme.brightness == Brightness.dark
        ? base.withValues(alpha: 0.74)
        : base.withValues(alpha: 0.9);
  }

  List<BoxShadow> _panelShadow(ThemeData theme) {
    if (theme.brightness == Brightness.dark) {
      return const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 22,
          offset: Offset(0, 12),
        ),
      ];
    }

    return const [
      BoxShadow(
        color: Color(0x0D101828),
        blurRadius: 18,
        offset: Offset(0, 10),
      ),
    ];
  }

  BoxDecoration _surfaceDecoration(
    ThemeData theme, {
    double radius = 24,
    bool tinted = false,
  }) {
    final panelColor = _panelColor(theme);
    final backgroundColor = _backgroundColor(theme);
    final accentColor = _accentColor(theme);
    final topColor = tinted
        ? Color.lerp(
            panelColor,
            accentColor,
            theme.brightness == Brightness.dark ? 0.08 : 0.05,
          )!
        : Color.lerp(panelColor, backgroundColor, 0.18)!;

    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [topColor, panelColor],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _panelBorderColor(theme)),
      boxShadow: _panelShadow(theme),
    );
  }

  Widget _buildBackgroundAccent({
    required Alignment alignment,
    required List<Color> colors,
    required double size,
  }) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: colors),
          ),
        ),
      ),
    );
  }

  List<_RankedProductEntry> _buildTopProducts() {
    const likes = [1200, 980, 870, 760, 650, 590, 540, 490, 430, 390];
    const growth = [
      '+18%',
      '+12%',
      '+9%',
      '+7%',
      '+6%',
      '+4%',
      '+3%',
      '+2%',
      '+2%',
      '+1%',
    ];
    final result = <_RankedProductEntry>[];
    final products = _catalogProducts;

    for (
      var index = 0;
      index < likes.length && index < products.length;
      index++
    ) {
      final product = products[index];
      result.add(
        _RankedProductEntry(
          rank: index + 1,
          title: (product['title'] ?? 'Produit').toString(),
          category: (product['category'] ?? 'Catalogue').toString(),
          imageUrl: (product['thumbnail'] ?? '').toString(),
          price: (product['price'] ?? 0).toString(),
          likes: likes[index],
          growth: growth[index],
        ),
      );
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    _hydrateStudioFields();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = _backgroundColor(theme);
    final panelColor = _panelColor(theme);
    final mutedColor = _mutedColor(theme);
    final accentColor = _accentColor(theme);
    final supportAccentColor = _supportAccentColor(theme);
    final filteredProducts = _filteredProducts;
    final topProducts = _buildTopProducts();

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          _buildBackgroundAccent(
            alignment: const Alignment(-1.1, -0.92),
            size: 240,
            colors: [
              accentColor.withValues(alpha: isDark ? 0.12 : 0.1),
              Colors.transparent,
            ],
          ),
          _buildBackgroundAccent(
            alignment: const Alignment(1.05, -0.2),
            size: 220,
            colors: [
              supportAccentColor.withValues(alpha: isDark ? 0.08 : 0.06),
              Colors.transparent,
            ],
          ),
          RefreshIndicator(
            onRefresh: refreshPageWithDialog,
            child: _showEntrySkeleton
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [SellerProfileSkeleton()],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 120),
                    children: [
                      _buildStudioHero(theme),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildMetricsGrid(
                          theme,
                          panelColor,
                          mutedColor,
                          accentColor,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildLaunchLiveButton(
                          theme,
                          accentColor,
                          supportAccentColor,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildDashboardCard(
                          theme,
                          panelColor,
                          mutedColor,
                          accentColor,
                          supportAccentColor,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildSearchSection(
                          theme,
                          panelColor,
                          mutedColor,
                          accentColor,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildTopProductsSection(
                          theme,
                          panelColor,
                          mutedColor,
                          accentColor,
                          topProducts,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildCatalogSection(
                          theme,
                          panelColor,
                          mutedColor,
                          filteredProducts,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildAccountInfoSection(
                          theme,
                          panelColor,
                          mutedColor,
                        ),
                      ),
                    ],
                  ),
          ),
          if (isOffline) const AppOfflineBanner(),
        ],
      ),
    );
  }

  Widget _buildStudioHero(ThemeData theme) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    final heroMinHeight = compact ? 372.0 : 344.0;
    final accentColor = _accentColor(theme);
    final accentSurfaceColor = _accentSurfaceColor(theme);
    final supportAccentColor = _supportAccentColor(theme);

    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(28)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: heroMinHeight),
              child: SizedBox(
                width: double.infinity,
                child: _buildEditableCoverImage(),
              ),
            ),
            Container(
              constraints: BoxConstraints(minHeight: heroMinHeight),
              padding: EdgeInsets.fromLTRB(
                20,
                compact ? 16 : 20,
                20,
                compact ? 16 : 20,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.appColors.scrimSoft,
                    theme.appColors.scrimStrong,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 10 : 12,
                      vertical: compact ? 6 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.appColors.heroSurface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: theme.appColors.heroBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 16,
                          color: theme.appColors.heroForeground,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Account Studio',
                          style: TextStyle(
                            color: theme.appColors.heroForeground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: compact ? 18 : 26),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: theme.appColors.heroSurface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.appColors.heroBorder,
                              ),
                            ),
                            child: _buildEditableAvatar(),
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: _buildImageEditButton(
                              onTap: () => _showImageSourceSheet(
                                _EditableProfileImageTarget.avatar,
                              ),
                              compact: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _studioName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.appColors.heroForeground,
                                fontSize: compact ? 22 : 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: compact ? 4 : 6),
                            Text(
                              _studioAddress,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.appColors.heroForegroundMuted,
                                fontWeight: FontWeight.w500,
                                fontSize: compact ? 13 : 14,
                              ),
                            ),
                            SizedBox(height: compact ? 8 : 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildHeroPill(
                                  icon: Icons.verified_rounded,
                                  label: profile.roleLabel,
                                ),
                                _buildHeroPill(
                                  icon: Icons.bolt_rounded,
                                  label: 'Actif aujourd\'hui',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 12 : 18),
                  Text(
                    _studioDescription,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.appColors.heroForegroundMuted,
                      height: 1.35,
                      fontSize: compact ? 13 : 14,
                    ),
                  ),
                  SizedBox(height: compact ? 12 : 18),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _showIdentityEditor,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text(
                            'Modifier profil',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.appColors.heroForeground,
                            foregroundColor: Colors.black,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                            padding: EdgeInsets.symmetric(
                              vertical: compact ? 10 : 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showStubAction('Creer un produit'),
                          icon: const Icon(Icons.add_box_outlined, size: 18),
                          label: const Text(
                            'Creer produit',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.appColors.heroForeground,
                            backgroundColor: supportAccentColor.withValues(
                              alpha: theme.brightness == Brightness.dark
                                  ? 0.22
                                  : 0.14,
                            ),
                            side: BorderSide(
                              color: supportAccentColor.withValues(
                                alpha: theme.brightness == Brightness.dark
                                    ? 0.42
                                    : 0.24,
                              ),
                            ),
                            padding: EdgeInsets.symmetric(
                              vertical: compact ? 10 : 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: _buildImageEditButton(
                onTap: () =>
                    _showImageSourceSheet(_EditableProfileImageTarget.cover),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(
    ThemeData theme,
    Color panelColor,
    Color mutedColor,
    Color accentColor,
  ) {
    final supportAccentColor = _supportAccentColor(theme);
    final metrics = [
      _StudioMetric('Abonnes', profile.followerCount, Icons.groups_2_outlined),
      _StudioMetric('Vues profil', '3.8k', Icons.visibility_outlined),
      _StudioMetric('Produits', '${_catalogProducts.length}', Icons.storefront),
      _StudioMetric('Likes total', '9.2k', Icons.favorite_outline),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 138,
      ),
      itemBuilder: (context, index) {
        final metric = metrics[index];
        final iconBackground = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.22),
            supportAccentColor.withValues(alpha: 0.12),
          ],
        );
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: _surfaceDecoration(
            theme,
            radius: 22,
            tinted: index.isEven,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: accentColor.withValues(alpha: 0.2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: iconBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(metric.icon, color: accentColor),
              ),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  metric.value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                metric.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: mutedColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDashboardCard(
    ThemeData theme,
    Color panelColor,
    Color mutedColor,
    Color accentColor,
    Color supportAccentColor,
  ) {
    final bars = const [0.35, 0.58, 0.47, 0.74, 0.62, 0.85, 0.68];

    final accentSurfaceColor = _accentSurfaceColor(theme);
    final chartBaseColor = theme.brightness == Brightness.dark
        ? supportAccentColor.withValues(alpha: 0.34)
        : accentColor.withValues(alpha: 0.24);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _surfaceDecoration(theme, tinted: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tableau de bord',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cette semaine, la boutique est en hausse de 18%.',
                      style: TextStyle(color: mutedColor),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentSurfaceColor,
                      supportAccentColor.withValues(alpha: 0.18),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '+18%',
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 128,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(bars.length, (index) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              height: 104 * bars[index],
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    accentColor.withOpacity(0.92),
                                    chartBaseColor,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ['L', 'M', 'M', 'J', 'V', 'S', 'D'][index],
                          style: TextStyle(
                            color: mutedColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLaunchLiveButton(
    ThemeData theme,
    Color accentColor,
    Color supportAccentColor,
  ) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: _surfaceDecoration(theme, radius: 22, tinted: true),
      child: ElevatedButton.icon(
        onPressed: _showLaunchLiveSheet,
        icon: const Icon(Icons.live_tv_rounded, size: 20),
        label: const Text(
          'Lancer un live',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          foregroundColor: Colors.white,
          backgroundColor: accentColor,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          minimumSize: const Size(double.infinity, 58),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: supportAccentColor.withValues(alpha: isDark ? 0.4 : 0.22),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSection(
    ThemeData theme,
    Color panelColor,
    Color mutedColor,
    Color accentColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _surfaceDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Recherche rapide',
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Recherche produit',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Cherche rapidement un produit et inspecte son statut.',
            style: TextStyle(color: mutedColor),
          ),
          const SizedBox(height: 14),
          DynamicIconInput(
            controller: _searchController,
            primary: accentColor,
            panelColor: _backgroundColor(theme),
            hintText: 'iPhone, Samsung, accessoire...',
            borderColor: accentColor.withOpacity(0.12),
            leadingIcon: Icon(Icons.search_rounded, color: accentColor),
            trailingIcon: _searchQuery.isEmpty
                ? null
                : Icon(Icons.close_rounded, color: accentColor),
            onTrailingTap: _searchQuery.isEmpty
                ? null
                : () {
                    _searchController.clear();
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductsSection(
    ThemeData theme,
    Color panelColor,
    Color mutedColor,
    Color accentColor,
    List<_RankedProductEntry> topProducts,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _surfaceDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            theme,
            'Top 10 produits likes',
            'Top performance',
          ),
          const SizedBox(height: 14),
          ...topProducts.take(5).map((product) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    alignment: Alignment.center,
                    child: Text(
                      '#${product.rank}',
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AppNetworkImage(
                      imageUrl: product.imageUrl,
                      width: 64,
                      height: 64,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${product.category} • ${product.price} Ar',
                          style: TextStyle(color: mutedColor),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.favorite_rounded,
                            size: 16,
                            color: theme.appColors.favoriteAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${product.likes}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.growth,
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCatalogSection(
    ThemeData theme,
    Color panelColor,
    Color mutedColor,
    List<Map<String, dynamic>> filteredProducts,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _surfaceDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            theme,
            'Catalogue studio',
            '${filteredProducts.length} resultats',
          ),
          const SizedBox(height: 14),
          if (filteredProducts.isEmpty)
            Text(
              'Aucun produit ne correspond a cette recherche.',
              style: TextStyle(color: mutedColor),
            )
          else
            ...filteredProducts.take(3).map((product) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ProductCard(product: product),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAccountInfoSection(
    ThemeData theme,
    Color panelColor,
    Color mutedColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _surfaceDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Informations boutique',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _showIdentityEditor,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Modifier'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildInfoRow('Nom', _studioName, mutedColor),
          _buildInfoRow('Adresse', _studioAddress, mutedColor),
          _buildInfoRow(
            'Description',
            _studioDescription,
            mutedColor,
            multiline: true,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    Color mutedColor, {
    bool multiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).appColors.inputFill.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _panelBorderColor(Theme.of(context))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: mutedColor, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: multiline ? 3 : 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableCoverImage() {
    if (_coverImageFile != null) {
      return Image.file(_coverImageFile!, fit: BoxFit.cover);
    }

    return AppNetworkImage(imageUrl: profile.coverImageUrl, fit: BoxFit.cover);
  }

  Widget _buildEditableAvatar() {
    if (_avatarImageFile != null) {
      return ClipOval(
        child: Image.file(
          _avatarImageFile!,
          width: 82,
          height: 82,
          fit: BoxFit.cover,
        ),
      );
    }

    return AppCircleNetworkAvatar(radius: 41, imageUrl: profile.avatarUrl);
  }

  Widget _buildImageEditButton({
    required VoidCallback onTap,
    bool compact = false,
  }) {
    final size = compact ? 34.0 : 40.0;
    final accentColor = _accentColor(Theme.of(context));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: accentColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).appColors.heroForegroundMuted,
              width: 2,
            ),
          ),
          child: Icon(
            Icons.photo_camera_rounded,
            size: compact ? 18 : 20,
            color: Theme.of(context).appColors.heroForeground,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroPill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).appColors.heroSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).appColors.heroBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).appColors.heroForeground,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).appColors.heroForeground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, String meta) {
    final accentColor = _accentColor(theme);

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            meta,
            style: TextStyle(color: accentColor, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _StudioMetric {
  final String label;
  final String value;
  final IconData icon;

  const _StudioMetric(this.label, this.value, this.icon);
}

class _RankedProductEntry {
  final int rank;
  final String title;
  final String category;
  final String imageUrl;
  final String price;
  final int likes;
  final String growth;

  const _RankedProductEntry({
    required this.rank,
    required this.title,
    required this.category,
    required this.imageUrl,
    required this.price,
    required this.likes,
    required this.growth,
  });
}
