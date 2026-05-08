import 'package:flutter/material.dart';

import 'package:banay/component/app_network_image.dart';
import 'package:banay/component/ProductCard.dart';
import 'package:banay/theme/app_theme_extensions.dart';

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxShape shape;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    return AppImagePlaceholder(
      width: width,
      height: height,
      borderRadius: borderRadius ?? BorderRadius.circular(12),
      shape: shape,
    );
  }
}

class ProductCardSkeleton extends StatelessWidget {
  final ProductCardVariant variant;

  const ProductCardSkeleton({
    super.key,
    this.variant = ProductCardVariant.editorial,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final borderColor = appColors.borderColor.withValues(alpha: 0.55);
    final isMarketplace = variant == ProductCardVariant.marketplace;
    final badgeWidth = isMarketplace ? 74.0 : 90.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(width: 1, color: borderColor),
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.42,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const SkeletonBox(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: BorderRadius.zero,
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: _skeletonChip(width: badgeWidth),
                  ),
                  const Positioned(
                    right: 12,
                    top: 12,
                    child: SkeletonBox(
                      width: 40,
                      height: 40,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: const SkeletonBox(
                      width: 34,
                      height: 34,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Positioned(
                    right: isMarketplace ? 64 : 12,
                    bottom: 12,
                    child: Row(
                      children: [
                        _skeletonChip(width: 52),
                        const SizedBox(width: 8),
                        _skeletonChip(width: 52),
                      ],
                    ),
                  ),
                  if (isMarketplace)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: _skeletonChip(width: 44),
                    ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SkeletonBox(width: 108, height: 26),
                      SizedBox(width: 8),
                      Expanded(
                        child: SkeletonBox(width: double.infinity, height: 16),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  SkeletonBox(width: double.infinity, height: 18),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      SkeletonBox(
                        width: 28,
                        height: 28,
                        shape: BoxShape.circle,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: SkeletonBox(width: double.infinity, height: 16),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  SkeletonBox(width: 150, height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _skeletonChip({required double width}) {
    return SkeletonBox(
      width: width,
      height: 26,
      borderRadius: BorderRadius.circular(999),
    );
  }
}

class CategoryBlockSkeleton extends StatelessWidget {
  const CategoryBlockSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SkeletonBox(width: 170, height: 18),
        ),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: 5,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return Container(
                width: 150,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).cardColor,
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SkeletonBox(width: 34, height: 34, shape: BoxShape.circle),
                    SizedBox(height: 10),
                    SkeletonBox(width: 96, height: 14),
                    SizedBox(height: 6),
                    SkeletonBox(width: 72, height: 14),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class ProductDetailSkeleton extends StatelessWidget {
  const ProductDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SkeletonBox(height: 310, borderRadius: BorderRadius.zero),
        _surface(
          context,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 94, height: 26),
              SizedBox(height: 12),
              SkeletonBox(width: 230, height: 26),
              SizedBox(height: 10),
              SkeletonBox(width: 180, height: 34),
              SizedBox(height: 12),
              SkeletonBox(width: 220, height: 14),
            ],
          ),
        ),
        _surface(
          context,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 140, height: 20),
              SizedBox(height: 14),
              SkeletonBox(width: double.infinity, height: 18),
              SizedBox(height: 10),
              SkeletonBox(width: double.infinity, height: 18),
              SizedBox(height: 10),
              SkeletonBox(width: 210, height: 18),
            ],
          ),
        ),
        _surface(
          context,
          child: const Row(
            children: [
              SkeletonBox(width: 56, height: 56, shape: BoxShape.circle),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SkeletonBox(width: 180, height: 18),
                    SizedBox(height: 10),
                    SkeletonBox(width: 210, height: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          child: Row(
            children: const [
              Expanded(child: SkeletonBox(height: 48)),
              SizedBox(width: 10),
              SkeletonBox(width: 52, height: 48),
            ],
          ),
        ),
      ],
    );
  }

  Widget _surface(BuildContext context, {required Widget child}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class SellerProfileSkeleton extends StatelessWidget {
  const SellerProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: const SkeletonBox(
            height: 300,
            borderRadius: BorderRadius.zero,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: const [
            Expanded(child: SkeletonBox(height: 86)),
            SizedBox(width: 10),
            Expanded(child: SkeletonBox(height: 86)),
            SizedBox(width: 10),
            Expanded(child: SkeletonBox(height: 86)),
          ],
        ),
        const SizedBox(height: 18),
        const SkeletonBox(width: 160, height: 18),
        const SizedBox(height: 10),
        Row(
          children: const [
            SkeletonBox(width: 110, height: 38),
            SizedBox(width: 8),
            SkeletonBox(width: 98, height: 38),
            SizedBox(width: 8),
            SkeletonBox(width: 82, height: 38),
          ],
        ),
        const SizedBox(height: 14),
        const ProductCardSkeleton(),
        const SizedBox(height: 10),
        const ProductCardSkeleton(),
      ],
    );
  }
}

class SellerChatSkeleton extends StatelessWidget {
  const SellerChatSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 72, 20, 18),
          child: const Row(
            children: [
              SkeletonBox(width: 52, height: 52, shape: BoxShape.circle),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 170, height: 20),
                    SizedBox(height: 8),
                    SkeletonBox(width: 120, height: 14),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const SkeletonBox(height: 100),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              Align(
                alignment: Alignment.centerLeft,
                child: SkeletonBox(width: 210, height: 74),
              ),
              SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: SkeletonBox(width: 170, height: 68),
              ),
              SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: SkeletonBox(width: 230, height: 92),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: const Row(
            children: [
              SkeletonBox(width: 42, height: 42, shape: BoxShape.circle),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 48)),
              SizedBox(width: 10),
              SkeletonBox(width: 48, height: 48, shape: BoxShape.circle),
            ],
          ),
        ),
      ],
    );
  }
}

