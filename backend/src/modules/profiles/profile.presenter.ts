import { Prisma } from '@prisma/client';

type UserProfileRecord = Prisma.UserGetPayload<{
  include: {
    sellerProfile: {
      include: {
        _count: {
          select: {
            products: true;
          };
        };
        products: {
          include: {
            category: true;
            _count: {
              select: {
                likes: true;
              };
            };
            productImages: {
              orderBy: {
                sortOrder: 'asc';
              };
            };
          };
        };
      };
    };
  };
}>;

type PublicSellerProfileRecord = Prisma.SellerProfileGetPayload<{
  include: {
    user: true;
    _count: {
      select: {
        products: true;
      };
    };
    products: {
      include: {
        category: true;
        _count: {
          select: {
            likes: true;
          };
        };
        productImages: {
          orderBy: {
            sortOrder: 'asc';
          };
        };
      };
      orderBy: {
        createdAt: 'desc';
      };
    };
  };
}>;

type SellerStats = {
  followerCount: number;
  profileViewCount: number;
  productCount: number;
  totalLikesCount: number;
};

const DISPLAY_NAME_CHANGE_COOLDOWN_DAYS = 7;

function addDays(date: Date, days: number) {
  const nextDate = new Date(date);
  nextDate.setDate(nextDate.getDate() + days);
  return nextDate;
}

export function presentUserProfile(user: UserProfileRecord, sellerStats?: SellerStats) {
  const nextDisplayNameChangeAt = user.displayNameChangedAt != null
    ? addDays(user.displayNameChangedAt, DISPLAY_NAME_CHANGE_COOLDOWN_DAYS)
    : null;
  const displayNameCooldownDaysRemaining = nextDisplayNameChangeAt == null
    ? 0
    : Math.max(
        0,
        Math.ceil(
          (nextDisplayNameChangeAt.getTime() - Date.now()) /
            (1000 * 60 * 60 * 24),
        ),
      );
  const productCount = user.sellerProfile?._count.products ?? 0;
  const resolvedSellerStats: SellerStats = sellerStats ?? {
    followerCount: 0,
    profileViewCount: 0,
    productCount,
    totalLikesCount: user.sellerProfile?.products.reduce(
      (sum, product) => sum + product._count.likes,
      0,
    ) ?? 0,
  };
  const sellerProducts = user.sellerProfile?.products.map((product) => ({
    images: product.productImages.length > 0
      ? product.productImages.map((image) => image.imageUrl)
      : [product.imageUrl],
    id: product.id,
    title: product.title,
    description: product.description,
    category: product.category.name,
    price: product.priceAmount.toNumber(),
    thumbnail:
      product.productImages[0]?.imageUrl ??
      product.imageUrl,
    isAvailable: product.isAvailable,
    likesCount: product._count.likes,
    createdAt: product.createdAt.toISOString(),
  })) ?? [];

  return {
    id: user.id,
    phoneE164: user.phoneE164,
    countryName: user.countryName,
    countryDialCode: user.countryDialCode,
    displayName: user.displayName,
    displayNameChangedAt: user.displayNameChangedAt?.toISOString() ?? null,
    nextDisplayNameChangeAt: nextDisplayNameChangeAt?.toISOString() ?? null,
    displayNameCooldownDaysRemaining,
    canChangeDisplayName:
      nextDisplayNameChangeAt == null || nextDisplayNameChangeAt.getTime() <= Date.now(),
    avatarUrl: user.avatarUrl,
    coverImageUrl: user.coverImageUrl,
    locationLabel: user.locationLabel,
    locationLatitude: user.locationLatitude,
    locationLongitude: user.locationLongitude,
    locationUpdatedAt: user.locationUpdatedAt?.toISOString() ?? null,
    preferredLanguage: user.preferredLanguage,
    role: user.role,
    shopRequestStatus: user.shopRequestStatus,
    shopRequestSubmittedAt: user.shopRequestSubmittedAt?.toISOString() ?? null,
    shopRequestReviewedAt: user.shopRequestReviewedAt?.toISOString() ?? null,
    sellerStats: resolvedSellerStats,
    isVerified: user.isVerified,
    isSellerCertified: user.isSellerCertified,
    sellerVerificationRequestStatus: user.sellerVerificationRequestStatus,
    sellerVerificationRequestedAt:
      user.sellerVerificationRequestedAt?.toISOString() ?? null,
    sellerVerificationReviewedAt:
      user.sellerVerificationReviewedAt?.toISOString() ?? null,
    createdAt: user.createdAt.toISOString(),
    updatedAt: user.updatedAt.toISOString(),
    sellerProfile: user.sellerProfile
      ? {
          id: user.sellerProfile.id,
          studioName: user.sellerProfile.studioName,
          description: user.sellerProfile.description,
          city: user.sellerProfile.city,
          country: user.sellerProfile.country,
          productCount: resolvedSellerStats.productCount,
          products: sellerProducts,
          createdAt: user.sellerProfile.createdAt.toISOString(),
          updatedAt: user.sellerProfile.updatedAt.toISOString(),
        }
      : null,
  };
}

