import { Injectable } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';

type ViewerSearchContext = {
  normalizedLocationLabel: string;
  normalizedCountryName: string;
  locationLatitude: number | null;
  locationLongitude: number | null;
  locationTokens: string[];
};

type RankedSearchItem = {
  label: string;
  locationLabel?: string | null;
  locationLatitude?: number | null;
  locationLongitude?: number | null;
};

@Injectable()
export class SearchService {
  constructor(private readonly prisma: PrismaService) {}

  private normalizeQuery(query: string) {
    return query.trim().toLowerCase();
  }

  private joinNonEmpty(values: Array<string | null | undefined>) {
    return values
      .filter((value): value is string => Boolean(value && value.trim().length > 0))
      .join(', ');
  }

  private clampLimit(limit: number, fallback: number, max: number) {
    return Number.isFinite(limit) ? Math.min(Math.max(limit, 1), max) : fallback;
  }

  private extractLocationTokens(...values: Array<string | null | undefined>) {
    return Array.from(
      new Set(
        values
          .flatMap((value) =>
            (value ?? '')
              .split(',')
              .map((part) => this.normalizeQuery(part))
              .filter((part) => part.length >= 3),
          )
          .filter((part) => part.length >= 3),
      ),
    );
  }

  private toNullableNumber(value: unknown) {
    if (typeof value !== 'number' || Number.isNaN(value)) {
      return null;
    }

    return value;
  }

  private computeDistanceInKm(
    firstLatitude: number,
    firstLongitude: number,
    secondLatitude: number,
    secondLongitude: number,
  ) {
    const toRadians = (degrees: number) => (degrees * Math.PI) / 180;
    const earthRadiusKm = 6371;
    const latitudeDelta = toRadians(secondLatitude - firstLatitude);
    const longitudeDelta = toRadians(secondLongitude - firstLongitude);
    const normalizedFirstLatitude = toRadians(firstLatitude);
    const normalizedSecondLatitude = toRadians(secondLatitude);
    const haversine =
      Math.sin(latitudeDelta / 2) * Math.sin(latitudeDelta / 2) +
      Math.cos(normalizedFirstLatitude) *
        Math.cos(normalizedSecondLatitude) *
        Math.sin(longitudeDelta / 2) *
        Math.sin(longitudeDelta / 2);

    return earthRadiusKm * 2 * Math.atan2(Math.sqrt(haversine), Math.sqrt(1 - haversine));
  }

  private computeLocationBoost(
    item: RankedSearchItem,
    context: ViewerSearchContext | null,
  ) {
    if (context == null) {
      return 0;
    }

    let score = 0;
    const normalizedLocationLabel = this.normalizeQuery(item.locationLabel ?? '');

    if (normalizedLocationLabel !== '') {
      if (
        context.normalizedLocationLabel !== '' &&
        normalizedLocationLabel === context.normalizedLocationLabel
      ) {
        score += 40;
      } else if (
        context.normalizedLocationLabel !== '' &&
        normalizedLocationLabel.includes(context.normalizedLocationLabel)
      ) {
        score += 26;
      }

      for (const token of context.locationTokens) {
        if (normalizedLocationLabel.includes(token)) {
          score += 10;
        }
      }

      if (
        context.normalizedCountryName !== '' &&
        normalizedLocationLabel.includes(context.normalizedCountryName)
      ) {
        score += 8;
      }
    }

    if (
      context.locationLatitude != null &&
      context.locationLongitude != null &&
      item.locationLatitude != null &&
      item.locationLongitude != null
    ) {
      const distanceInKm = this.computeDistanceInKm(
        context.locationLatitude,
        context.locationLongitude,
        item.locationLatitude,
        item.locationLongitude,
      );

      if (distanceInKm <= 15) {
        score += 40;
      } else if (distanceInKm <= 50) {
        score += 28;
      } else if (distanceInKm <= 150) {
        score += 18;
      } else if (distanceInKm <= 400) {
        score += 10;
      }
    }

    return score;
  }

  private rankItems<T extends RankedSearchItem>(
    items: T[],
    query: string,
    context: ViewerSearchContext | null,
  ) {
    const normalizedQuery = this.normalizeQuery(query);

    return [...items].sort((left, right) => {
      const leftLabel = this.normalizeQuery(left.label);
      const rightLabel = this.normalizeQuery(right.label);
      const leftScore =
        this.computeLocationBoost(left, context) +
        (normalizedQuery !== '' && leftLabel.startsWith(normalizedQuery)
          ? 18
          : leftLabel.includes(normalizedQuery)
            ? 8
            : 0);
      const rightScore =
        this.computeLocationBoost(right, context) +
        (normalizedQuery !== '' && rightLabel.startsWith(normalizedQuery)
          ? 18
          : rightLabel.includes(normalizedQuery)
            ? 8
            : 0);

      if (leftScore !== rightScore) {
        return rightScore - leftScore;
      }

      return left.label.localeCompare(right.label);
    });
  }

