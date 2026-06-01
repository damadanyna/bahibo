import 'dart:async';

import 'package:banay/component/app_network_image.dart';
import 'package:banay/component/profile_models.dart';
import 'package:banay/component/seller_profile_page.dart';
import 'package:banay/component/ui/dinamic_categories_h_list.dart';
import 'package:banay/component/ui/dinamic_icon_input.dart';
import 'package:banay/page/category_page.dart';
import 'package:banay/page/productDetail.dart';
import 'package:banay/localization/banay_localizations.dart';
import 'package:banay/services/app_analytics.dart';
import 'package:banay/services/app_api_client.dart';
import 'package:banay/services/catalog_api_service.dart';
import 'package:banay/services/search_history_service.dart';
import 'package:banay/services/search_api_service.dart';
import 'package:banay/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';

class MainNavigationSearchPanel extends StatefulWidget {
  const MainNavigationSearchPanel({super.key});

  @override
  State<MainNavigationSearchPanel> createState() =>
      _MainNavigationSearchPanelState();
}

class _MainNavigationSearchPanelState extends State<MainNavigationSearchPanel> {
  final CatalogApiService _catalogApiService = CatalogApiService();
  final SearchHistoryService _searchHistoryService = SearchHistoryService();
  final SearchApiService _searchApiService = SearchApiService();

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Map<String, dynamic>> _categories = const [];
  List<String> _searchHistory = const [];
  final Set<String> _hiddenSearchHistory = <String>{};
  List<_SearchSuggestion> _autocompleteSuggestions = const [];
  List<_SearchSuggestion> _suggestions = const [];
  Timer? _searchDebounce;
  bool _isLoadingAutocomplete = false;
  bool _isSearchingApi = false;
  bool _hasSubmittedSearch = false;
  String? _searchError;
  Map<String, int> _resultCounts = const {
    'products': 0,
    'users': 0,
    'categories': 0,
    'locations': 0,
  };

  bool _isVisibleSuggestionPayload(Map<String, dynamic> item) {
    final rawType = (item['type'] as String? ?? '').trim().toLowerCase();
    if (rawType != 'product') {
      return true;
    }

    final rawProductData = item['productData'];
    if (rawProductData is Map) {
      final productData = Map<String, dynamic>.from(rawProductData);
      final value = productData['isAvailable'];
      return value is bool ? value : true;
    }

    final value = item['isAvailable'];
    return value is bool ? value : true;
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _searchFocusNode.addListener(_handleFocusChanged);
    _loadSearchHistory();
    _refreshCategories();
  }

  Future<void> _loadSearchHistory() async {
    final history = await _searchHistoryService.loadHistory();
    if (!mounted) {
      return;
    }

    setState(() {
      _searchHistory = history;
    });
  }

  Future<void> _refreshCategories() async {
    try {
      final categories = await _catalogApiService.fetchCategories();
      if (!mounted) {
        return;
      }

      setState(() {
        _categories = categories;
      });
    } catch (_) {}
  }

