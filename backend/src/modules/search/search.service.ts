import { Injectable } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class SearchService {
  constructor(private readonly prisma: PrismaService) {}

  private joinNonEmpty(values: Array<string | null | undefined>) {
    return values
      .filter((value): value is string => Boolean(value && value.trim().length > 0))
      .join(', ');
  }

  async search(params: { query: string; limit: number }) {
    const normalizedQuery = params.query.trim();
    const take = Number.isFinite(params.limit)
      ? Math.min(Math.max(params.limit, 1), 40)
      : 24;

    const [products, users, categories, locations] = await Promise.all([
      this.findProducts(normalizedQuery, take),
      this.findUsers(normalizedQuery, take),
      this.findCategories(normalizedQuery, take),
      this.findLocations(normalizedQuery, take),
    ]);

    return {
      query: normalizedQuery,
      results: [
        ...products.map((product) => ({ type: 'product' as const, ...product })),
        ...users.map((user) => ({ type: 'user' as const, ...user })),
        ...categories.map((category) => ({ type: 'category' as const, ...category })),
        ...locations.map((location) => ({ type: 'location' as const, ...location })),
      ],
      counts: {
        products: products.length,
        users: users.length,
        categories: categories.length,
        locations: locations.length,
      },
    };
  }

  private async findProducts(query: string, take: number) {
    const where = query
      ? {
          OR: [
            { title: { contains: query, mode: 'insensitive' as const } },
            { description: { contains: query, mode: 'insensitive' as const } },
            {
              category: {
                name: { contains: query, mode: 'insensitive' as const },
              },
            },
            {
              sellerProfile: {
                studioName: { contains: query, mode: 'insensitive' as const },
              },
            },
            {
              sellerProfile: {
                city: { contains: query, mode: 'insensitive' as const },
              },
            },
            {
              sellerProfile: {
                country: { contains: query, mode: 'insensitive' as const },
              },
            },
            {
              sellerProfile: {
                user: {
                  displayName: { contains: query, mode: 'insensitive' as const },
                },
              },
            },
          ],
        }
      : undefined;

    const products = await this.prisma.product.findMany({
      where,
      include: {
        category: true,
        _count: {
          select: {
            likes: true,
          },
        },
        sellerProfile: {
          include: {
            user: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      take,
    });

    return products.map((product) => ({
      id: product.id,
      label: product.title,
      subtitle: `Produit chez ${product.sellerProfile.studioName}`,
      sellerName: product.sellerProfile.user.displayName,
      categoryName: product.category.name,
      locationLabel: this.joinNonEmpty([
        product.sellerProfile.city,
        product.sellerProfile.country,
      ]),
      imageUrl: product.imageUrl,
      description: product.description,
      productData: {
        id: product.id,
        title: product.title,
        description: product.description,
        price: product.priceAmount.toNumber(),
        currency: product.currencyCode,
        category: product.category.name,
        categoryId: product.categoryId,
        seller: {
          id: product.sellerProfile.id,
          userId: product.sellerProfile.userId,
          name: product.sellerProfile.user.displayName,
          avatarUrl: product.sellerProfile.user.avatarUrl,
        },
        sellerName: product.sellerProfile.user.displayName,
        sellerAvatarUrl: product.sellerProfile.user.avatarUrl,
        sellerRole: 'Vendeur',
        images: [product.imageUrl],
        thumbnail: product.imageUrl,
        isAvailable: product.isAvailable,
        likesCount: product._count.likes,
        createdAt: product.createdAt.toISOString(),
      },
    }));
  }

  private async findUsers(query: string, take: number) {
    const where = query
      ? {
          OR: [
            { displayName: { contains: query, mode: 'insensitive' as const } },
            { phoneE164: { contains: query, mode: 'insensitive' as const } },
            { countryName: { contains: query, mode: 'insensitive' as const } },
            { countryDialCode: { contains: query, mode: 'insensitive' as const } },
            {
              sellerProfile: {
                is: {
                  studioName: { contains: query, mode: 'insensitive' as const },
                },
              },
            },
            {
              sellerProfile: {
                is: {
                  city: { contains: query, mode: 'insensitive' as const },
                },
              },
            },
            {
              sellerProfile: {
                is: {
                  country: { contains: query, mode: 'insensitive' as const },
                },
              },
            },
          ],
        }
      : undefined;

    const users = await this.prisma.user.findMany({
      where,
      include: {
        sellerProfile: {
          include: {
            followers: true,
            profileViews: true,
            products: {
              include: {
                _count: {
                  select: {
                    likes: true,
                  },
                },
              },
              orderBy: { createdAt: 'desc' },
              take: 6,
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      take,
    });

    return users.map((user) => {
      const locationLabel = this.joinNonEmpty([
        user.sellerProfile?.city,
        user.sellerProfile?.country,
        user.countryName,
      ]);
      const sellerProducts = user.sellerProfile?.products ?? [];
      const headline = user.sellerProfile != null
        ? [user.sellerProfile.studioName, locationLabel]
            .filter((value) => value.trim().length > 0)
            .join(' · ')
        : [user.countryName, user.phoneE164]
            .filter((value) => Boolean(value && value.trim().length > 0))
            .join(' · ');
      const description = user.sellerProfile?.description ??
        (user.countryName != null && user.countryName!.trim().length > 0
          ? `Utilisateur Bahibo de ${user.countryName}.`
          : 'Utilisateur Bahibo.');
      const totalLikesCount = sellerProducts.reduce(
        (sum, product) => sum + product._count.likes,
        0,
      );

      return {
        id: user.id,
        label: user.displayName,
        subtitle: user.sellerProfile?.studioName ?? 'Utilisateur Bahibo',
        sellerName: user.displayName,
        categoryName: sellerProducts[0]?.title,
        locationLabel,
        imageUrl: user.avatarUrl,
        description,
        sellerProfile: {
          userId: user.id,
          name: user.displayName,
          avatarUrl:
            user.avatarUrl ??
            'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=600',
          coverImageUrl:
            user.coverImageUrl ??
            'https://images.unsplash.com/photo-1520607162513-77705c0f0d4a?w=1600',
          roleLabel: user.sellerProfile != null ? 'Vendeur certifie' : 'Utilisateur verifie',
          responseLabel: 'Profil actif',
          headline,
          about: description,
          followerCount: `${user.sellerProfile?.followers.length ?? 0}`,
          visitorCount: `${user.sellerProfile?.profileViews.length ?? 0}`,
          rating: '4.8',
          products: sellerProducts.map((product) => ({
            'id': product.id,
            'title': product.title,
            'category': 'Produit Bahibo',
            'price': product.priceAmount.toNumber(),
            'likesCount': product._count.likes,
            'images': [product.imageUrl],
            'thumbnail': product.imageUrl,
          })),
          totalLikesCount: `${totalLikesCount}`,
          sellerProfileId: user.sellerProfile?.id,
        },
      };
    });
  }

  private async findCategories(query: string, take: number) {
    const categories = await this.prisma.category.findMany({
      where: query
        ? {
            name: {
              contains: query,
              mode: 'insensitive',
            },
          }
        : undefined,
      include: {
        _count: {
          select: {
            products: true,
          },
        },
      },
      orderBy: { name: 'asc' },
      take,
    });

    return categories.map((category) => ({
      id: category.id,
      label: category.name,
      subtitle: `${category._count.products} produits`,
      categoryName: category.name,
      description: 'Categorie Bahibo',
    }));
  }

  private async findLocations(query: string, take: number) {
    const profiles = await this.prisma.sellerProfile.findMany({
      where: query
        ? {
            OR: [
              { city: { contains: query, mode: 'insensitive' } },
              { country: { contains: query, mode: 'insensitive' } },
            ],
          }
        : {
            OR: [{ city: { not: null } }, { country: { not: null } }],
          },
      select: {
        city: true,
        country: true,
      },
      take: take * 2,
    });

    const uniqueLocations = new Map<string, { city?: string | null; country?: string | null }>();

    for (const profile of profiles) {
      const label = this.joinNonEmpty([profile.city, profile.country]);

      if (!label) {
        continue;
      }

      if (!uniqueLocations.has(label)) {
        uniqueLocations.set(label, profile);
      }
    }

    return Array.from(uniqueLocations.entries())
      .slice(0, take)
      .map(([label, profile]) => ({
        id: label,
        label,
        subtitle: 'Lieu',
        locationLabel: label,
        description: this.joinNonEmpty([profile.city, profile.country]),
      }));
  }
}