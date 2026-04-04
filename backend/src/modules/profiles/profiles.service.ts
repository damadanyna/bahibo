import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, ShopRequestStatus, UserRole } from '@prisma/client';

import { CloudinaryService } from '../auth/cloudinary.service';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateProfileDto, UpdateSellerProfileDto } from './dto/update-profile.dto';
import { presentPublicSellerProfile, presentUserProfile } from './profile.presenter';

@Injectable()
export class ProfilesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly cloudinaryService: CloudinaryService,
  ) {}

  async getCurrentUserProfile(userId: string) {
    const user = await this.findUserProfileById(userId, this.prisma);
    return presentUserProfile(user);
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

    return this.getCurrentUserProfile(userId);
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
      },
    });

    if (!sellerProfile) {
      throw new NotFoundException('Seller profile not found');
    }

    return presentPublicSellerProfile(sellerProfile);
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
      return presentUserProfile(user);
    }

    await this.prisma.user.update({
      where: { id: userId },
      data: {
        shopRequestStatus: ShopRequestStatus.PENDING,
        shopRequestSubmittedAt: new Date(),
        shopRequestReviewedAt: null,
      },
    });

    return this.getCurrentUserProfile(userId);
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

    return this.getCurrentUserProfile(userId);
  }

  private async findUserProfileById(userId: string, client: PrismaService | Prisma.TransactionClient) {
    const user = await client.user.findUnique({
      where: { id: userId },
      include: {
        sellerProfile: true,
      },
    });

    if (!user) {
      throw new NotFoundException('User profile not found');
    }

    return user;
  }

  private buildUserUpdateData(
    existingUser: Prisma.UserGetPayload<{ include: { sellerProfile: true } }>,
    dto: UpdateProfileDto,
  ): Prisma.UserUpdateInput {
    const userData: Prisma.UserUpdateInput = {};

    if (dto.displayName !== undefined) {
      userData.displayName = dto.displayName;
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

    return {
      originalUrl: uploadResult.originalUrl,
      publicId: uploadResult.publicId,
      imageUrl: uploadResult.imageUrl,
      profile: await this.getCurrentUserProfile(userId),
    };
  }
}