  void _handleSearchChanged() {
    final query = _searchController.text.trim();
    _searchDebounce?.cancel();
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _autocompleteSuggestions = const [];
          _suggestions = const [];
          _resultCounts = const {
            'products': 0,
            'users': 0,
            'categories': 0,
            'locations': 0,
          };
          _searchError = null;
          _hasSubmittedSearch = false;
          _isLoadingAutocomplete = false;
          _isSearchingApi = false;
        });
      }
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      _refreshAutocomplete();
    });
    if (mounted) {
      setState(() {
        _hasSubmittedSearch = false;
      });
    }
  }

  void _handleFocusChanged() {
    if (_searchFocusNode.hasFocus && _searchController.text.trim().isNotEmpty) {
      _searchDebounce?.cancel();
      unawaited(_refreshAutocomplete());
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refreshAutocomplete() async {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _autocompleteSuggestions = const [];
          _isLoadingAutocomplete = false;
          _searchError = null;
        });
      }
      return;
    }

    setState(() {
      _isLoadingAutocomplete = true;
      _searchError = null;
    });

    try {
      final response = await _searchApiService.autocomplete(query: query);
      final rawResults = ((response['results'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where(_isVisibleSuggestionPayload)
          .toList(growable: false);

      if (!mounted) return;

      setState(() {
        _autocompleteSuggestions = rawResults
            .map(_SearchSuggestion.fromApi)
            .toList();
        _isLoadingAutocomplete = false;
      });
    } on AppApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _autocompleteSuggestions = const [];
        _isLoadingAutocomplete = false;
        _searchError = error.message;
      });
    }
  }

  Future<void> _executeSearch({String? query, bool unfocus = true}) async {
    final normalizedQuery = (query ?? _searchController.text).trim();
    if (normalizedQuery.isEmpty) {
      return;
    }

    _searchDebounce?.cancel();
    if (_searchController.text != normalizedQuery) {
      _searchController.value = TextEditingValue(
        text: normalizedQuery,
        selection: TextSelection.collapsed(offset: normalizedQuery.length),
      );
    }

    if (unfocus) {
      _searchFocusNode.unfocus();
    }

    setState(() {
      _isSearchingApi = true;
      _hasSubmittedSearch = true;
      _searchError = null;
    });

    try {
      final response = await _searchApiService.search(query: normalizedQuery);
      final rawResults = ((response['results'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where(_isVisibleSuggestionPayload)
          .toList(growable: false);
      final counts = Map<String, int>.from(
        ((response['counts'] as Map?) ?? const <String, int>{}).map(
          (key, value) =>
              MapEntry(key.toString(), (value as num?)?.toInt() ?? 0),
        ),
      );

      await AppAnalytics.instance.logSearchQuery(query: normalizedQuery);
      await AppAnalytics.instance.logUserEvent(
        name: 'search_results_loaded',
        parameters: {
          'query': normalizedQuery,
          'result_count': rawResults.length,
          'user_count': counts['users'] ?? 0,
          'category_count': counts['categories'] ?? 0,
          'location_count': counts['locations'] ?? 0,
        },
        source: 'search',
      );

      if (!mounted) return;

      setState(() {
        _suggestions = rawResults.map(_SearchSuggestion.fromApi).toList();
        _resultCounts = {
          'products': _suggestions
              .where((suggestion) => suggestion.type == _SuggestionType.product)
              .length,
          'users': counts['users'] ?? 0,
          'categories': counts['categories'] ?? 0,
          'locations': counts['locations'] ?? 0,
        };
        _autocompleteSuggestions = const [];
        _isSearchingApi = false;
      });
    } on AppApiException catch (error) {
      await AppAnalytics.instance.logUserEvent(
        name: 'search_failed',
        parameters: {'query': normalizedQuery, 'reason': error.message},
        source: 'search',
        status: 'failure',
      );
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

  Future<void> _selectAutocompleteSuggestion(
    _SearchSuggestion suggestion,
  ) async {
    await _executeSearch(query: suggestion.label, unfocus: true);
  }

  void _selectSuggestion(_SearchSuggestion suggestion) {
    _searchController.value = TextEditingValue(
      text: suggestion.label,
      selection: TextSelection.collapsed(offset: suggestion.label.length),
    );
    _searchFocusNode.unfocus();
  }

  Future<void> _repeatSearchFromHistory(String query) async {
    await _executeSearch(query: query, unfocus: true);
  }

  Future<void> _saveQueryToHistory(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return;
    }

    final updatedHistory = await _searchHistoryService.addQuery(normalized);
    if (!mounted) {
      return;
    }

    setState(() {
      _searchHistory = updatedHistory;
      _hiddenSearchHistory.removeWhere(
        (entry) => entry.toLowerCase() == normalized.toLowerCase(),
      );
    });
  }

  void _hideSearchHistoryEntry(String query) {
    setState(() {
      _hiddenSearchHistory.add(query.trim().toLowerCase());
    });
  }

  Future<void> _confirmHideSearchHistoryEntry(String query) async {
    final decision = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          context.tr(BanayLocalizationKeys.searchHideHistoryDialogTitle),
        ),
        content: Text(
          context.tr(
            BanayLocalizationKeys.searchHideHistoryDialogBody,
            params: {'query': query},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr(BanayLocalizationKeys.searchCancel)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr(BanayLocalizationKeys.searchDelete)),
          ),
        ],
      ),
    );

    if (decision == true && mounted) {
      _hideSearchHistoryEntry(query);
    }
  }

  Widget _buildAutocompleteSection(
    ThemeData theme,
    List<_SearchSuggestion> suggestions,
  ) {
    final query = _searchController.text.trim();

    if (_isLoadingAutocomplete) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.2),
        ),
      );
    }

    if (suggestions.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.appColors.inputBorder),
        ),
        child: Text(
          context.tr(
            BanayLocalizationKeys.searchNoSuggestions,
            params: {'query': query},
          ),
          style: TextStyle(
            color: theme.appColors.mutedText,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? theme.appColors.inputFill
            : theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.appColors.inputBorder),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.people_alt_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    context.tr(BanayLocalizationKeys.searchSuggestionsTitle),
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...suggestions.map(
                (suggestion) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => _selectAutocompleteSuggestion(suggestion),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          _buildAutocompleteLeading(theme, suggestion),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  suggestion.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  suggestion.subtitle.isEmpty
                                      ? context.tr(suggestion.typeLabel)
                                      : '${context.tr(suggestion.typeLabel)} · ${suggestion.subtitle}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: theme.appColors.mutedText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAutocompleteLeading(
    ThemeData theme,
    _SearchSuggestion suggestion,
  ) {
    switch (suggestion.type) {
      case _SuggestionType.user:
        return SizedBox(
          width: 42,
          height: 42,
          child: AppCircleNetworkAvatar(
            imageUrl: suggestion.imageUrl ?? '',
            radius: 21,
            userId: suggestion.id,
            showPresenceBadge: false,
          ),
        );
      case _SuggestionType.product:
        return AppNetworkImage(
          imageUrl: suggestion.imageUrl ?? '',
          width: 42,
          height: 42,
          borderRadius: BorderRadius.circular(12),
          errorChild: Icon(
            Icons.inventory_2_outlined,
            color: theme.appColors.placeholderIcon,
            size: 22,
          ),
        );
      case _SuggestionType.category:
      case _SuggestionType.location:
        return AppImagePlaceholder(
          width: 42,
          height: 42,
          borderRadius: BorderRadius.circular(12),
          child: Icon(
            suggestion.icon,
            color: theme.colorScheme.primary,
            size: 22,
          ),
        );
    }
  }

  Future<void> _openCategoryShortcut(Map<String, dynamic> category) async {
    FocusScope.of(context).unfocus();
    final slug = category['slug']?.toString() ?? '';
    final label = category['name']?.toString() ?? slug;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryPage(
          categoryName: slug,
          categoryLabel: label,
          categoryIcon: resolveDinamicCategoryIcon(category),
        ),
      ),
    );
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
        sellerProfileId: profile.sellerProfileId,
        name: profile.name,
        avatarUrl: avatarUrl,
        coverImageUrl: coverImageUrl,
        roleLabel: profile.roleLabel,
        responseLabel: profile.responseLabel,
        headline: profile.headline,
        about: profile.about,
        followerCount: profile.followerCount,
        visitorCount: profile.visitorCount,
        productCount: profile.productCount,
        totalLikesCount: profile.totalLikesCount,
        rating: profile.rating,
        isFollowing: profile.isFollowing,
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
    final searchedQuery = _searchController.text.trim();
    await AppAnalytics.instance.logUserEvent(
      name: 'search_result_opened',
      parameters: {
        'query': searchedQuery,
        'result_id': suggestion.id,
        'result_type': suggestion.type.name,
        'label': suggestion.label,
      },
      source: 'search',
    );
    _selectSuggestion(suggestion);

    if (suggestion.type == _SuggestionType.product &&
        suggestion.productData != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductDetailPage(product: suggestion.productData!),
        ),
      );
      await _saveQueryToHistory(searchedQuery);
      return;
    }

    if (suggestion.type == _SuggestionType.category ||
        suggestion.type == _SuggestionType.location) {
      _searchFocusNode.requestFocus();
      unawaited(_refreshAutocomplete());
      return;
    }

    final sellerProfile = _resolveSellerProfile(suggestion);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SellerProfilePage(profile: sellerProfile),
      ),
    );
    await _saveQueryToHistory(searchedQuery);
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
    final showAutocomplete =
        _searchFocusNode.hasFocus && _searchController.text.trim().isNotEmpty;
    final showSearchResults =
        _hasSubmittedSearch && _searchController.text.trim().isNotEmpty;
    final suggestions = _visibleSuggestions;
    final autocompleteSuggestions = _autocompleteSuggestions;

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
                  context.tr(BanayLocalizationKeys.searchTitle),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                DynamicIconInput(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onSubmitted: (_) => _executeSearch(),
                  primary: theme.colorScheme.primary,
                  panelColor: theme.cardColor,
                  borderColor: appColors.inputBorder,
                  textInputAction: TextInputAction.search,
                  hintText: context.tr(BanayLocalizationKeys.searchHint),
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
                Expanded(
                  child: showAutocomplete
                      ? _buildAutocompleteSection(
                          theme,
                          autocompleteSuggestions,
                        )
                      : showSearchResults
                      ? _buildSuggestionsPanel(theme, suggestions)
                      : ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            DinamicCategoriesHList(
                              categories: _categories,
                              showTitle: false,
                              onCategoryTap: _openCategoryShortcut,
                            ),
                            _buildSearchHistorySection(theme),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchHistorySection(ThemeData theme) {
    final visibleHistory = _searchHistory.where((query) {
      return !_hiddenSearchHistory.contains(query.trim().toLowerCase());
    }).toList();

    if (visibleHistory.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          context.tr(BanayLocalizationKeys.searchHistoryTitle),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        ...visibleHistory.map(
          (query) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => _repeatSearchFromHistory(query),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: theme.appColors.inputBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 20,
                      color: theme.appColors.mutedText,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        query,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: () => _confirmHideSearchHistoryEntry(query),
                      tooltip: context.tr(
                        BanayLocalizationKeys.searchHideHistoryTooltip,
                      ),
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: theme.appColors.mutedText,
                      ),
                      visualDensity: VisualDensity.compact,
                      splashRadius: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
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
              context.tr(
                BanayLocalizationKeys.searchNoResults,
                params: {'query': query},
              ),
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
              ? context.tr(BanayLocalizationKeys.searchResultsFromDatabase)
              : context.tr(
                  BanayLocalizationKeys.searchResultsForQuery,
                  params: {'count': '${suggestions.length}'},
                ),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          context.tr(
            BanayLocalizationKeys.searchResultsSummary,
            params: {
              'products': '${_resultCounts['products'] ?? productCount}',
              'users': '${_resultCounts['users'] ?? userCount}',
              'categories': '${_resultCounts['categories'] ?? 0}',
              'locations': '${_resultCounts['locations'] ?? 0}',
            },
          ),
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
                                    context.tr(suggestion.typeLabel),
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
        sellerProfileId: rawSellerProfile['sellerProfileId'] as String?,
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
        productCount: (rawSellerProfile['productCount'] as String?) ?? '0',
        totalLikesCount:
            (rawSellerProfile['totalLikesCount'] as String?) ?? '0',
        rating: (rawSellerProfile['rating'] as String?) ?? '0.0',
        isFollowing: rawSellerProfile['isFollowing'] as bool? ?? false,
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
        return BanayLocalizationKeys.searchTypeProduct;
      case _SuggestionType.user:
        return BanayLocalizationKeys.searchTypeUser;
      case _SuggestionType.category:
        return BanayLocalizationKeys.searchTypeCategory;
      case _SuggestionType.location:
        return BanayLocalizationKeys.searchTypeLocation;
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
