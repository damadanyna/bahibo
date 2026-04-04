import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, ShopRequestStatus, UserRole } from '@prisma/client';

import { CloudinaryService } from '../auth/cloudinary.service';
import { ConversationsRealtimeGateway } from '../conversations/realtime/conversations-realtime.gateway';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateProfileDto, UpdateSellerProfileDto } from './dto/update-profile.dto';
import { presentPublicSellerProfile, presentUserProfile } from './profile.presenter';

@Injectable()
export class ProfilesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly cloudinaryService: CloudinaryService,
    private readonly conversationsRealtimeGateway: ConversationsRealtimeGateway,
  ) {}

  async getCurrentUserProfile(userId: string) {
    const user = await this.findUserProfileById(userId, this.prisma);
    const sellerStats = user.sellerProfile
      ? await this.buildSellerStats(user.sellerProfile.id)
      : undefined;
    return presentUserProfile(user, sellerStats);
  }

  async updateCurrentUserProfile(userId: string, dto: UpdateProfileDto) {
    await this.prisma.$transaction(async (transaction) => {
      const existingUser = await this.findUserProfileById(userId, transaction);
      const userData = this.buildUserUpdateData(existingUser, dto);
      const sellerProfileData = this.buildSellerProfileUpdateData(dto.sellerProfile);

      if (Object.keys(userData).length > 0) {
        await transaction.user.update({
          where: { id: userId },
          data: userData,
        });
      }

      if (sellerProfileData) {
        await transaction.sellerProfile.upsert({
          where: { userId },
          update: sellerProfileData,
          create: {
            userId,
            studioName: sellerProfileData.studioName ?? existingUser.displayName,
            description: sellerProfileData.description,
            city: sellerProfileData.city,
            country: sellerProfileData.country,
          },
        });
      }
    });

    const profile = await this.getCurrentUserProfile(userId);
    this.emitProfileUpdated(profile);
    return profile;
  }

  async getPublicSellerProfile(sellerProfileId: string) {
    const sellerProfile = await this.prisma.sellerProfile.findUnique({
      where: { id: sellerProfileId },
      include: {
        user: true,
        _count: {
          select: {
            products: true,
          },
        },
        products: {
          include: {
            category: true,
            _count: {
              select: {
                likes: true,
              },
            },
            productImages: {
              orderBy: {
                sortOrder: 'asc',
              },
            },
          },
          orderBy: {
            createdAt: 'desc',
          },
        },
      },
    });

    if (!sellerProfile) {
      throw new NotFoundException('Seller profile not found');
    }

    const sellerStats = await this.buildSellerStats(sellerProfileId);
    return presentPublicSellerProfile(sellerProfile, sellerStats, false);
  }

  async getPublicSellerProfileForViewer(sellerProfileId: string, viewerUserId: string) {
    const sellerProfile = await this.prisma.sellerProfile.findUnique({
      where: { id: sellerProfileId },
      include: {
        user: true,
        _count: {
          select: {
            products: true,
          },
        },
        products: {
          include: {
            category: true,
            _count: {
              select: {
                likes: true,
              },
            },
            productImages: {
              orderBy: {
                sortOrder: 'asc',
              },
            },
          },
          orderBy: {
            createdAt: 'desc',
          },
        },
      },
    });

    if (!sellerProfile) {
      throw new NotFoundException('Seller profile not found');
    }

    const [sellerStats, existingFollow] = await Promise.all([
      this.buildSellerStats(sellerProfileId),
      this.prisma.sellerFollow.findUnique({
        where: {
          followerUserId_sellerProfileId: {
            followerUserId: viewerUserId,
            sellerProfileId,
          },
        },
      }),
    ]);

    return presentPublicSellerProfile(
      sellerProfile,
      sellerStats,
      existingFollow != null,
    );
  }

  async followSeller(viewerUserId: string, sellerProfileId: string) {
    const sellerProfile = await this.prisma.sellerProfile.findUnique({
      where: { id: sellerProfileId },
      include: {
        user: true,
      },
    });

    if (!sellerProfile) {
      throw new NotFoundException('Seller profile not found');
    }

    if (sellerProfile.userId === viewerUserId) {
      throw new BadRequestException('Impossible de s\'abonner a son propre profil.');
    }

    await this.prisma.sellerFollow.upsert({
      where: {
        followerUserId_sellerProfileId: {
          followerUserId: viewerUserId,
          sellerProfileId,
        },
      },
      create: {
        followerUserId: viewerUserId,
        sellerProfileId,
      },
      update: {},
    });

    await this.emitSellerMetricsProfileUpdate(sellerProfile.userId);
    return this.getPublicSellerProfileForViewer(sellerProfileId, viewerUserId);
  }

  async unfollowSeller(viewerUserId: string, sellerProfileId: string) {
    const sellerProfile = await this.prisma.sellerProfile.findUnique({
      where: { id: sellerProfileId },
      include: {
        user: true,
      },
    });

    if (!sellerProfile) {
      throw new NotFoundException('Seller profile not found');
    }

    await this.prisma.sellerFollow.deleteMany({
      where: {
        followerUserId: viewerUserId,
        sellerProfileId,
      },
    });

    await this.emitSellerMetricsProfileUpdate(sellerProfile.userId);
    return this.getPublicSellerProfileForViewer(sellerProfileId, viewerUserId);
  }

  async recordSellerProfileView(viewerUserId: string, sellerProfileId: string) {
    const sellerProfile = await this.prisma.sellerProfile.findUnique({
      where: { id: sellerProfileId },
      include: {
        user: true,
      },
    });

    if (!sellerProfile) {
      throw new NotFoundException('Seller profile not found');
    }

    if (sellerProfile.userId !== viewerUserId) {
      await this.prisma.sellerProfileView.create({
        data: {
          sellerProfileId,
          viewerUserId,
        },
      });

      await this.emitSellerMetricsProfileUpdate(sellerProfile.userId);
    }

    return this.getPublicSellerProfileForViewer(sellerProfileId, viewerUserId);
  }

  async updateCurrentUserAvatarImage(
    userId: string,
    file: Express.Multer.File | undefined,
  ) {
    return this.updateCurrentUserImage(userId, file, 'avatar');
  }

  async updateCurrentUserCoverImage(
    userId: string,
    file: Express.Multer.File | undefined,
  ) {
    return this.updateCurrentUserImage(userId, file, 'cover');
  }

  async submitShopRequest(userId: string) {
    const user = await this.findUserProfileById(userId, this.prisma);

    if (user.role === UserRole.SELLER) {
      throw new BadRequestException('Ce compte est deja une boutique.');
    }

    if (user.shopRequestStatus === ShopRequestStatus.PENDING) {
      const profile = await this.getCurrentUserProfile(userId);
      this.emitShopRequestProfileUpdate(profile);
      return profile;
    }

    await this.prisma.user.update({
      where: { id: userId },
      data: {
        shopRequestStatus: ShopRequestStatus.PENDING,
        shopRequestSubmittedAt: new Date(),
        shopRequestReviewedAt: null,
      },
    });

    const profile = await this.getCurrentUserProfile(userId);
    this.emitShopRequestProfileUpdate(profile);
    return profile;
  }

  async listPendingShopRequests() {
    const users = await this.prisma.user.findMany({
      where: {
        shopRequestStatus: ShopRequestStatus.PENDING,
      },
      orderBy: {
        shopRequestSubmittedAt: 'asc',
      },
      include: {
        sellerProfile: true,
      },
    });

    return users.map((user) => ({
      id: user.id,
      displayName: user.displayName,
      phoneE164: user.phoneE164,
      avatarUrl: user.avatarUrl,
      coverImageUrl: user.coverImageUrl,
      locationLabel: user.locationLabel,
      role: user.role,
      isVerified: user.isVerified,
      shopRequestStatus: user.shopRequestStatus,
      shopRequestSubmittedAt: user.shopRequestSubmittedAt?.toISOString() ?? null,
      createdAt: user.createdAt.toISOString(),
      sellerProfile: user.sellerProfile
        ? {
            id: user.sellerProfile.id,
            studioName: user.sellerProfile.studioName,
            description: user.sellerProfile.description,
            city: user.sellerProfile.city,
            country: user.sellerProfile.country,
          }
        : null,
    }));
  }

  async approveShopRequest(userId: string) {
    const user = await this.findUserProfileById(userId, this.prisma);

    if (user.shopRequestStatus !== ShopRequestStatus.PENDING) {
      throw new BadRequestException('No pending shop request found for this user.');
    }

    await this.prisma.$transaction(async (transaction) => {
      await transaction.user.update({
        where: { id: userId },
        data: {
          role: UserRole.SELLER,
          shopRequestStatus: ShopRequestStatus.APPROVED,
          shopRequestReviewedAt: new Date(),
        },
      });

      if (!user.sellerProfile) {
        await transaction.sellerProfile.create({
          data: {
            userId,
            studioName: user.displayName,
          },
        });
      }
    });

    const profile = await this.getCurrentUserProfile(userId);
    this.emitShopRequestProfileUpdate(profile);
    return profile;
  }

  async resetShopRequestToPending(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        sellerProfile: {
          include: {
            _count: {
              select: {
                products: true,
                orders: true,
              },
            },
          },
        },
      },
    });

    if (!user) {
      throw new NotFoundException('User profile not found');
    }

    if (user.shopRequestStatus === ShopRequestStatus.PENDING) {
      const profile = await this.getCurrentUserProfile(userId);
      this.emitShopRequestProfileUpdate(profile);
      return profile;
    }

    if (
      user.sellerProfile &&
      (user.sellerProfile._count.products > 0 || user.sellerProfile._count.orders > 0)
    ) {
      throw new BadRequestException(
        'Impossible de remettre cette demande en attente car la boutique a deja des produits ou des commandes.',
      );
    }

    await this.prisma.$transaction(async (transaction) => {
      await transaction.user.update({
        where: { id: userId },
        data: {
          role: UserRole.CUSTOMER,
          shopRequestStatus: ShopRequestStatus.PENDING,
          shopRequestSubmittedAt: user.shopRequestSubmittedAt ?? new Date(),
          shopRequestReviewedAt: null,
        },
      });

      if (user.sellerProfile) {
        await transaction.sellerProfile.delete({
          where: { userId },
        });
      }
    });

    const profile = await this.getCurrentUserProfile(userId);
    this.emitShopRequestProfileUpdate(profile);
    return profile;
  }

  private emitShopRequestProfileUpdate(profile: Awaited<ReturnType<ProfilesService['getCurrentUserProfile']>>) {
    this.conversationsRealtimeGateway.emitProfileEvent(profile.id, {
      type: 'profile:shop-request-updated',
      userId: profile.id,
      profile: {
        id: profile.id,
        role: profile.role,
        shopRequestStatus: profile.shopRequestStatus,
        shopRequestSubmittedAt: profile.shopRequestSubmittedAt,
        shopRequestReviewedAt: profile.shopRequestReviewedAt,
        sellerProfile: profile.sellerProfile,
      },
    });
  }

  private emitProfileUpdated(profile: Awaited<ReturnType<ProfilesService['getCurrentUserProfile']>>) {
    this.conversationsRealtimeGateway.emitProfileEvent(profile.id, {
      type: 'profile:updated',
      userId: profile.id,
      profile: {
        id: profile.id,
        role: profile.role,
        shopRequestStatus: profile.shopRequestStatus,
        shopRequestSubmittedAt: profile.shopRequestSubmittedAt,
        shopRequestReviewedAt: profile.shopRequestReviewedAt,
        sellerProfile: profile.sellerProfile,
      },
    });
  }

  async emitSellerMetricsProfileUpdate(userId: string) {
    const profile = await this.getCurrentUserProfile(userId);
    this.emitProfileUpdated(profile);
  }

  private async buildSellerStats(sellerProfileId: string) {
    const [followerCount, profileViewCount, totalLikesCount, productCount] = await Promise.all([
      this.prisma.sellerFollow.count({
        where: { sellerProfileId },
      }),
      this.prisma.sellerProfileView.count({
        where: { sellerProfileId },
      }),
      this.prisma.productLike.count({
        where: {
          product: {
            sellerProfileId,
          },
        },
      }),
      this.prisma.product.count({
        where: { sellerProfileId },
      }),
    ]);

    return {
      followerCount,
      profileViewCount,
      productCount,
      totalLikesCount,
    };
  }

  private async findUserProfileById(userId: string, client: PrismaService | Prisma.TransactionClient) {
    const user = await client.user.findUnique({
      where: { id: userId },
      include: {
        sellerProfile: {
          include: {
            _count: {
              select: {
                products: true,
              },
            },
            products: {
              include: {
                category: true,
                _count: {
                  select: {
                    likes: true,
                  },
                },
                productImages: {
                  orderBy: {
                    sortOrder: 'asc',
                  },
                },
              },
              orderBy: {
                createdAt: 'desc',
              },
            },
          },
        },
      },
    });

    if (!user) {
      throw new NotFoundException('User profile not found');
    }

    return user;
  }

  private buildUserUpdateData(
    existingUser: Prisma.UserGetPayload<{
      include: {
        sellerProfile: {
          include: {
            _count: {
              select: {
                products: true,
              },
            },
            products: {
              include: {
                category: true,
                _count: {
                  select: {
                    likes: true,
                  },
                },
                productImages: {
                  orderBy: {
                    sortOrder: 'asc',
                  },
                },
              },
              orderBy: {
                createdAt: 'desc',
              },
            },
          },
        },
      },
    }>,
    dto: UpdateProfileDto,
  ): Prisma.UserUpdateInput {
    const userData: Prisma.UserUpdateInput = {};

    if (dto.displayName !== undefined) {
      const normalizedDisplayName = dto.displayName.trim();

      if (normalizedDisplayName.length < 2 || normalizedDisplayName.length > 120) {
        throw new BadRequestException('Le nom utilisateur doit contenir entre 2 et 120 caracteres.');
      }

      if (normalizedDisplayName !== existingUser.displayName.trim()) {
        const now = new Date();
        const nextAllowedChangeAt = this.getNextDisplayNameChangeAt(
          existingUser.displayNameChangedAt,
        );

        if (nextAllowedChangeAt != null && nextAllowedChangeAt.getTime() > now.getTime()) {
          throw new BadRequestException(
            `Le nom utilisateur ne peut etre modifie qu'une fois tous les 3 mois. Prochaine date autorisee: ${this.formatDisplayNameCooldownDate(nextAllowedChangeAt)}.`,
          );
        }

        userData.displayName = normalizedDisplayName;
        userData.displayNameChangedAt = now;
      }
    }

    if (dto.avatarUrl !== undefined) {
      userData.avatarUrl = dto.avatarUrl;
    }

    if (dto.coverImageUrl !== undefined) {
      userData.coverImageUrl = dto.coverImageUrl;
    }

    if (dto.locationLabel !== undefined) {
      userData.locationLabel = dto.locationLabel;
    }

    if (dto.locationLatitude !== undefined) {
      userData.locationLatitude = dto.locationLatitude;
    }

    if (dto.locationLongitude !== undefined) {
      userData.locationLongitude = dto.locationLongitude;
    }

    if (
      dto.locationLabel !== undefined ||
      dto.locationLatitude !== undefined ||
      dto.locationLongitude !== undefined
    ) {
      userData.locationUpdatedAt = new Date();
    }

    if (dto.preferredLanguage !== undefined) {
      userData.preferredLanguage = dto.preferredLanguage;
    }

    if (this.buildSellerProfileUpdateData(dto.sellerProfile) && existingUser.role !== UserRole.SELLER) {
      userData.role = UserRole.SELLER;
    }

    return userData;
  }

  private buildSellerProfileUpdateData(dto?: UpdateSellerProfileDto) {
    if (!dto) {
      return null;
    }

    const sellerProfileData: {
      studioName?: string;
      description?: string;
      city?: string;
      country?: string;
    } = {};

    if (dto.studioName !== undefined) {
      sellerProfileData.studioName = dto.studioName;
    }

    if (dto.description !== undefined) {
      sellerProfileData.description = dto.description;
    }

    if (dto.city !== undefined) {
      sellerProfileData.city = dto.city;
    }

    if (dto.country !== undefined) {
      sellerProfileData.country = dto.country;
    }

    return Object.keys(sellerProfileData).length > 0 ? sellerProfileData : null;
  }

  private getNextDisplayNameChangeAt(displayNameChangedAt: Date | null) {
    if (displayNameChangedAt == null) {
      return null;
    }

    const nextAllowedChangeAt = new Date(displayNameChangedAt);
    nextAllowedChangeAt.setMonth(nextAllowedChangeAt.getMonth() + 3);
    return nextAllowedChangeAt;
  }

  private formatDisplayNameCooldownDate(date: Date) {
    const day = date.getDate().toString().padStart(2, '0');
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const year = date.getFullYear();
    return `${day}/${month}/${year}`;
  }

  private async updateCurrentUserImage(
    userId: string,
    file: Express.Multer.File | undefined,
    variant: 'avatar' | 'cover',
  ) {
    if (!file) {
      throw new BadRequestException('Profile image file is required');
    }

    const user = await this.findUserProfileById(userId, this.prisma);
    const uploadResult = await this.cloudinaryService.uploadUserImage(
      file,
      user.phoneE164,
      variant,
    );

    const data: Prisma.UserUpdateInput =
      variant === 'cover'
        ? { coverImageUrl: uploadResult.imageUrl }
        : { avatarUrl: uploadResult.imageUrl };

    await this.prisma.user.update({
      where: { id: userId },
      data,
    });

    const profile = await this.getCurrentUserProfile(userId);
    this.emitProfileUpdated(profile);

    return {
      originalUrl: uploadResult.originalUrl,
      publicId: uploadResult.publicId,
      imageUrl: uploadResult.imageUrl,
      profile,
    };
  }
}