  private async resolveViewerContext(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        locationLabel: true,
        locationLatitude: true,
        locationLongitude: true,
        countryName: true,
      },
    });

    if (user == null) {
      return null;
    }

    return {
      normalizedLocationLabel: this.normalizeQuery(user.locationLabel ?? ''),
      normalizedCountryName: this.normalizeQuery(user.countryName ?? ''),
      locationLatitude: this.toNullableNumber(user.locationLatitude),
      locationLongitude: this.toNullableNumber(user.locationLongitude),
      locationTokens: this.extractLocationTokens(user.locationLabel, user.countryName),
    } as ViewerSearchContext;
  }

  async autocomplete(params: { userId: string; query: string; limit: number }) {
    const normalizedQuery = params.query.trim();
    const take = this.clampLimit(params.limit, 6, 10);
    const viewerContext = await this.resolveViewerContext(params.userId);
    const branchTake = Math.min(Math.max(take, 4), 8);

    const [users, products, categories, locations] = await Promise.all([
      this.findAutocompleteUsers(normalizedQuery, branchTake, viewerContext),
      this.findProducts(normalizedQuery, branchTake, viewerContext),
      this.findCategories(normalizedQuery, Math.min(branchTake, 5)),
      this.findLocations(normalizedQuery, Math.min(branchTake, 5)),
    ]);

    const rankedResults = [
      ...users.map((user) => ({ type: 'user' as const, ...user })),
      ...products.map((product) => ({ type: 'product' as const, ...product })),
      ...categories.map((category) => ({ type: 'category' as const, ...category })),
      ...locations.map((location) => ({ type: 'location' as const, ...location })),
    ]
      .map((item, index) => {
        const normalizedLabel = this.normalizeQuery(item.label);
        const normalizedSubtitle = this.normalizeQuery(
          'subtitle' in item && typeof item.subtitle === 'string' ? item.subtitle : '',
        );
        const typePriority =
          item.type === 'user' ? 4 : item.type === 'product' ? 3 : item.type === 'category' ? 2 : 1;
        const textScore =
          normalizedQuery !== '' && normalizedLabel === normalizedQuery
            ? 80
            : normalizedQuery !== '' && normalizedLabel.startsWith(normalizedQuery)
              ? 42
              : normalizedQuery !== '' && normalizedLabel.includes(normalizedQuery)
                ? 18
                : normalizedQuery !== '' && normalizedSubtitle.includes(normalizedQuery)
                  ? 10
                  : 0;

        return {
          item,
          index,
          score: textScore + typePriority,
        };
      })
      .sort((left, right) => {
        if (left.score !== right.score) {
          return right.score - left.score;
        }

        return left.index - right.index;
      })
      .slice(0, take)
      .map(({ item }) => item);

    return {
      query: normalizedQuery,
      results: rankedResults,
      counts: {
        products: products.length,
        users: users.length,
        categories: categories.length,
        locations: locations.length,
      },
    };
  }

  async search(params: { userId: string; query: string; limit: number }) {
    const normalizedQuery = params.query.trim();
    const take = this.clampLimit(params.limit, 24, 40);
    const viewerContext = await this.resolveViewerContext(params.userId);

    const [products, users, categories, locations] = await Promise.all([
      this.findProducts(normalizedQuery, take, viewerContext),
      this.findUsers(normalizedQuery, take, viewerContext),
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

  async recordSearchHistory(params: {
    userId: string;
    query: string;
    resultCount: number;
  }) {
    const query = params.query.trim();
    const normalizedQuery = this.normalizeQuery(query);

    if (!query || !normalizedQuery) {
      return null;
    }

    const resultCount = Number.isFinite(params.resultCount)
      ? Math.max(0, Math.trunc(params.resultCount))
      : 0;

    const existing = await this.prisma.searchHistory.findUnique({
      where: {
        userId_normalizedQuery: {
          userId: params.userId,
          normalizedQuery,
        },
      },
    });

    const history = existing
      ? await this.prisma.searchHistory.update({
          where: { id: existing.id },
          data: {
            query,
            resultCount,
            lastSearchedAt: new Date(),
            occurrenceCount: {
              increment: 1,
            },
          },
        })
      : await this.prisma.searchHistory.create({
          data: {
            userId: params.userId,
            query,
            normalizedQuery,
            resultCount,
          },
        });

    return this.mapSearchHistory(history);
  }

  async findNoResultHistory(userId: string) {
    const histories = await this.prisma.searchHistory.findMany({
      where: {
        userId,
        resultCount: 0,
      },
      orderBy: {
        lastSearchedAt: 'desc',
      },
      take: 50,
    });

    return histories.map((history) => this.mapSearchHistory(history));
  }

  private mapSearchHistory(history: {
    id: string;
    query: string;
    resultCount: number;
    occurrenceCount: number;
    createdAt: Date;
    updatedAt: Date;
    lastSearchedAt: Date;
  }) {
    return {
      id: history.id,
      query: history.query,
      resultCount: history.resultCount,
      occurrenceCount: history.occurrenceCount,
      createdAt: history.createdAt.toISOString(),
      updatedAt: history.updatedAt.toISOString(),
      lastSearchedAt: history.lastSearchedAt.toISOString(),
    };
  }

  private async findProducts(
    query: string,
    take: number,
    viewerContext: ViewerSearchContext | null,
  ) {
    const fetchTake = Math.min(take * 3, 60);
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
      take: fetchTake,
    });

    const rankedProducts = this.rankItems(
      products.map((product) => ({
        id: product.id,
        label: product.title,
        subtitle: `Produit chez ${product.sellerProfile.studioName}`,
        sellerName: product.sellerProfile.user.displayName,
        categoryName: product.category.name,
        locationLabel: this.joinNonEmpty([
          product.sellerProfile.city,
          product.sellerProfile.country,
          product.sellerProfile.user.locationLabel,
        ]),
        locationLatitude: this.toNullableNumber(product.sellerProfile.user.locationLatitude),
        locationLongitude: this.toNullableNumber(product.sellerProfile.user.locationLongitude),
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
      })),
      query,
      viewerContext,
    ).slice(0, take);

    return rankedProducts.map(({ locationLatitude, locationLongitude, ...product }) => ({
      ...product,
    }));
  }

  private async findAutocompleteUsers(
    query: string,
    take: number,
    viewerContext: ViewerSearchContext | null,
  ) {
    const users = await this.prisma.user.findMany({
      where: query
        ? {
            OR: [
              { displayName: { contains: query, mode: 'insensitive' as const } },
              {
                sellerProfile: {
                  is: {
                    studioName: { contains: query, mode: 'insensitive' as const },
                  },
                },
              },
            ],
          }
        : undefined,
      select: {
        id: true,
        displayName: true,
        avatarUrl: true,
        coverImageUrl: true,
        isVerified: true,
        isSellerCertified: true,
        locationLabel: true,
        locationLatitude: true,
        locationLongitude: true,
        countryName: true,
        sellerProfile: {
          select: {
            id: true,
            studioName: true,
            city: true,
            country: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: Math.min(take * 3, 30),
    });

    return this.rankItems(
      users.map((user) => ({
        id: user.id,
        label: user.displayName,
        subtitle: user.sellerProfile?.studioName ?? 'Utilisateur BANAY',
        sellerName: user.displayName,
        locationLabel: this.joinNonEmpty([
          user.locationLabel,
          user.sellerProfile?.city,
          user.sellerProfile?.country,
          user.countryName,
        ]),
        locationLatitude: this.toNullableNumber(user.locationLatitude),
        locationLongitude: this.toNullableNumber(user.locationLongitude),
        imageUrl: user.avatarUrl,
        description: user.sellerProfile?.studioName ?? user.countryName ?? 'Utilisateur BANAY',
      })),
      query,
      viewerContext,
    )
      .slice(0, take)
      .map(({ locationLatitude, locationLongitude, ...user }) => ({ ...user }));
  }

  private async findUsers(
    query: string,
    take: number,
    viewerContext: ViewerSearchContext | null,
  ) {
    const fetchTake = Math.min(take * 3, 60);
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
      take: fetchTake,
    });

    const rankedUsers = this.rankItems(
      users.map((user) => {
        const locationLabel = this.joinNonEmpty([
          user.locationLabel,
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
          (user.countryName != null && user.countryName.trim().length > 0
            ? `Utilisateur BANAY de ${user.countryName}.`
            : 'Utilisateur BANAY.');
        const totalLikesCount = sellerProducts.reduce(
          (sum, product) => sum + product._count.likes,
          0,
        );

        return {
          id: user.id,
          label: user.displayName,
          subtitle: user.sellerProfile?.studioName ?? 'Utilisateur BANAY',
          sellerName: user.displayName,
          categoryName: sellerProducts[0]?.title,
          locationLabel,
          locationLatitude: this.toNullableNumber(user.locationLatitude),
          locationLongitude: this.toNullableNumber(user.locationLongitude),
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
            roleLabel: user.sellerProfile != null
                ? (user.isSellerCertified ? 'Vendeur certifie' : 'Vendeur')
                : (user.isVerified ? 'Utilisateur verifie' : 'Utilisateur'),
            responseLabel: 'Profil actif',
            headline,
            about: description,
            followerCount: `${user.sellerProfile?.followers.length ?? 0}`,
            visitorCount: `${user.sellerProfile?.profileViews.length ?? 0}`,
            rating: '4.8',
            products: sellerProducts.map((product) => ({
              'id': product.id,
              'title': product.title,
              'category': 'Produit BANAY',
              'price': product.priceAmount.toNumber(),
              'likesCount': product._count.likes,
              'images': [product.imageUrl],
              'thumbnail': product.imageUrl,
            })),
            totalLikesCount: `${totalLikesCount}`,
            sellerProfileId: user.sellerProfile?.id,
          },
        };
      }),
      query,
      viewerContext,
    ).slice(0, take);

    return rankedUsers.map(({ locationLatitude, locationLongitude, ...user }) => ({
      ...user,
    }));
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
      description: 'Categorie BANAY',
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
