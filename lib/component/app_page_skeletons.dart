import 'package:flutter/material.dart';

import 'package:bahibo/component/app_network_image.dart';

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
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.outlineVariant.withValues(alpha: 0.24)
        : theme.colorScheme.onSurface.withValues(alpha: 0.08);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(width: 1, color: borderColor),
        borderRadius: BorderRadius.circular(10),
        color: theme.cardColor,
      ),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Row(
          children: [
            const Expanded(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: SkeletonBox(width: 70, height: 170),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(width: 170, height: 20),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      SkeletonBox(width: 15, height: 15),
                      SizedBox(width: 4),
                      SkeletonBox(width: 120, height: 15),
                    ],
                  ),
                  SizedBox(height: 4),
                  SkeletonBox(width: 120, height: 15),
                  SizedBox(height: 30),
                  SkeletonBox(width: 120, height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
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
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SkeletonBox(width: 170, height: 18),
        ),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: 5,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) {
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
        const SizedBox(height: 40),
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
                  children: [
                    SkeletonBox(width: 180, height: 18),
                    SizedBox(height: 8),
                    SkeletonBox(width: 120, height: 14),
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
      separatorBuilder: (_, __) => const SizedBox(height: 12),
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
