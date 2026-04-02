import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, PrismaClient, UserRole } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { UpdateProfileDto, UpdateSellerProfileDto } from './dto/update-profile.dto';
import { presentPublicSellerProfile, presentUserProfile } from './profile.presenter';

@Injectable()
export class ProfilesService {
  constructor(private readonly prisma: PrismaService) {}

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
}