export function presentPublicSellerProfile(
  profile: PublicSellerProfileRecord,
  sellerStats?: SellerStats,
  isFollowing = false,
  includeUnavailableProducts = false,
  viewerIsAdmin = false,
) {
  const resolvedSellerStats: SellerStats = sellerStats ?? {
    followerCount: 0,
    profileViewCount: 0,
    productCount: profile._count.products,
    totalLikesCount: profile.products.reduce(
      (sum, product) => sum + product._count.likes,
      0,
    ),
  };

  return {
    id: profile.id,
    studioName: profile.studioName,
    description: profile.description,
    city: profile.city,
    country: profile.country,
    createdAt: profile.createdAt.toISOString(),
    updatedAt: profile.updatedAt.toISOString(),
    productCount: resolvedSellerStats.productCount,
    sellerStats: resolvedSellerStats,
    isFollowing,
    products: profile.products
      .filter((product) => includeUnavailableProducts || product.isAvailable)
      .map((product) => ({
        id: product.id,
        title: product.title,
        description: product.description,
        category: product.category.name,
        price: product.priceAmount.toNumber(),
        images: product.productImages.length > 0
          ? product.productImages.map((image) => image.imageUrl)
          : [product.imageUrl],
        thumbnail: product.productImages[0]?.imageUrl ?? product.imageUrl,
        isAvailable: product.isAvailable,
        likesCount: product._count.likes,
        createdAt: product.createdAt.toISOString(),
      })),
    isVerified: profile.user.isVerified,
    isSellerCertified: profile.user.isSellerCertified,
    owner: {
      userId: profile.user.id,
      displayName: profile.user.displayName,
      avatarUrl: profile.user.avatarUrl,
      coverImageUrl: profile.user.coverImageUrl,
      lastSeenAt: profile.user.lastSeenAt?.toISOString() ?? null,
      createdAt: profile.user.createdAt.toISOString(),
      locationLabel: profile.user.locationLabel,
      phoneE164: viewerIsAdmin ? profile.user.phoneE164 : null,
    },
  };
}

export function presentPublicUserProfile(
  user: UserProfileRecord,
  sellerStats?: SellerStats,
  viewerIsAdmin = false,
) {
  const productCount = user.sellerProfile?._count.products ?? 0;
  const resolvedSellerStats: SellerStats = sellerStats ?? {
    followerCount: 0,
    profileViewCount: 0,
    productCount,
    totalLikesCount: user.sellerProfile?.products.reduce(
      (sum, product) => sum + product._count.likes,
      0,
    ) ?? 0,
  };

  return {
    id: user.id,
    displayName: user.displayName,
    avatarUrl: user.avatarUrl,
    coverImageUrl: user.coverImageUrl,
    locationLabel: user.locationLabel,
    role: user.role,
    phoneE164: viewerIsAdmin ? user.phoneE164 : null,
    isVerified: user.isVerified,
    isSellerCertified: user.isSellerCertified,
    createdAt: user.createdAt.toISOString(),
    sellerStats: resolvedSellerStats,
    sellerProfile: user.sellerProfile
      ? {
          id: user.sellerProfile.id,
          studioName: user.sellerProfile.studioName,
          description: user.sellerProfile.description,
          city: user.sellerProfile.city,
          country: user.sellerProfile.country,
        }
      : null,
  };
}