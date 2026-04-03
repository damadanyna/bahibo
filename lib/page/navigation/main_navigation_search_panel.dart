import 'dart:async';

import 'package:bahibo/component/app_network_image.dart';
import 'package:bahibo/component/navigation/navigation_search_chip.dart';
import 'package:bahibo/component/profile_models.dart';
import 'package:bahibo/component/seller_profile_page.dart';
import 'package:bahibo/component/ui/dinamic_icon_input.dart';
import 'package:bahibo/page/productDetail.dart';
import 'package:bahibo/services/app_api_client.dart';
import 'package:bahibo/services/search_api_service.dart';
import 'package:bahibo/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';

class MainNavigationSearchPanel extends StatefulWidget {
  const MainNavigationSearchPanel({super.key});

  @override
  State<MainNavigationSearchPanel> createState() =>
      _MainNavigationSearchPanelState();
}

class _MainNavigationSearchPanelState extends State<MainNavigationSearchPanel> {
  final SearchApiService _searchApiService = SearchApiService();

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<_SearchSuggestion> _suggestions = const [];
  Timer? _searchDebounce;
  bool _isSearchingApi = false;
  String? _searchError;
  Map<String, int> _resultCounts = const {
    'products': 0,
    'users': 0,
    'categories': 0,
    'locations': 0,
  };

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

