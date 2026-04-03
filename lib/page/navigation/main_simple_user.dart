import 'package:bahibo/component/app_network_image.dart';
import 'package:bahibo/services/app_auth_service.dart';
import 'package:bahibo/services/session_storage.dart';
import 'package:bahibo/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';

class MainSimpleUser extends StatefulWidget {
  const MainSimpleUser({super.key});

  @override
  State<MainSimpleUser> createState() => _MainSimpleUserState();
}

class _MainSimpleUserState extends State<MainSimpleUser> {
  static const String _defaultCoverImageUrl =
      'https://images.unsplash.com/photo-1517292987719-0369a794ec0f?w=1600';

  final AppAuthService _authService = AppAuthService();
  final SessionStorage _sessionStorage = SessionStorage();

  bool _isLoading = true;
  String? _errorMessage;
  String _displayName = 'Utilisateur Bahibo';
  String _avatarUrl = '';
  String _coverImageUrl = _defaultCoverImageUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final localDisplayName = await _sessionStorage.getDisplayName();

    if (mounted &&
        localDisplayName != null &&
        localDisplayName.trim().isNotEmpty) {
      setState(() {
        _displayName = localDisplayName.trim();
      });
    }

    try {
      final user = await _authService.fetchCurrentUser();

      if (!mounted) {
        return;
      }

      final avatarUrl = (user['avatarUrl'] as String?)?.trim() ?? '';
      setState(() {
        _displayName =
            (user['displayName'] as String?)?.trim().isNotEmpty == true
            ? (user['displayName'] as String).trim()
            : _displayName;
        _avatarUrl = avatarUrl;
        _coverImageUrl = avatarUrl.isNotEmpty
            ? avatarUrl
            : _defaultCoverImageUrl;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Impossible de charger le profil utilisateur';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final titleColor = theme.colorScheme.onSurface;
    final subtitleColor = appColors.mutedText;

    return Scaffold(
      backgroundColor: appColors.backgroundBase,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProfile,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                child: Text(
                  'Compte',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: appColors.inputBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(32),
                            ),
                            child: SizedBox(
                              height: 190,
                              width: double.infinity,
                              child: AppNetworkImage(
                                imageUrl: _coverImageUrl,
                                fit: BoxFit.cover,
                                errorChild: Icon(
                                  Icons.landscape_rounded,
                                  color: appColors.placeholderIcon,
                                  size: 32,
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(32),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.08),
                                    Colors.black.withValues(alpha: 0.28),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 24,
                            bottom: -44,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: appColors.inputBorder,
                                ),
                              ),
                              child: _avatarUrl.isNotEmpty
                                  ? AppCircleNetworkAvatar(
                                      imageUrl: _avatarUrl,
                                      radius: 44,
                                    )
                                  : Container(
                                      width: 88,
                                      height: 88,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: appColors.placeholderFill,
                                      ),
                                      child: Icon(
                                        Icons.person_rounded,
                                        color: appColors.placeholderIcon,
                                        size: 42,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 58, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isLoading)
                              Text(
                                'Chargement du profil...',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: subtitleColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            else ...[
                              Text(
                                _displayName,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: titleColor,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Nom saisi lors de la creation du compte',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: subtitleColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
