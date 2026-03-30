import 'package:bahibo/component/navigation/navigation_message_components.dart';
import 'package:bahibo/page/chat_page.dart';
import 'package:bahibo/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';

typedef NavigationMessageConversation = ({
  String name,
  String preview,
  String time,
  String avatarUrl,
  bool unread,
});

const List<NavigationMessageConversation> mainNavigationMessageConversations = [
  (
    name: 'John Rakoto',
    preview: 'Bonjour, le Samsung S20 est-il toujours disponible ?',
    time: '13:06',
    avatarUrl:
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=600',
    unread: true,
  ),
  (
    name: 'Miora Andrianiaina',
    preview: 'Je peux vous envoyer les photos cet apres-midi.',
    time: '11:24',
    avatarUrl:
        'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300',
    unread: false,
  ),
  (
    name: 'Kevin R.',
    preview: 'Merci, je passe demain matin vers 9h.',
    time: 'Hier',
    avatarUrl:
        'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=300',
    unread: false,
  ),
  (
    name: 'Aina Shop',
    preview: 'Le produit est reserve jusqu a ce soir.',
    time: 'Lun',
    avatarUrl:
        'https://images.unsplash.com/photo-1544723795-3fb6469f5b39?w=300',
    unread: true,
  ),
  (
    name: 'Tiana Market',
    preview: 'Le prix est negociable si vous venez aujourd hui.',
    time: 'Dim',
    avatarUrl:
        'https://images.unsplash.com/photo-1504257432389-52343af06ae3?w=300',
    unread: false,
  ),
  (
    name: 'Sarah Boutique',
    preview: 'Bonsoir, la robe est encore disponible en taille M.',
    time: 'Sam',
    avatarUrl:
        'https://images.unsplash.com/photo-1488426862026-3ee34a7d66df?w=300',
    unread: true,
  ),
  (
    name: 'Nomena Tech',
    preview: 'Je peux livrer le laptop demain matin si besoin.',
    time: 'Ven',
    avatarUrl:
        'https://images.unsplash.com/photo-1504593811423-6dd665756598?w=300',
    unread: false,
  ),
  (
    name: 'Lova Deco',
    preview: 'Les photos supplementaires ont ete envoyees.',
    time: 'Jeu',
    avatarUrl:
        'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=300',
    unread: true,
  ),
];

int get mainNavigationUnreadMessageCount => mainNavigationMessageConversations
    .where((message) => message.unread)
    .length;

class MainNavigationMessagesPanel extends StatefulWidget {
  const MainNavigationMessagesPanel({super.key});

  @override
  State<MainNavigationMessagesPanel> createState() =>
      _MainNavigationMessagesPanelState();
}

class _MainNavigationMessagesPanelState
    extends State<MainNavigationMessagesPanel> {
  static const double _searchBarHeight = 58;
  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _searchAnchorKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  double? _searchAnchorTop;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureSearchAnchorTop();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!mounted) return;
    setState(() {});
  }

  void _captureSearchAnchorTop() {
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final anchorBox =
        _searchAnchorKey.currentContext?.findRenderObject() as RenderBox?;

    if (stackBox == null || anchorBox == null) {
      return;
    }

    final top = anchorBox.localToGlobal(Offset.zero, ancestor: stackBox).dy;
    if (_searchAnchorTop == null || (_searchAnchorTop! - top).abs() > 0.5) {
      setState(() => _searchAnchorTop = top);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appColors = theme.appColors;
    final primary = theme.colorScheme.primary;
    final heroColor = appColors.panelMuted;
    final searchFillColor = appColors.panelBackground;
    final quickActionColor = isDark
        ? appColors.heroSurface
        : primary.withValues(alpha: 0.12);
    final titleColor = theme.colorScheme.onSurface;
    final mutedColor = appColors.mutedText;
    final normalizedQuery = _searchQuery.trim().toLowerCase();
    final filteredConversations = normalizedQuery.isEmpty
        ? mainNavigationMessageConversations
        : mainNavigationMessageConversations.where((conversation) {
            final name = conversation.name.toLowerCase();
            final preview = conversation.preview.toLowerCase();
            return name.contains(normalizedQuery) ||
                preview.contains(normalizedQuery);
          }).toList();
    final currentScrollOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    final rawSearchTop = _searchAnchorTop == null
        ? null
        : _searchAnchorTop! - currentScrollOffset;
    final isSearchPinned = rawSearchTop != null && rawSearchTop <= 0;
    final floatingSearchTop = rawSearchTop == null
        ? null
        : rawSearchTop.clamp(0.0, double.infinity);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureSearchAnchorTop();
    });

    return Scaffold(
      backgroundColor: theme.cardColor,
      body: SafeArea(
        child: Stack(
          key: _stackKey,
          children: [
            ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(18, 20, 18, 0),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primary.withValues(alpha: isDark ? 0.2 : 0.14),
                        heroColor,
                        heroColor,
                      ],
                    ),
                    border: Border.all(
                      color: isDark
                          ? appColors.overlayBorder
                          : primary.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Messages',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: titleColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        key: _searchAnchorKey,
                        height: _searchBarHeight,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 120),
                          opacity: isSearchPinned ? 0 : 1,
                          child: IgnorePointer(
                            ignoring: isSearchPinned,
                            child: NavigationMessageSearchBar(
                              controller: _searchController,
                              fillColor: searchFillColor,
                              iconColor: mutedColor,
                              hintColor: mutedColor,
                              onChanged: (value) {
                                setState(() => _searchQuery = value);
                              },
                              borderColor: appColors.inputBorder,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 92,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: filteredConversations.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 16),
                          itemBuilder: (context, index) {
                            final conversation = filteredConversations[index];
                            return NavigationMessageStoryAvatar(
                              name: conversation.name.split(' ').first,
                              avatarUrl: conversation.avatarUrl,
                              isActive: true,
                              primary: primary,
                              labelColor: titleColor,
                              haloColor: heroColor,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ChatPage(),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (filteredConversations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: appColors.inputBorder),
                      ),
                      child: Text(
                        'Aucun message ne correspond a votre recherche.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: mutedColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                else
                  ...List.generate(filteredConversations.length, (index) {
                    final conversation = filteredConversations[index];
                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        18,
                        0,
                        18,
                        index == filteredConversations.length - 1 ? 0 : 12,
                      ),
                      child: NavigationConversationTile(
                        name: conversation.name,
                        preview: conversation.preview,
                        time: conversation.time,
                        avatarUrl: conversation.avatarUrl,
                        unread: conversation.unread,
                        primary: primary,
                        isDark: isDark,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ChatPage()),
                          );
                        },
                      ),
                    );
                  }),
              ],
            ),
            if (floatingSearchTop != null && isSearchPinned)
              Positioned(
                top: floatingSearchTop,
                left: 18,
                right: 18,
                child: NavigationMessageSearchBar(
                  controller: _searchController,
                  fillColor: searchFillColor,
                  iconColor: mutedColor,
                  hintColor: mutedColor,
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                  borderColor: appColors.inputBorder,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
