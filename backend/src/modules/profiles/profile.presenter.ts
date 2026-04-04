import { Prisma } from '@prisma/client';

type UserProfileRecord = Prisma.UserGetPayload<{
  include: {
    sellerProfile: true;
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
  };
}>;

export function presentUserProfile(user: UserProfileRecord) {
  return {
    id: user.id,
    phoneE164: user.phoneE164,
    countryName: user.countryName,
    countryDialCode: user.countryDialCode,
    displayName: user.displayName,
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
    isVerified: user.isVerified,
    createdAt: user.createdAt.toISOString(),
    updatedAt: user.updatedAt.toISOString(),
    sellerProfile: user.sellerProfile
      ? {
          id: user.sellerProfile.id,
          studioName: user.sellerProfile.studioName,
          description: user.sellerProfile.description,
          city: user.sellerProfile.city,
          country: user.sellerProfile.country,
          createdAt: user.sellerProfile.createdAt.toISOString(),
          updatedAt: user.sellerProfile.updatedAt.toISOString(),
        }
      : null,
  };
}

export function presentPublicSellerProfile(profile: PublicSellerProfileRecord) {
  return {
    id: profile.id,
    studioName: profile.studioName,
    description: profile.description,
    city: profile.city,
    country: profile.country,
    createdAt: profile.createdAt.toISOString(),
    updatedAt: profile.updatedAt.toISOString(),
    productCount: profile._count.products,
    isVerified: profile.user.isVerified,
    owner: {
      userId: profile.user.id,
      displayName: profile.user.displayName,
      avatarUrl: profile.user.avatarUrl,
      coverImageUrl: profile.user.coverImageUrl,
    },
  };
}