import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma, ShopRequestStatus, UserRole } from '@prisma/client';
import { AccessToken, TrackSource } from 'livekit-server-sdk';

import { CloudinaryService } from '../auth/cloudinary.service';
import { ConversationsRealtimeGateway } from '../conversations/realtime/conversations-realtime.gateway';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';
import { PushNotificationsService } from '../push-notifications/push-notifications.service';
import { UpdateProfileDto, UpdateSellerProfileDto } from './dto/update-profile.dto';

const DISPLAY_NAME_CHANGE_COOLDOWN_DAYS = 7;
import {
  presentPublicSellerProfile,
  presentPublicUserProfile,
  presentUserProfile,
} from './profile.presenter';

@Injectable()
export class ProfilesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly cloudinaryService: CloudinaryService,
    private readonly conversationsRealtimeGateway: ConversationsRealtimeGateway,
    private readonly notificationsService: NotificationsService,
    private readonly pushNotificationsService: PushNotificationsService,
    private readonly configService: ConfigService,
  ) {}

  async getCurrentUserProfile(userId: string) {
    const user = await this.findUserProfileById(userId, this.prisma);
    const sellerStats = user.sellerProfile
      ? await this.buildSellerStats(user.sellerProfile.id)
      : undefined;
    return presentUserProfile(user, sellerStats);
  }

  private isUserOnline(userId: string, _lastSeenAt?: Date | null) {
    return this.conversationsRealtimeGateway.isUserConnected(userId);
  }

  private async findReportTargetUser(reportedUserId: string) {
    const reportedUser = await this.prisma.user.findUnique({
      where: { id: reportedUserId },
      select: {
        id: true,
        displayName: true,
        avatarUrl: true,
      },
    });

    if (!reportedUser) {
      throw new NotFoundException('User not found');
    }

    return reportedUser;
  }

  async blockUser(
    blockerUserId: string,
    blockedUserId: string,
    input: { conversationId?: string } = {},
  ) {
    const normalizedBlockedUserId = blockedUserId.trim();

    if (normalizedBlockedUserId.length === 0) {
      throw new BadRequestException('Blocked user id is required');
    }

    if (normalizedBlockedUserId === blockerUserId) {
      throw new BadRequestException('You cannot block your own account');
    }

    const blockedUser = await this.findReportTargetUser(normalizedBlockedUserId);

    const userBlock = await this.prisma.userBlock.upsert({
      where: {
        blockerUserId_blockedUserId: {
          blockerUserId,
          blockedUserId: normalizedBlockedUserId,
        },
      },
      update: {
        updatedAt: new Date(),
      },
      create: {
        blockerUserId,
        blockedUserId: normalizedBlockedUserId,
      },
    });

    const conversationId = input.conversationId?.trim() ?? '';
    if (conversationId.length > 0) {
      this.conversationsRealtimeGateway.emitConversationEvent(
        [blockerUserId, normalizedBlockedUserId],
        {
          type: 'conversation:blocked',
          conversationId,
          actorUserId: blockerUserId,
        },
      );
    }

    return {
      id: userBlock.id,
      blockedUserId: blockedUser.id,
      blockedUserDisplayName: blockedUser.displayName,
      blockedUserAvatarUrl: blockedUser.avatarUrl,
      createdAt: userBlock.createdAt.toISOString(),
      updatedAt: userBlock.updatedAt.toISOString(),
    };
  }

  async unblockUser(blockerUserId: string, blockedUserId: string) {
    const normalizedBlockedUserId = blockedUserId.trim();

    if (normalizedBlockedUserId.length === 0) {
      throw new BadRequestException('Blocked user id is required');
    }

    if (normalizedBlockedUserId === blockerUserId) {
      throw new BadRequestException('You cannot unblock your own account');
    }

    await this.prisma.userBlock.deleteMany({
      where: {
        blockerUserId,
        blockedUserId: normalizedBlockedUserId,
      },
    });

    return {
      blockerUserId,
      blockedUserId: normalizedBlockedUserId,
      unblocked: true,
    };
  }

  async listBlockedUsers(blockerUserId: string) {
    const blocks = await this.prisma.userBlock.findMany({
      where: {
        blockerUserId,
      },
      orderBy: {
        updatedAt: 'desc',
      },
      include: {
        blocked: {
          select: {
            id: true,
            displayName: true,
            avatarUrl: true,
          },
        },
      },
    });

    return blocks.map((block) => ({
      id: block.id,
      blockedAt: block.createdAt.toISOString(),
      updatedAt: block.updatedAt.toISOString(),
      blocked: {
        id: block.blocked.id,
        displayName: block.blocked.displayName,
        avatarUrl: block.blocked.avatarUrl,
      },
    }));
  }

  async reportUser(
    reporterUserId: string,
    reportedUserId: string,
    input: {
      conversationId?: string;
      reason?: string;
      details?: string;
      blockUser?: boolean;
    },
  ) {
    const normalizedReportedUserId = reportedUserId.trim();

    if (normalizedReportedUserId.length === 0) {
      throw new BadRequestException('Reported user id is required');
    }

    if (normalizedReportedUserId === reporterUserId) {
      throw new BadRequestException('You cannot report your own account');
    }

    const reportedUser = await this.findReportTargetUser(normalizedReportedUserId);
    const shouldBlockUser = input.blockUser === true;

    const report = await this.prisma.userReport.create({
      data: {
        reporterUserId,
        reportedUserId: normalizedReportedUserId,
        conversationId: input.conversationId?.trim() || null,
        reason: input.reason?.trim() || 'CHAT_REPORT',
        details: input.details?.trim() || null,
        blockRequested: shouldBlockUser,
      },
    });

    if (shouldBlockUser) {
      await this.blockUser(reporterUserId, normalizedReportedUserId, {
        conversationId: report.conversationId ?? undefined,
      });
    }

    return {
      id: report.id,
      reportedUserId: reportedUser.id,
      reportedUserDisplayName: reportedUser.displayName,
      reportedUserAvatarUrl: reportedUser.avatarUrl,
      blockRequested: report.blockRequested,
      createdAt: report.createdAt.toISOString(),
    };
  }

  async listReportsByReporter(reporterUserId: string) {
    const reports = await this.prisma.userReport.findMany({
      where: {
        reporterUserId,
      },
      orderBy: {
        createdAt: 'desc',
      },
      include: {
        reporter: {
          select: {
            id: true,
            displayName: true,
            avatarUrl: true,
          },
        },
        reported: {
          select: {
            id: true,
            displayName: true,
            avatarUrl: true,
          },
        },
      },
    });

    return reports.map((report) => ({
      id: report.id,
      conversationId: report.conversationId,
      reason: report.reason,
      details: report.details,
      blockRequested: report.blockRequested,
      createdAt: report.createdAt.toISOString(),
      reporter: {
        id: report.reporter.id,
        displayName: report.reporter.displayName,
        avatarUrl: report.reporter.avatarUrl,
      },
      reported: {
        id: report.reported.id,
        displayName: report.reported.displayName,
        avatarUrl: report.reported.avatarUrl,
      },
    }));
  }

  async listAllReports() {
    const reports = await this.prisma.userReport.findMany({
      orderBy: {
        createdAt: 'desc',
      },
      include: {
        reporter: {
          select: {
            id: true,
            displayName: true,
            avatarUrl: true,
          },
        },
        reported: {
          select: {
            id: true,
            displayName: true,
            avatarUrl: true,
          },
        },
      },
    });

    return reports.map((report) => ({
      id: report.id,
      conversationId: report.conversationId,
      reason: report.reason,
      details: report.details,
      blockRequested: report.blockRequested,
      createdAt: report.createdAt.toISOString(),
      reporter: {
        id: report.reporter.id,
        displayName: report.reporter.displayName,
        avatarUrl: report.reporter.avatarUrl,
      },
      reported: {
        id: report.reported.id,
        displayName: report.reported.displayName,
        avatarUrl: report.reported.avatarUrl,
      },
    }));
  }

  async listAllUsers(query: {
    search?: string;
    role?: UserRole;
    page?: number;
    limit?: number;
  }) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 25;

    const where: Prisma.UserWhereInput = {};
    if (query.role) {
      where.role = query.role;
    }
    if (query.search) {
      where.OR = [
        { displayName: { contains: query.search, mode: 'insensitive' } },
        { phoneE164: { contains: query.search, mode: 'insensitive' } },
      ];
    }

    const [users, total] = await Promise.all([
      this.prisma.user.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
        select: {
          id: true,
          displayName: true,
          phoneE164: true,
          countryDialCode: true,
          avatarUrl: true,
          role: true,
          isVerified: true,
          isSellerCertified: true,
          shopRequestStatus: true,
          sellerVerificationRequestStatus: true,
          lastSeenAt: true,
          createdAt: true,
        },
      }),
      this.prisma.user.count({ where }),
    ]);

    return {
      items: users,
      page,
      limit,
      total,
      totalPages: Math.max(1, Math.ceil(total / limit)),
    };
  }

  async startCurrentUserLive(
    userId: string,
    params: { title: string; category: string },
  ) {
    const sellerProfile = await this.prisma.sellerProfile.findUnique({
      where: { userId },
      include: {
        followers: {
          select: {
            followerUserId: true,
          },
        },
      },
    });

    if (!sellerProfile) {
      throw new NotFoundException('Seller profile not found');
    }

    const title = params.title.trim();
    const category = params.category.trim();

    if (title.length === 0) {
      throw new BadRequestException('Live title is required');
    }

    const liveSession = await this.prisma.sellerLiveSession.upsert({
      where: { sellerProfileId: sellerProfile.id },
      create: {
        sellerProfileId: sellerProfile.id,
        title,
        category: category.length > 0 ? category : 'Live boutique',
        endedAt: null,
      },
      update: {
        title,
        category: category.length > 0 ? category : 'Live boutique',
        startedAt: new Date(),
        endedAt: null,
      },
    });

    this.conversationsRealtimeGateway.emitLiveEvent(
      [
        userId,
        ...sellerProfile.followers.map((follower) => follower.followerUserId),
      ],
      {
        type: 'live:updated',
        sellerProfileId: sellerProfile.id,
        isLive: true,
        title: liveSession.title,
        category: liveSession.category,
        startedAt: liveSession.startedAt.toISOString(),
      },
    );

    return {
      sellerProfileId: sellerProfile.id,
      roomName: this.buildLiveRoomName(sellerProfile.id),
      url: this.requireLivekitUrl(),
      token: await this.buildLivekitToken({
        roomName: this.buildLiveRoomName(sellerProfile.id),
        identity: `seller-${userId}`,
        name: sellerProfile.studioName,
        canPublish: true,
        canSubscribe: true,
      }),
      title: liveSession.title,
      category: liveSession.category,
      startedAt: liveSession.startedAt.toISOString(),
      isLive: true,
    };
  }

  async stopCurrentUserLive(userId: string) {
    const sellerProfile = await this.prisma.sellerProfile.findUnique({
      where: { userId },
      include: {
        followers: {
          select: {
            followerUserId: true,
          },
        },
      },
    });

    if (!sellerProfile) {
      throw new NotFoundException('Seller profile not found');
    }

    await this.prisma.sellerLiveSession.updateMany({
      where: {
        sellerProfileId: sellerProfile.id,
        endedAt: null,
      },
      data: {
        endedAt: new Date(),
      },
    });

    this.conversationsRealtimeGateway.emitLiveEvent(
      [
        userId,
        ...sellerProfile.followers.map((follower) => follower.followerUserId),
      ],
      {
        type: 'live:updated',
        sellerProfileId: sellerProfile.id,
        isLive: false,
        title: null,
        category: null,
        startedAt: null,
      },
    );

    return {
      sellerProfileId: sellerProfile.id,
      isLive: false,
    };
  }

  async getSellerLiveJoinInfo(currentUserId: string, sellerProfileId: string) {
    const sellerProfile = await this.prisma.sellerProfile.findUnique({
      where: { id: sellerProfileId },
      include: {
        user: true,
        liveSession: true,
      },
    });

    if (!sellerProfile) {
      throw new NotFoundException('Seller profile not found');
    }

    const liveSession = sellerProfile.liveSession;
    if (!liveSession || liveSession.endedAt != null) {
      throw new NotFoundException('Live session not found');
    }

    return {
      sellerProfileId: sellerProfile.id,
      roomName: this.buildLiveRoomName(sellerProfile.id),
      url: this.requireLivekitUrl(),
      token: await this.buildLivekitToken({
        roomName: this.buildLiveRoomName(sellerProfile.id),
        identity: `viewer-${currentUserId}-${Date.now()}`,
        name: `viewer-${currentUserId}`,
        canPublish: false,
        canSubscribe: true,
      }),
      title: liveSession.title,
      category: liveSession.category,
      sellerName:
          sellerProfile.studioName.trim().length > 0
            ? sellerProfile.studioName
            : sellerProfile.user.displayName,
      sellerAvatarUrl: sellerProfile.user.avatarUrl,
      startedAt: liveSession.startedAt.toISOString(),
      isLive: true,
    };
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
    return presentPublicSellerProfile(sellerProfile, sellerStats, false, false);
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
      sellerProfile.userId === viewerUserId,
    );
  }

  async getPublicUserProfile(userId: string) {
    const user = await this.findUserProfileById(userId, this.prisma);
    const sellerStats = user.sellerProfile
      ? await this.buildSellerStats(user.sellerProfile.id)
      : undefined;
    return presentPublicUserProfile(user, sellerStats);
  }

  async getUsersPresence(rawUserIds: string | undefined) {
    if (rawUserIds == null || rawUserIds.trim().length === 0) {
      return [];
    }

    const userIds = [...new Set(
      rawUserIds
        .split(',')
        .map((value) => value.trim())
        .filter((value) => value.length > 0),
    )];

    const users = await this.prisma.user.findMany({
      where: { id: { in: userIds } },
      select: {
        id: true,
        lastSeenAt: true,
      },
    });
    const lastSeenByUserId = new Map(
      users.map((user) => [user.id, user.lastSeenAt?.toISOString() ?? null]),
    );

    return userIds.map((userId) => {
      const userLastSeenAt = users.find((user) => user.id === userId)?.lastSeenAt ?? null;

      return {
        userId,
        isOnline: this.isUserOnline(userId, userLastSeenAt),
        lastSeenAt: lastSeenByUserId.get(userId) ?? null,
      };
    });
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

    const existingFollow = await this.prisma.sellerFollow.findUnique({
      where: {
        followerUserId_sellerProfileId: {
          followerUserId: viewerUserId,
          sellerProfileId,
        },
      },
    });

    if (!existingFollow) {
      const follower = await this.prisma.user.findUnique({
        where: {
          id: viewerUserId,
        },
        select: {
          id: true,
          displayName: true,
          avatarUrl: true,
        },
      });

      await this.prisma.sellerFollow.create({
        data: {
          followerUserId: viewerUserId,
          sellerProfileId,
        },
      });

      if (follower) {
        await this.emitNotificationUpdatedEvent(
          sellerProfile.userId,
          'seller_follow',
        );
        await this.pushNotificationsService.sendSellerFollowNotification({
          recipientUserId: sellerProfile.userId,
          followerUserId: follower.id,
          followerDisplayName: follower.displayName,
          followerAvatarUrl: follower.avatarUrl ?? undefined,
          sellerProfileId,
        });
      }
    }

    await this.emitSellerMetricsProfileUpdate(sellerProfile.userId);
    return this.getPublicSellerProfileForViewer(sellerProfileId, viewerUserId);
  }

  private async emitNotificationUpdatedEvent(
    userId: string,
    reason:
      | 'product_like'
      | 'product_comment'
      | 'followed_seller_activity'
      | 'seller_follow'
      | 'shop_request_approved',
  ) {
    const unreadCount = await this.notificationsService.countUnread(userId);
    this.conversationsRealtimeGateway.emitNotificationEvent(userId, {
      type: 'notifications:updated',
      userId,
      reason,
      unreadCount,
    });
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

  async getSellerFollowers(currentUserId: string, sellerProfileId: string) {
    const followerLinks = await this.prisma.sellerFollow.findMany({
      where: { sellerProfileId },
      include: {
        follower: {
          include: {
            sellerProfile: true,
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    return followerLinks.map((link) => ({
      id: link.follower.id,
      userId: link.follower.id,
      sellerProfileId: link.follower.sellerProfile?.id ?? null,
      role: link.follower.role,
      displayName: link.follower.displayName,
      avatarUrl: link.follower.avatarUrl,
      subtitle: this.buildMetricUserSubtitle({
        locationLabel: link.follower.locationLabel,
        sellerProfileDescription: link.follower.sellerProfile?.description,
        fallback: 'Abonne a votre boutique',
      }),
      trailingText: 'Abonne',
    }));
  }

  async getCurrentUserFollowing(currentUserId: string) {
    const followingLinks = await this.prisma.sellerFollow.findMany({
      where: {
        followerUserId: currentUserId,
      },
      include: {
        sellerProfile: {
          include: {
            user: true,
            liveSession: true,
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    return followingLinks.map((link) => {
      const liveSession = link.sellerProfile.liveSession;
      const isLive = liveSession != null && liveSession.endedAt == null;

      return {
        id: link.sellerProfile.user.id,
        userId: link.sellerProfile.user.id,
        sellerProfileId: link.sellerProfile.id,
        role: link.sellerProfile.user.role,
        displayName:
          link.sellerProfile.studioName?.trim() !== ''
            ? link.sellerProfile.studioName
            : link.sellerProfile.user.displayName,
        avatarUrl: link.sellerProfile.user.avatarUrl,
        subtitle: this.buildMetricUserSubtitle({
          locationLabel: link.sellerProfile.user.locationLabel,
          sellerProfileDescription: link.sellerProfile.description,
          fallback: 'Boutique suivie',
        }),
        trailingText: 'Boutique',
        followedAt: link.createdAt,
        isLive,
        liveTitle: isLive ? liveSession.title : null,
        liveCategory: isLive ? liveSession.category : null,
        liveStartedAt: isLive ? liveSession.startedAt.toISOString() : null,
      };
    });
  }

  async getSellerProfileViews(currentUserId: string, sellerProfileId: string) {
    const rawViews = await this.prisma.sellerProfileView.findMany({
      where: {
        sellerProfileId,
        viewerUserId: {
          not: null,
        },
      },
      include: {
        viewer: {
          include: {
            sellerProfile: true,
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    const uniqueViews = new Map<string, (typeof rawViews)[number]>();
    for (const view of rawViews) {
      if (view.viewer == null) {
        continue;
      }
      if (!uniqueViews.has(view.viewer.id)) {
        uniqueViews.set(view.viewer.id, view);
      }
    }

    return Array.from(uniqueViews.values()).map((view) => ({
      id: view.viewer!.id,
      userId: view.viewer!.id,
      sellerProfileId: view.viewer!.sellerProfile?.id ?? null,
      role: view.viewer!.role,
      displayName: view.viewer!.displayName,
      avatarUrl: view.viewer!.avatarUrl,
      subtitle: this.buildMetricUserSubtitle({
        locationLabel: view.viewer!.locationLabel,
        sellerProfileDescription: view.viewer!.sellerProfile?.description,
        fallback: 'A visite votre profil recemment',
      }),
      trailingText: 'Vu',
    }));
  }

  async getSellerLikeUsers(currentUserId: string, sellerProfileId: string) {
    const likes = await this.prisma.productLike.findMany({
      where: {
        product: {
          sellerProfileId,
        },
      },
      include: {
        user: {
          include: {
            sellerProfile: true,
          },
        },
        product: {
          select: {
            title: true,
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    const likesByUser = new Map<
      string,
      {
        userId: string;
        sellerProfileId: string | null;
        displayName: string;
        avatarUrl: string | null;
        locationLabel: string | null;
        sellerProfileDescription: string | null;
        latestProductTitle: string;
        count: number;
      }
    >();

    for (const like of likes) {
      const existingEntry = likesByUser.get(like.user.id);
      if (existingEntry == null) {
        likesByUser.set(like.user.id, {
          userId: like.user.id,
          sellerProfileId: like.user.sellerProfile?.id ?? null,
          displayName: like.user.displayName,
          avatarUrl: like.user.avatarUrl,
          locationLabel: like.user.locationLabel,
          sellerProfileDescription: like.user.sellerProfile?.description ?? null,
          latestProductTitle: like.product.title,
          count: 1,
        });
        continue;
      }

      existingEntry.count += 1;
    }

    return Array.from(likesByUser.values()).map((entry) => ({
      id: entry.userId,
      userId: entry.userId,
      sellerProfileId: entry.sellerProfileId,
      role: entry.sellerProfileId != null ? UserRole.SELLER : UserRole.CUSTOMER,
      displayName: entry.displayName,
      avatarUrl: entry.avatarUrl,
      count: entry.count,
      subtitle: entry.count > 1
          ? 'A laisse ${entry.count} likes sur vos produits'
          : 'A laisse 1 like sur votre produit',
      trailingText: entry.count > 1 ? '${entry.count} likes' : '1 like',
    }));
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

  async submitSellerVerificationRequest(userId: string) {
    const user = await this.findUserProfileById(userId, this.prisma);

    if (user.role !== UserRole.SELLER) {
      throw new BadRequestException('La certification est reservee aux boutiques.');
    }

    if (user.isSellerCertified) {
      const profile = await this.getCurrentUserProfile(userId);
      this.emitProfileUpdated(profile);
      return profile;
    }

    if (user.sellerVerificationRequestStatus === ShopRequestStatus.PENDING) {
      const profile = await this.getCurrentUserProfile(userId);
      this.emitProfileUpdated(profile);
      return profile;
    }

    await this.prisma.user.update({
      where: { id: userId },
      data: {
        sellerVerificationRequestStatus: ShopRequestStatus.PENDING,
        sellerVerificationRequestedAt: new Date(),
        sellerVerificationReviewedAt: null,
      },
    });

    const profile = await this.getCurrentUserProfile(userId);
    this.emitProfileUpdated(profile);
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

  async listPendingSellerVerificationRequests() {
    const users = await this.prisma.user.findMany({
      where: {
        role: UserRole.SELLER,
        sellerVerificationRequestStatus: ShopRequestStatus.PENDING,
      },
      orderBy: {
        sellerVerificationRequestedAt: 'asc',
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
      isSellerCertified: user.isSellerCertified,
      sellerVerificationRequestStatus: user.sellerVerificationRequestStatus,
      sellerVerificationRequestedAt:
        user.sellerVerificationRequestedAt?.toISOString() ?? null,
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
    await this.emitNotificationUpdatedEvent(userId, 'shop_request_approved');
    const sellerStudioName = profile.sellerProfile?.studioName?.trim() ?? '';
    await this.pushNotificationsService.sendShopRequestApprovedNotification({
      recipientUserId: userId,
      sellerProfileId: profile.sellerProfile?.id,
      sellerDisplayName: sellerStudioName.length > 0
        ? sellerStudioName
        : profile.displayName,
      sellerAvatarUrl: profile.avatarUrl ?? undefined,
    });
    return profile;
  }

  async approveSellerVerificationRequest(userId: string) {
    const user = await this.findUserProfileById(userId, this.prisma);

    if (user.role !== UserRole.SELLER) {
      throw new BadRequestException('Ce compte n\'est pas une boutique.');
    }

    if (user.sellerVerificationRequestStatus !== ShopRequestStatus.PENDING) {
      throw new BadRequestException(
        'No pending seller verification request found for this user.',
      );
    }

    await this.prisma.user.update({
      where: { id: userId },
      data: {
        isSellerCertified: true,
        sellerVerificationRequestStatus: ShopRequestStatus.APPROVED,
        sellerVerificationReviewedAt: new Date(),
      },
    });

    const profile = await this.getCurrentUserProfile(userId);
    this.emitProfileUpdated(profile);
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

  async resetSellerVerificationRequestToPending(userId: string) {
    const user = await this.findUserProfileById(userId, this.prisma);

    if (user.role !== UserRole.SELLER) {
      throw new BadRequestException('Ce compte n\'est pas une boutique.');
    }

    if (user.sellerVerificationRequestStatus === ShopRequestStatus.PENDING) {
      const profile = await this.getCurrentUserProfile(userId);
      this.emitProfileUpdated(profile);
      return profile;
    }

    await this.prisma.user.update({
      where: { id: userId },
      data: {
        isSellerCertified: false,
        sellerVerificationRequestStatus: ShopRequestStatus.PENDING,
        sellerVerificationRequestedAt: user.sellerVerificationRequestedAt ?? new Date(),
        sellerVerificationReviewedAt: null,
      },
    });

    const profile = await this.getCurrentUserProfile(userId);
    this.emitProfileUpdated(profile);
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
        sellerVerificationRequestStatus: profile.sellerVerificationRequestStatus,
        sellerVerificationRequestedAt: profile.sellerVerificationRequestedAt,
        sellerVerificationReviewedAt: profile.sellerVerificationReviewedAt,
        isSellerCertified: profile.isSellerCertified,
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
        sellerVerificationRequestStatus: profile.sellerVerificationRequestStatus,
        sellerVerificationRequestedAt: profile.sellerVerificationRequestedAt,
        sellerVerificationReviewedAt: profile.sellerVerificationReviewedAt,
        isSellerCertified: profile.isSellerCertified,
        sellerProfile: profile.sellerProfile,
      },
    });

    this.conversationsRealtimeGateway.emitPublicProfileEvent({
      type: 'profile:public-updated',
      userId: profile.id,
      profile: {
        id: profile.id,
        role: profile.role,
        displayName: profile.displayName,
        avatarUrl: profile.avatarUrl,
        coverImageUrl: profile.coverImageUrl,
        isSellerCertified: profile.isSellerCertified,
        sellerProfile: profile.sellerProfile,
      },
    });
  }

  async emitSellerMetricsProfileUpdate(userId: string) {
    const profile = await this.getCurrentUserProfile(userId);
    this.emitProfileUpdated(profile);
  }

  private async assertSellerOwnership(currentUserId: string, sellerProfileId: string) {
    const sellerProfile = await this.prisma.sellerProfile.findUnique({
      where: { id: sellerProfileId },
      select: {
        id: true,
        userId: true,
      },
    });

    if (!sellerProfile) {
      throw new NotFoundException('Seller profile not found');
    }

    if (sellerProfile.userId !== currentUserId) {
      throw new ForbiddenException('Access denied to this seller metrics list');
    }

    return sellerProfile;
  }

  private buildLiveRoomName(sellerProfileId: string) {
    return `seller-live-${sellerProfileId}`;
  }

  private requireLivekitUrl() {
    const livekitUrl = this.configService.get<string>('LIVEKIT_URL')?.trim() ?? '';
    if (livekitUrl.length === 0) {
      throw new BadRequestException('LIVEKIT_URL is not configured');
    }

    return livekitUrl;
  }

  private async buildLivekitToken(params: {
    roomName: string;
    identity: string;
    name: string;
    canPublish: boolean;
    canSubscribe: boolean;
  }) {
    const apiKey = this.configService.get<string>('LIVEKIT_API_KEY')?.trim() ?? '';
    const apiSecret = this.configService.get<string>('LIVEKIT_API_SECRET')?.trim() ?? '';

    if (apiKey.length === 0 || apiSecret.length === 0) {
      throw new BadRequestException('LiveKit credentials are not configured');
    }

    const token = new AccessToken(apiKey, apiSecret, {
      identity: params.identity,
      name: params.name,
      ttl: '2h',
    });

    token.addGrant({
      roomJoin: true,
      room: params.roomName,
      canPublish: params.canPublish,
      canSubscribe: params.canSubscribe,
      canPublishData: params.canPublish,
      canPublishSources: params.canPublish
        ? [TrackSource.CAMERA, TrackSource.MICROPHONE]
        : undefined,
    });

    return token.toJwt();
  }

  private buildMetricUserSubtitle(params: {
    locationLabel?: string | null;
    sellerProfileDescription?: string | null;
    fallback: string;
  }) {
    const locationLabel = params.locationLabel?.trim() ?? '';
    if (locationLabel !== '') {
      return locationLabel;
    }

    const sellerProfileDescription = params.sellerProfileDescription?.trim() ?? '';
    if (sellerProfileDescription !== '') {
      return sellerProfileDescription;
    }

    return params.fallback;
  }

  private async buildSellerStats(sellerProfileId: string) {
    const [followerCount, uniqueProfileViews, totalLikesCount, productCount] = await Promise.all([
      this.prisma.sellerFollow.count({
        where: { sellerProfileId },
      }),
      this.prisma.sellerProfileView.groupBy({
        by: ['viewerUserId'],
        where: {
          sellerProfileId,
          viewerUserId: {
            not: null,
          },
        },
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
      profileViewCount: uniqueProfileViews.length,
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
    const now = new Date();
    const nextAllowedChangeAt = this.getNextDisplayNameChangeAt(
      existingUser.displayNameChangedAt,
    );
    let visibleNameChanged = false;

    if (dto.displayName !== undefined) {
      const normalizedDisplayName = dto.displayName.trim();

      if (normalizedDisplayName.length < 2 || normalizedDisplayName.length > 120) {
        throw new BadRequestException('Le nom utilisateur doit contenir entre 2 et 120 caracteres.');
      }

      if (normalizedDisplayName !== existingUser.displayName.trim()) {
        if (nextAllowedChangeAt != null && nextAllowedChangeAt.getTime() > now.getTime()) {
          throw new BadRequestException(
            this.buildDisplayNameCooldownMessage(nextAllowedChangeAt, now),
          );
        }

        userData.displayName = normalizedDisplayName;
        visibleNameChanged = true;
      }
    }

    const requestedStudioName = dto.sellerProfile?.studioName?.trim();
    const currentVisibleStudioName =
      existingUser.sellerProfile?.studioName?.trim() ?? existingUser.displayName.trim();

    if (
      requestedStudioName !== undefined &&
      requestedStudioName !== currentVisibleStudioName
    ) {
      if (nextAllowedChangeAt != null && nextAllowedChangeAt.getTime() > now.getTime()) {
        throw new BadRequestException(
          this.buildDisplayNameCooldownMessage(nextAllowedChangeAt, now),
        );
      }

      visibleNameChanged = true;
    }

    if (visibleNameChanged) {
      userData.displayNameChangedAt = now;
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
    nextAllowedChangeAt.setDate(nextAllowedChangeAt.getDate() + DISPLAY_NAME_CHANGE_COOLDOWN_DAYS);
    return nextAllowedChangeAt;
  }

  private getDisplayNameCooldownDaysRemaining(nextAllowedChangeAt: Date, now: Date) {
    return Math.max(
      1,
      Math.ceil(
        (nextAllowedChangeAt.getTime() - now.getTime()) / (1000 * 60 * 60 * 24),
      ),
    );
  }

  private buildDisplayNameCooldownMessage(nextAllowedChangeAt: Date, now: Date) {
    const remainingDays = this.getDisplayNameCooldownDaysRemaining(nextAllowedChangeAt, now);
    const dayLabel = remainingDays > 1 ? 'jours' : 'jour';

    return `Le nom utilisateur ne peut etre modifie qu'une fois tous les 7 jours. ${remainingDays} ${dayLabel} restant(s). Prochaine date autorisee: ${this.formatDisplayNameCooldownDate(nextAllowedChangeAt)}.`;
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