  Future<void> _refreshSearchResults() async {
    final query = _searchController.text.trim();

    setState(() {
      _isSearchingApi = true;
      _searchError = null;
    });

    try {
      final response = await _searchApiService.search(query: query);
      final rawResults = (response['results'] as List?) ?? const [];
      final counts = Map<String, int>.from(
        ((response['counts'] as Map?) ?? const <String, int>{}).map(
          (key, value) =>
              MapEntry(key.toString(), (value as num?)?.toInt() ?? 0),
        ),
      );

      if (!mounted) return;

      setState(() {
        _suggestions = rawResults
            .whereType<Map>()
            .map(
              (item) =>
                  _SearchSuggestion.fromApi(Map<String, dynamic>.from(item)),
            )
            .toList();
        _resultCounts = {
          'products': counts['products'] ?? 0,
          'users': counts['users'] ?? 0,
          'categories': counts['categories'] ?? 0,
          'locations': counts['locations'] ?? 0,
        };
        _isSearchingApi = false;
      });
    } on AppApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _suggestions = const [];
        _isSearchingApi = false;
        _searchError = error.message;
      });
    }
  }

  List<_SearchSuggestion> get _visibleSuggestions {
    final query = _searchController.text.trim().toLowerCase();
    final suggestions = <_SearchSuggestion>[..._suggestions];

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
      final profile = suggestion.sellerProfile!;
      final avatarUrl = profile.avatarUrl.trim().isNotEmpty
          ? profile.avatarUrl.trim()
          : ((suggestion.imageUrl ?? '').trim().isNotEmpty
                ? suggestion.imageUrl!.trim()
                : 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=600');
      final coverImageUrl = profile.coverImageUrl.trim().isNotEmpty
          ? profile.coverImageUrl.trim()
          : 'https://images.unsplash.com/photo-1520607162513-77705c0f0d4a?w=1600';

      return UserProfileData(
        userId: profile.userId,
        name: profile.name,
        avatarUrl: avatarUrl,
        coverImageUrl: coverImageUrl,
        roleLabel: profile.roleLabel,
        responseLabel: profile.responseLabel,
        headline: profile.headline,
        about: profile.about,
        followerCount: profile.followerCount,
        visitorCount: profile.visitorCount,
        rating: profile.rating,
        products: profile.products,
      );
    }

    return buildProfileFromUser(
      userId: suggestion.type == _SuggestionType.user ? suggestion.id : null,
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

    if (suggestion.type == _SuggestionType.category ||
        suggestion.type == _SuggestionType.location) {
      _searchFocusNode.requestFocus();
      unawaited(_refreshSearchResults());
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
                      'Rechercher un utilisateur, produit, categorie ou lieu...',
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
              'Aucun utilisateur, produit, categorie ou lieu pour "$query".',
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
    final userCount = suggestions
        .where((suggestion) => suggestion.type == _SuggestionType.user)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          query.isEmpty
              ? 'Resultats depuis la base Bahibo'
              : 'Resultats lies a la recherche (${suggestions.length})',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${_resultCounts['products'] ?? productCount} produits • ${_resultCounts['users'] ?? userCount} utilisateurs • ${_resultCounts['categories'] ?? 0} categories • ${_resultCounts['locations'] ?? 0} lieux',
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

enum _SuggestionType { product, user, category, location }

class _SearchSuggestion {
  final String id;
  final String label;
  final String subtitle;
  final _SuggestionType type;
  final String? keywords;
  final String? productName;
  final String? sellerName;
  final String? categoryName;
  final String? locationLabel;
  final String? imageUrl;
  final String? description;
  final Map<String, dynamic>? productData;
  final UserProfileData? sellerProfile;

  const _SearchSuggestion({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.type,
    this.keywords,
    this.productName,
    this.sellerName,
    this.categoryName,
    this.locationLabel,
    this.imageUrl,
    this.description,
    this.productData,
    this.sellerProfile,
  });

  factory _SearchSuggestion.fromApi(Map<String, dynamic> item) {
    final rawType = (item['type'] as String? ?? '').trim().toLowerCase();
    final type = switch (rawType) {
      'product' => _SuggestionType.product,
      'user' => _SuggestionType.user,
      'category' => _SuggestionType.category,
      'location' => _SuggestionType.location,
      _ => _SuggestionType.product,
    };

    UserProfileData? sellerProfile;
    final rawSellerProfile = item['sellerProfile'];
    if (rawSellerProfile is Map) {
      sellerProfile = UserProfileData(
        userId: rawSellerProfile['userId'] as String?,
        name: (rawSellerProfile['name'] as String?) ?? '',
        avatarUrl: (rawSellerProfile['avatarUrl'] as String?) ?? '',
        coverImageUrl: (rawSellerProfile['coverImageUrl'] as String?) ?? '',
        roleLabel: (rawSellerProfile['roleLabel'] as String?) ?? 'Vendeur',
        responseLabel:
            (rawSellerProfile['responseLabel'] as String?) ?? 'Profil actif',
        headline: (rawSellerProfile['headline'] as String?) ?? '',
        about: (rawSellerProfile['about'] as String?) ?? '',
        followerCount: (rawSellerProfile['followerCount'] as String?) ?? '0',
        visitorCount: (rawSellerProfile['visitorCount'] as String?) ?? '0',
        rating: (rawSellerProfile['rating'] as String?) ?? '0.0',
        products: ((rawSellerProfile['products'] as List?) ?? const [])
            .whereType<Map>()
            .map((product) => Map<String, dynamic>.from(product))
            .toList(),
      );
    }

    Map<String, dynamic>? productData;
    final rawProductData = item['productData'];
    if (rawProductData is Map) {
      productData = Map<String, dynamic>.from(rawProductData);
    }

    return _SearchSuggestion(
      id: (item['id'] as String?) ?? '',
      label: (item['label'] as String?) ?? '',
      subtitle: (item['subtitle'] as String?) ?? '',
      type: type,
      keywords: (item['description'] as String?) ?? '',
      productName: (item['label'] as String?) ?? '',
      sellerName: item['sellerName'] as String?,
      categoryName: item['categoryName'] as String?,
      locationLabel: item['locationLabel'] as String?,
      imageUrl: item['imageUrl'] as String?,
      description: item['description'] as String?,
      productData: productData,
      sellerProfile: sellerProfile,
    );
  }

  static String normalize(String? value) {
    return (value ?? '').toLowerCase();
  }

  String get displayTitle => type == _SuggestionType.product
      ? (productName ?? label)
      : (sellerName ?? label);

  String get searchableText =>
      '${normalize(label)} ${normalize(subtitle)} ${normalize(typeLabel)} ${normalize(keywords)} ${normalize(description)} ${normalize(productName)} ${normalize(sellerName)} ${normalize(categoryName)} ${normalize(locationLabel)}';

  String get typeLabel {
    switch (type) {
      case _SuggestionType.product:
        return 'Produit';
      case _SuggestionType.user:
        return 'Utilisateur';
      case _SuggestionType.category:
        return 'Categorie';
      case _SuggestionType.location:
        return 'Lieu';
    }
  }

  IconData get icon {
    switch (type) {
      case _SuggestionType.product:
        return Icons.inventory_2_outlined;
      case _SuggestionType.user:
        return Icons.person_outline_rounded;
      case _SuggestionType.category:
        return Icons.sell_outlined;
      case _SuggestionType.location:
        return Icons.location_on_outlined;
    }
  }
}