class UserListSkeleton extends StatelessWidget {
  const UserListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      itemCount: 5,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Container(
            margin: const EdgeInsets.only(top: 24),
            padding: const EdgeInsets.fromLTRB(20, 88, 20, 20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 190, height: 28),
                SizedBox(height: 8),
                SkeletonBox(width: 150, height: 14),
                SizedBox(height: 18),
                SkeletonBox(height: 46),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Row(
            children: [
              SkeletonBox(width: 56, height: 56, shape: BoxShape.circle),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 150, height: 18),
                    SizedBox(height: 8),
                    SkeletonBox(width: 220, height: 14),
                  ],
                ),
              ),
              SizedBox(width: 12),
              SkeletonBox(width: 52, height: 14),
            ],
          ),
        );
      },
    );
  }
}

class MainNavigationMessagesSkeleton extends StatelessWidget {
  final bool showStories;
  final bool showInvitationCard;

  const MainNavigationMessagesSkeleton({
    super.key,
    this.showStories = true,
    this.showInvitationCard = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceColor = theme.cardColor;
    final errorColor = theme.colorScheme.error;
    final isDark = theme.brightness == Brightness.dark;
    final headerBlockColor = isDark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.38)
        : theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.92);
    final tileColor = isDark
        ? theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.36)
        : surfaceColor;
    final outlineColor = isDark
        ? theme.colorScheme.outline.withValues(alpha: 0.16)
        : theme.colorScheme.outline.withValues(alpha: 0.08);
    const titleWidths = <double>[168, 144, 176, 136, 158, 149];
    const previewWidths = <double>[228, 194, 238, 172, 208, 186];
    const statusWidths = <double>[92, 116, 79, 102, 86, 108];
    const storyNameWidths = <double>[42, 55, 48, 52, 46];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: headerBlockColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: outlineColor),
                ),
                child: const Center(child: SkeletonBox(width: 14, height: 14)),
              ),
              const SizedBox(width: 10),
              const Expanded(child: SkeletonBox(height: 28, width: 150)),
              const SizedBox(width: 10),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: headerBlockColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: outlineColor),
                ),
                child: const Center(child: SkeletonBox(width: 14, height: 14)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: tileColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: outlineColor),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: const Row(
              children: [
                SkeletonBox(width: 22, height: 22),
                SizedBox(width: 12),
                Expanded(child: SkeletonBox(height: 14)),
              ],
            ),
          ),
        ),
        if (showStories) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 98,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) => SizedBox(
                width: 72,
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2.6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: index.isEven
                                  ? theme.colorScheme.primary.withValues(
                                      alpha: 0.9,
                                    )
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: 0.3,
                                    ),
                              width: index.isEven ? 2.2 : 1.1,
                            ),
                          ),
                          child: const SkeletonBox(
                            width: 56,
                            height: 56,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const Positioned(
                          right: 1,
                          bottom: 1,
                          child: SkeletonBox(
                            width: 15,
                            height: 15,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SkeletonBox(
                      width: storyNameWidths[index % storyNameWidths.length],
                      height: 13,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: tileColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: outlineColor),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Row(
                children: [
                  SkeletonBox(width: 42, height: 42, shape: BoxShape.circle),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 148, height: 15),
                        SizedBox(height: 8),
                        SkeletonBox(width: 210, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (showInvitationCard)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: tileColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: outlineColor),
              ),
              child: const Row(
                children: [
                  SkeletonBox(width: 24, height: 24),
                  SizedBox(width: 10),
                  Expanded(child: SkeletonBox(width: 188, height: 15)),
                ],
              ),
            ),
          ),
        ...List.generate(6, (index) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              14,
              index == 0 ? 4 : 2,
              14,
              index == 5 ? 0 : 2,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: tileColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: outlineColor),
              ),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: index == 0 || index == 3
                                ? theme.colorScheme.primary.withValues(
                                    alpha: 0.82,
                                  )
                                : theme.colorScheme.outline.withValues(
                                    alpha: 0.22,
                                  ),
                            width: index == 0 || index == 3 ? 1.8 : 1,
                          ),
                        ),
                        child: const SkeletonBox(
                          width: 52,
                          height: 52,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const SkeletonBox(
                            width: 14,
                            height: 14,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: titleWidths[index % titleWidths.length],
                              child: const SkeletonBox(height: 17),
                            ),
                            const SizedBox(width: 12),
                            SkeletonBox(
                              width: index.isEven ? 38 : 46,
                              height: 12,
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        if (index == 1)
                          Row(
                            children: [
                              Row(
                                children: List.generate(
                                  3,
                                  (dotIndex) => Padding(
                                    padding: EdgeInsets.only(
                                      right: dotIndex == 2 ? 8 : 4,
                                    ),
                                    child: const SkeletonBox(
                                      width: 6,
                                      height: 6,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                              const SkeletonBox(width: 74, height: 14),
                            ],
                          )
                        else
                          SkeletonBox(
                            height: 14,
                            width: previewWidths[index % previewWidths.length],
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            SkeletonBox(
                              width: statusWidths[index % statusWidths.length],
                              height: 11,
                            ),
                            if (index == 0 || index == 3) ...[
                              const SizedBox(width: 10),
                              Container(
                                constraints: const BoxConstraints(minWidth: 20),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: errorColor.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const SkeletonBox(width: 12, height: 11),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
