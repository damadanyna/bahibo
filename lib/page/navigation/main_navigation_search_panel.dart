import 'dart:async';
import 'dart:convert';

import 'package:bahibo/component/app_network_image.dart';
import 'package:bahibo/component/navigation/navigation_search_chip.dart';
import 'package:bahibo/component/profile_models.dart';
import 'package:bahibo/component/seller_profile_page.dart';
import 'package:bahibo/component/ui/dinamic_icon_input.dart';
import 'package:bahibo/page/productDetail.dart';
import 'package:bahibo/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MainNavigationSearchPanel extends StatefulWidget {
  const MainNavigationSearchPanel({super.key});

  @override
  State<MainNavigationSearchPanel> createState() =>
      _MainNavigationSearchPanelState();
}

class _MainNavigationSearchPanelState extends State<MainNavigationSearchPanel> {
  static const String _productsApiUrl = 'https://dummyjson.com/products';
  static const List<Map<String, dynamic>> _extraStudioProducts = [
    {
      'title': 'Dior Sauvage Parfum',
      'category': 'Parfum de luxe',
      'price': 560,
      'thumbnail':
          'https://images.unsplash.com/photo-1594035910387-fea47794261f?w=800',
    },
    {
      'title': 'iPhone 13 Pro Max',
      'category': 'Top vente',
      'price': 3150,
      'thumbnail':
          'https://images.unsplash.com/photo-1632661674596-df8be070a5c5?w=800',
    },
    {
      'title': 'Tecno Camon 20',
      'category': 'Disponible',
      'price': 890,
      'thumbnail':
          'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=800',
    },
    {
      'title': 'AirPods Pro 2',
      'category': 'Accessoire',
      'price': 680,
      'thumbnail':
          'https://images.unsplash.com/photo-1606220588913-b3aacb4d2f46?w=800',
    },
    {
      'title': 'Samsung Galaxy S23',
      'category': 'Top vente',
      'price': 2890,
      'thumbnail':
          'https://images.unsplash.com/photo-1610945265064-0e34e5519bbf?w=800',
    },
    {
      'title': 'Apple Watch Series 9',
      'category': 'Accessoire',
      'price': 1490,
      'thumbnail':
          'https://images.unsplash.com/photo-1546868871-7041f2a55e12?w=800',
    },
  ];

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final List<_SearchSuggestion> _sellerSuggestions = _buildSellerSuggestions();
  List<_SearchSuggestion> _productSuggestions = const [];
  Timer? _searchDebounce;
  bool _isSearchingApi = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _searchFocusNode.addListener(_handleFocusChanged);
    _refreshSearchResults();
  }

  void _handleSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      _refreshSearchResults();
    });
    if (mounted) setState(() {});
  }

  void _handleFocusChanged() {
    if (_searchFocusNode.hasFocus && _searchController.text.trim().isNotEmpty) {
      _searchDebounce?.cancel();
      unawaited(_refreshSearchResults());
    }

    if (mounted) {
      setState(() {});
    }
  }

  static String _buildProductKeywords({
    required String title,
    required String category,
    required String sellerName,
    String? description,
    List<dynamic>? tags,
  }) {
    final base =
        '$title commentaire avis bon produit livraison rapide qualite vendeur $sellerName $category ${description ?? ''} ${(tags ?? const []).join(' ')}';
    final normalizedTitle = title.toLowerCase();

    if (normalizedTitle.contains('watch')) {
      return '$base watch smartwatch montre water waterproof water resistant resistant sport fitness';
    }

    if (normalizedTitle.contains('airpods')) {
      return '$base audio ecouteur wireless bluetooth music';
    }

    if (normalizedTitle.contains('iphone') ||
        normalizedTitle.contains('samsung') ||
        normalizedTitle.contains('tecno') ||
        normalizedTitle.contains('redmi')) {
      return '$base telephone smartphone mobile camera batterie';
    }

    if (normalizedTitle.contains('dior')) {
      return '$base parfum fragrance beauty luxe mode';
    }

    return base;
  }

  static List<_SearchSuggestion> _buildSellerSuggestions() {
    final profiles = <UserProfileData>[
      defaultSellerProfileData(),
      buildProfileFromUser(
        name: 'Miora Mobile',
        avatarUrl:
            'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=600',
        subtitle: 'Vendeuse accessoires et smartphones',
      ),
      buildProfileFromUser(
        name: 'Tahina Store',
        avatarUrl:
            'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=600',
        subtitle: 'Boutique telephones et gadgets',
      ),
    ];
    final diorProfile = buildProfileFromUser(
      name: 'Dior Beauty Mada',
      avatarUrl:
          'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?w=600',
      subtitle: 'Boutique officielle parfums et beaute',
    );

    final suggestions = <_SearchSuggestion>[];
    final seen = <String>{};

    void addSuggestion(_SearchSuggestion suggestion) {
      final key =
          '${suggestion.type}|${_SearchSuggestion.normalize(suggestion.label)}';
      if (seen.add(key)) {
        suggestions.add(suggestion);
      }
    }

    for (var index = 0; index < profiles.length; index++) {
      final profile = profiles[index];

      if (index == 0) {
        addSuggestion(
          _SearchSuggestion(
            label: 'Dior Beauty Mada',
            subtitle: 'Boutique officielle parfums et beaute',
            type: _SuggestionType.seller,
            sellerName: 'Dior Beauty Mada',
            imageUrl:
                'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?w=600',
            description:
                'Selection Dior: parfums, rouge a levres, coffrets cadeaux et nouveautes luxe.',
            keywords:
                'dior beauty mada parfum luxe maquillage mode sauvage miss dior vendeur officiel',
            sellerProfile: diorProfile,
          ),
        );
      }

      addSuggestion(
        _SearchSuggestion(
          label: profile.name,
          subtitle: profile.roleLabel,
          type: _SuggestionType.seller,
          sellerName: profile.name,
          imageUrl: profile.avatarUrl,
          description: profile.about,
          keywords:
              '${profile.headline} ${profile.about} vendeur fiable repond rapidement service serieux ${profile.roleLabel}',
          sellerProfile: profile,
        ),
      );
    }

    return suggestions;
  }

  List<_SearchSuggestion> _buildLocalProductSuggestions() {
    final products = <Map<String, dynamic>>[
      ...defaultSellerProfileData().products,
      ..._extraStudioProducts,
    ];

    return products.map((product) {
      final title = (product['title'] ?? '').toString();
      final category = (product['category'] ?? '').toString();
      final thumbnail = (product['thumbnail'] ?? '').toString();
      final price = (product['price'] ?? '').toString();

      return _SearchSuggestion(
        label: title,
        subtitle: 'Produit local',
        type: _SuggestionType.product,
        sellerName: 'Bahibo Studio',
        productName: title,
        categoryName: category,
        imageUrl: thumbnail,
        description: category.isEmpty
            ? 'Disponible sur Bahibo'
            : '$category • ${price.isEmpty ? '' : '$price MGA'}',
        keywords: _buildProductKeywords(
          title: title,
          category: category,
          sellerName: 'Bahibo Studio',
        ),
        productData: _normalizeProductData(product),
      );
    }).toList();
  }

  Future<void> _refreshSearchResults() async {
    final query = _searchController.text.trim();

    setState(() {
      _isSearchingApi = true;
      _searchError = null;
    });

    try {
      final remoteSuggestions = await _fetchApiProductSuggestions(query);
      if (!mounted) return;
      setState(() {
        _productSuggestions = remoteSuggestions;
        _isSearchingApi = false;
      });
    } catch (_) {
      final fallbackSuggestions = _buildLocalProductSuggestions();
      if (!mounted) return;
      setState(() {
        _productSuggestions = fallbackSuggestions;
        _isSearchingApi = false;
        _searchError = 'Recherche API indisponible, affichage local.';
      });
    }
  }

  Future<List<_SearchSuggestion>> _fetchApiProductSuggestions(
    String query,
  ) async {
    final endpoint = query.isEmpty
        ? Uri.parse('$_productsApiUrl?limit=100')
        : Uri.parse(
            '$_productsApiUrl/search?q=${Uri.encodeQueryComponent(query)}',
          );

    final response = await http.get(endpoint);
    if (response.statusCode != 200) {
      throw Exception('API error');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final products = (data['products'] as List<dynamic>? ?? const []);

    return products.map((rawProduct) {
      final product = rawProduct as Map<String, dynamic>;
      final title = (product['title'] ?? '').toString();
      final category = (product['category'] ?? '').toString();
      final thumbnail = (product['thumbnail'] ?? '').toString();
      final price = (product['price'] ?? '').toString();
      final brand = (product['brand'] ?? 'Boutique partenaire').toString();
      final description = (product['description'] ?? '').toString();
      final tags = (product['tags'] as List<dynamic>?) ?? const [];

      return _SearchSuggestion(
        label: title,
        subtitle: 'Produit chez $brand',
        type: _SuggestionType.product,
        sellerName: brand,
        productName: title,
        categoryName: category,
        imageUrl: thumbnail,
        description: category.isEmpty
            ? description
            : '$category • ${price.isEmpty ? '' : '$price MGA'} • $description',
        keywords: _buildProductKeywords(
          title: title,
          category: category,
          sellerName: brand,
          description: description,
          tags: tags,
        ),
        productData: _normalizeProductData(product),
      );
    }).toList();
  }

  static Map<String, dynamic> _normalizeProductData(
    Map<String, dynamic> product,
  ) {
    final normalized = Map<String, dynamic>.from(product);
    final thumbnail = (normalized['thumbnail'] ?? '').toString();
    final images = (normalized['images'] as List?)
        ?.whereType<String>()
        .toList();

    normalized['thumbnail'] = thumbnail;
    normalized['images'] = images == null || images.isEmpty
        ? (thumbnail.isEmpty ? <String>[] : <String>[thumbnail])
        : images;

    return normalized;
  }

  List<_SearchSuggestion> get _visibleSuggestions {
    final query = _searchController.text.trim().toLowerCase();
    final suggestions = <_SearchSuggestion>[
      ..._productSuggestions,
      ..._sellerSuggestions,
    ];

    suggestions.sort((left, right) {
      final leftStarts = _SearchSuggestion.normalize(
        left.label,
      ).startsWith(query);
      final rightStarts = _SearchSuggestion.normalize(
        right.label,
      ).startsWith(query);
      if (leftStarts != rightStarts) {
        return leftStarts ? -1 : 1;
      }

      final leftContains = left.searchableText.contains(query);
      final rightContains = right.searchableText.contains(query);
      if (leftContains != rightContains) {
        return leftContains ? -1 : 1;
      }

      return left.label.compareTo(right.label);
    });

    if (query.isEmpty) {
      return suggestions;
    }

    return suggestions.where((suggestion) {
      return suggestion.searchableText.contains(query);
    }).toList();
  }

  void _selectSuggestion(_SearchSuggestion suggestion) {
    _searchController.value = TextEditingValue(
      text: suggestion.label,
      selection: TextSelection.collapsed(offset: suggestion.label.length),
    );
    _searchFocusNode.unfocus();
  }

  UserProfileData _resolveSellerProfile(_SearchSuggestion suggestion) {
    if (suggestion.sellerProfile != null) {
      return suggestion.sellerProfile!;
    }

    return buildProfileFromUser(
      name: suggestion.sellerName ?? suggestion.label,
      avatarUrl:
          suggestion.imageUrl ??
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=600',
      subtitle: suggestion.subtitle,
    );
  }

  Future<void> _openSearchResult(_SearchSuggestion suggestion) async {
    _selectSuggestion(suggestion);

    if (suggestion.type == _SuggestionType.product &&
        suggestion.productData != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductDetailPage(product: suggestion.productData!),
        ),
      );
      return;
    }

    final sellerProfile = _resolveSellerProfile(suggestion);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SellerProfilePage(profile: sellerProfile),
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    _searchFocusNode.removeListener(_handleFocusChanged);
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final showSuggestions = _searchFocusNode.hasFocus;
    final suggestions = _visibleSuggestions;

    return Scaffold(
      backgroundColor: appColors.backgroundBase,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recherche',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                DynamicIconInput(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  primary: theme.colorScheme.primary,
                  panelColor: theme.cardColor,
                  borderColor: appColors.inputBorder,
                  hintText:
                      'Rechercher un produit, un vendeur, une categorie...',
                  contentPadding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                  leadingSize: 24,
                  leadingIcon: Icon(
                    Icons.search_rounded,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                  trailingIcon: _searchController.text.trim().isEmpty
                      ? null
                      : Icon(
                          Icons.close_rounded,
                          color: theme.appColors.mutedText,
                          size: 20,
                        ),
                  trailingSize: 32,
                  onTrailingTap: () {
                    _searchController.clear();
                    _searchFocusNode.requestFocus();
                  },
                ),
                const SizedBox(height: 20),
                if (showSuggestions)
                  Expanded(child: _buildSuggestionsPanel(theme, suggestions))
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: const [
                      NavigationSearchChip(label: 'Dior'),
                      NavigationSearchChip(label: 'Water'),
                      NavigationSearchChip(label: 'Samsung'),
                      NavigationSearchChip(label: 'Telephone'),
                      NavigationSearchChip(label: 'Mode'),
                      NavigationSearchChip(label: 'Cuisine'),
                      NavigationSearchChip(label: 'Auto'),
                      NavigationSearchChip(label: 'Laptop'),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsPanel(
    ThemeData theme,
    List<_SearchSuggestion> suggestions,
  ) {
    final query = _searchController.text.trim();

    if (_isSearchingApi) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }

    if (suggestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Aucun produit ou vendeur pour "$query".',
              style: TextStyle(
                color: theme.appColors.mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_searchError != null) ...[
              const SizedBox(height: 8),
              Text(
                _searchError!,
                style: TextStyle(
                  color: theme.appColors.mutedText,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      );
    }

    final productCount = suggestions
        .where((suggestion) => suggestion.type == _SuggestionType.product)
        .length;
    final sellerCount = suggestions.length - productCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          query.isEmpty
              ? 'Produits et vendeurs charges depuis l’API'
              : 'Resultats lies a la recherche (${suggestions.length})',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$productCount produits • $sellerCount vendeurs',
          style: TextStyle(
            color: theme.appColors.mutedText,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: suggestions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final suggestion = suggestions[index];
              return InkWell(
                onTap: () => _openSearchResult(suggestion),
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: theme.appColors.inputBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSuggestionLeading(theme, suggestion),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    suggestion.displayTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.appColors.panelMuted,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    suggestion.typeLabel,
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              suggestion.subtitle,
                              style: TextStyle(
                                color: theme.appColors.mutedText,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if ((suggestion.description ?? '').isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                suggestion.description!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.textTheme.bodyMedium?.color,
                                  height: 1.35,
                                ),
                              ),
                            ],
                            if (suggestion.productName != null ||
                                suggestion.sellerName != null) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  if (suggestion.productName != null)
                                    _buildMetaChip(
                                      theme,
                                      icon: Icons.inventory_2_outlined,
                                      text: suggestion.productName!,
                                    ),
                                  if (suggestion.sellerName != null)
                                    _buildMetaChip(
                                      theme,
                                      icon: Icons.storefront_rounded,
                                      text: suggestion.sellerName!,
                                    ),
                                  if (suggestion.categoryName != null &&
                                      suggestion.categoryName!.isNotEmpty)
                                    _buildMetaChip(
                                      theme,
                                      icon: Icons.sell_outlined,
                                      text: suggestion.categoryName!,
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionLeading(
    ThemeData theme,
    _SearchSuggestion suggestion,
  ) {
    if (suggestion.imageUrl != null && suggestion.imageUrl!.isNotEmpty) {
      return AppNetworkImage(
        imageUrl: suggestion.imageUrl!,
        width: 74,
        height: 74,
        borderRadius: BorderRadius.circular(14),
        errorChild: Icon(
          suggestion.icon,
          color: theme.colorScheme.primary,
          size: 28,
        ),
      );
    }

    return _buildSuggestionIconBox(theme, suggestion);
  }

  Widget _buildSuggestionIconBox(
    ThemeData theme,
    _SearchSuggestion suggestion,
  ) {
    return Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(suggestion.icon, color: theme.colorScheme.primary, size: 28),
    );
  }

  Widget _buildMetaChip(
    ThemeData theme, {
    required IconData icon,
    required String text,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.appColors.panelMuted,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _SuggestionType { product, seller }

class _SearchSuggestion {
  final String label;
  final String subtitle;
  final _SuggestionType type;
  final String? keywords;
  final String? productName;
  final String? sellerName;
  final String? categoryName;
  final String? imageUrl;
  final String? description;
  final Map<String, dynamic>? productData;
  final UserProfileData? sellerProfile;

  const _SearchSuggestion({
    required this.label,
    required this.subtitle,
    required this.type,
    this.keywords,
    this.productName,
    this.sellerName,
    this.categoryName,
    this.imageUrl,
    this.description,
    this.productData,
    this.sellerProfile,
  });

  static String normalize(String? value) {
    return (value ?? '').toLowerCase();
  }

  String get displayTitle => type == _SuggestionType.product
      ? (productName ?? label)
      : (sellerName ?? label);

  String get searchableText =>
      '${normalize(label)} ${normalize(subtitle)} ${normalize(typeLabel)} ${normalize(keywords)} ${normalize(description)} ${normalize(productName)} ${normalize(sellerName)} ${normalize(categoryName)}';

  String get typeLabel {
    switch (type) {
      case _SuggestionType.product:
        return 'Produit';
      case _SuggestionType.seller:
        return 'Vendeur';
    }
  }

  IconData get icon {
    switch (type) {
      case _SuggestionType.product:
        return Icons.inventory_2_outlined;
      case _SuggestionType.seller:
        return Icons.storefront_rounded;
    }
  }
}
