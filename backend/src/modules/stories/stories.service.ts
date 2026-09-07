import {
  BadRequestException,
  Injectable,
  ForbiddenException,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import type { StoryMediaType } from '@prisma/client';

import { CloudinaryService } from '../auth/cloudinary.service';
import { ConversationsRealtimeGateway } from '../conversations/realtime/conversations-realtime.gateway';
import { PrismaService } from '../prisma/prisma.service';
import { PushNotificationsService } from '../push-notifications/push-notifications.service';
import { CreateStoryDto } from './dto/create-story.dto';

/** A story is visible for 24 h after publication. */
const STORY_LIFETIME_MS = 24 * 60 * 60 * 1000;
/** Expired rows are kept one more day (viewer counters, debugging) then purged. */
const STORY_PURGE_GRACE_MS = 24 * 60 * 60 * 1000;
const MAX_ACTIVE_STORIES_PER_USER = 30;
const MAX_VIEWERS_RETURNED = 200;
/** Same cap as the mobile picker's `maxDuration`. */
export const STORY_VIDEO_MAX_SECONDS = 60;
const STORY_VIDEO_DURATION_TOLERANCE_SECONDS = 2;

const IMAGE_EXTENSIONS = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'heic', 'heif', 'bmp'];
const VIDEO_EXTENSIONS = ['mp4', 'mov', 'm4v', '3gp', 'webm', 'mkv'];

type StoryRow = {
  id: string;
  userId: string;
  mediaType: StoryMediaType;
  mediaUrl: string;
  mediaPublicId: string | null;
  thumbnailUrl: string | null;
  durationSeconds: number | null;
  caption: string | null;
  createdAt: Date;
  expiresAt: Date;
};

type StoryAuthor = {
  id: string;
  displayName: string;
  avatarUrl: string | null;
  sellerProfile: { id: string; studioName: string } | null;
};

export type PresentedStory = {
  id: string;
  authorUserId: string;
  mediaType: StoryMediaType;
  mediaUrl: string;
  thumbnailUrl: string | null;
  durationSeconds: number | null;
  caption: string | null;
  createdAt: string;
  expiresAt: string;
  isViewed: boolean;
  isOwner: boolean;
  /** Only filled for the owner; null for viewers. */
  viewCount: number | null;
};

export type PresentedStoryGroup = {
  authorUserId: string;
  /** Null for customers; lets the client open the shop page / match notifications. */
  authorSellerProfileId: string | null;
  authorName: string;
  authorAvatarUrl: string;
  isOwner: boolean;
  hasUnviewed: boolean;
  latestStoryAt: string;
  stories: PresentedStory[];
};

const storyAuthorSelect = {
  id: true,
  displayName: true,
  avatarUrl: true,
  sellerProfile: { select: { id: true, studioName: true } },
} as const;

@Injectable()
export class StoriesService {
  private readonly logger = new Logger(StoriesService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly cloudinaryService: CloudinaryService,
    private readonly conversationsRealtimeGateway: ConversationsRealtimeGateway,
    private readonly pushNotificationsService: PushNotificationsService,
  ) {}

  async createStory(
    userId: string,
    file: Express.Multer.File | undefined,
    dto: CreateStoryDto,
  ): Promise<PresentedStory> {
    if (!file) {
      throw new BadRequestException('Story media is required');
    }
    const mediaType = this.resolveMediaType(file, dto.mediaType);
    if (!mediaType) {
      throw new BadRequestException(
        'Only images and videos are supported for stories',
      );
    }

    const author = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { ...storyAuthorSelect, deletedAt: true },
    });
    if (!author || author.deletedAt) {
      throw new NotFoundException('User not found');
    }

    const now = new Date();
    const activeCount = await this.prisma.userStory.count({
      where: { userId, expiresAt: { gt: now } },
    });
    if (activeCount >= MAX_ACTIVE_STORIES_PER_USER) {
      throw new BadRequestException(
        'Story limit reached, try again once older stories expire',
      );
    }

    let mediaUrl: string;
    let mediaPublicId: string | null;
    let thumbnailUrl: string | null;
    let durationSeconds: number | null = null;

    if (mediaType === 'VIDEO') {
      const upload = await this.cloudinaryService.uploadStoryVideo(file, userId);
      const resolvedDuration = upload.durationSeconds ?? dto.durationSeconds ?? null;
      if (
        resolvedDuration != null &&
        resolvedDuration >
          STORY_VIDEO_MAX_SECONDS + STORY_VIDEO_DURATION_TOLERANCE_SECONDS
      ) {
        await this.deleteAssetQuietly({
          id: 'pending',
          mediaType: 'VIDEO',
          mediaUrl: upload.videoUrl,
          mediaPublicId: upload.publicId,
        });
        throw new BadRequestException(
          `Story videos are limited to ${STORY_VIDEO_MAX_SECONDS} seconds`,
        );
      }
      mediaUrl = upload.videoUrl;
      mediaPublicId = upload.publicId;
      thumbnailUrl = upload.thumbnailUrl;
      durationSeconds = resolvedDuration;
    } else {
      const upload = await this.cloudinaryService.uploadStoryImage(file, userId);
      mediaUrl = upload.imageUrl;
      mediaPublicId = upload.publicId;
      thumbnailUrl = upload.imageUrl;
    }

    const story = await this.prisma.userStory.create({
      data: {
        userId,
        mediaType,
        mediaUrl,
        mediaPublicId,
        thumbnailUrl,
        durationSeconds,
        caption: dto.caption?.trim() || null,
        expiresAt: new Date(now.getTime() + STORY_LIFETIME_MS),
      },
    });

    const audienceUserIds = await this.resolveAudienceUserIds(userId);
    this.conversationsRealtimeGateway.emitStoriesEvent(
      [userId, ...audienceUserIds],
      {
        type: 'stories:updated',
        action: 'created',
        authorUserId: userId,
        storyId: story.id,
      },
    );

    // Push stays follower-based (only shops have followers); a customer's
    // story reaches their contacts through the row, without a push. The
    // story is already saved: a push failure must not turn into a 500.
    if (author.sellerProfile) {
      try {
        await this.pushNotificationsService.sendStoryPublishedNotification({
          sellerProfileId: author.sellerProfile.id,
          sellerUserId: userId,
          sellerDisplayName: this.resolveAuthorName(author),
          sellerAvatarUrl: author.avatarUrl ?? undefined,
          storyId: story.id,
          storyImageUrl: thumbnailUrl ?? mediaUrl,
        });
      } catch (error) {
        this.logger.warn(
          `Story push failed for user ${userId}: ${
            error instanceof Error ? error.message : String(error)
          }`,
        );
      }
    }

    return this.presentStory(story, {
      isOwner: true,
      isViewed: true,
      viewCount: 0,
    });
  }

  /**
   * Active stories grouped per author: the caller's own group first, then
   * authors with something not yet seen (newest first), then fully seen
   * ones. "Contacts" = shops the caller follows, the caller's followers
   * (shops only), and anyone they share a conversation with; blocks in
   * either direction hide the author.
   */
  async getFeed(userId: string): Promise<PresentedStoryGroup[]> {
    const stories = await this.prisma.userStory.findMany({
      where: {
        expiresAt: { gt: new Date() },
        OR: [
          { userId },
          {
            user: {
              sellerProfile: {
                followers: { some: { followerUserId: userId } },
              },
            },
          },
          {
            user: {
              sellerFollows: { some: { sellerProfile: { userId } } },
            },
          },
          { user: { boughtConversations: { some: { sellerUserId: userId } } } },
          { user: { soldConversations: { some: { buyerUserId: userId } } } },
        ],
        user: {
          deletedAt: null,
          blocksSent: { none: { blockedUserId: userId } },
          blocksReceived: { none: { blockerUserId: userId } },
        },
      },
      include: {
        user: { select: storyAuthorSelect },
        views: {
          where: { viewerUserId: userId },
          select: { id: true },
        },
        _count: {
          select: { views: true },
        },
      },
      orderBy: { createdAt: 'asc' },
      take: 600,
    });

    const groups = new Map<string, PresentedStoryGroup>();
    for (const story of stories) {
      const isOwner = story.userId === userId;
      let group = groups.get(story.userId);
      if (!group) {
        group = {
          authorUserId: story.user.id,
          authorSellerProfileId: story.user.sellerProfile?.id ?? null,
          authorName: this.resolveAuthorName(story.user),
          authorAvatarUrl: story.user.avatarUrl ?? '',
          isOwner,
          hasUnviewed: false,
          latestStoryAt: story.createdAt.toISOString(),
          stories: [],
        };
        groups.set(story.userId, group);
      }

      const isViewed = isOwner || story.views.length > 0;
      group.stories.push(
        this.presentStory(story, {
          isOwner,
          isViewed,
          viewCount: isOwner ? story._count.views : null,
        }),
      );
      if (!isViewed) {
        group.hasUnviewed = true;
      }
      const createdAtIso = story.createdAt.toISOString();
      if (createdAtIso > group.latestStoryAt) {
        group.latestStoryAt = createdAtIso;
      }
    }

    return [...groups.values()].sort((left, right) => {
      if (left.isOwner !== right.isOwner) {
        return left.isOwner ? -1 : 1;
      }
      if (left.hasUnviewed !== right.hasUnviewed) {
        return left.hasUnviewed ? -1 : 1;
      }
      return right.latestStoryAt.localeCompare(left.latestStoryAt);
    });
  }

  async markViewed(userId: string, storyId: string) {
    const story = await this.prisma.userStory.findUnique({
      where: { id: storyId },
      select: { id: true, userId: true },
    });
    if (!story) {
      throw new NotFoundException('Story not found');
    }
    if (story.userId === userId) {
      return { storyId, viewed: false, isOwner: true };
    }

    await this.prisma.userStoryView.upsert({
      where: {
        storyId_viewerUserId: { storyId, viewerUserId: userId },
      },
      create: { storyId, viewerUserId: userId },
      update: {},
    });

    return { storyId, viewed: true, isOwner: false };
  }

  async getViewers(userId: string, storyId: string) {
    const story = await this.prisma.userStory.findUnique({
      where: { id: storyId },
      select: { id: true, userId: true },
    });
    if (!story) {
      throw new NotFoundException('Story not found');
    }
    if (story.userId !== userId) {
      throw new ForbiddenException('Only the story owner can see its viewers');
    }

    const views = await this.prisma.userStoryView.findMany({
      where: { storyId },
      include: {
        viewer: {
          select: {
            id: true,
            displayName: true,
            avatarUrl: true,
            role: true,
            sellerProfile: { select: { id: true } },
          },
        },
      },
      orderBy: { viewedAt: 'desc' },
      take: MAX_VIEWERS_RETURNED,
    });

    return views.map((view) => ({
      id: view.viewer.id,
      userId: view.viewer.id,
      sellerProfileId: view.viewer.sellerProfile?.id ?? null,
      role: view.viewer.role,
      displayName: view.viewer.displayName,
      avatarUrl: view.viewer.avatarUrl ?? '',
      viewedAt: view.viewedAt.toISOString(),
    }));
  }

  async deleteStory(userId: string, storyId: string) {
    const story = await this.prisma.userStory.findUnique({
      where: { id: storyId },
    });
    if (!story) {
      throw new NotFoundException('Story not found');
    }
    if (story.userId !== userId) {
      throw new ForbiddenException('Only the story owner can delete it');
    }

    await this.prisma.userStory.delete({ where: { id: storyId } });
    await this.deleteAssetQuietly(story);

    const audienceUserIds = await this.resolveAudienceUserIds(userId);
    this.conversationsRealtimeGateway.emitStoriesEvent(
      [userId, ...audienceUserIds],
      {
        type: 'stories:updated',
        action: 'deleted',
        authorUserId: userId,
        storyId,
      },
    );

    return { id: storyId, deleted: true };
  }

  /**
   * Feed queries already filter on expiresAt; this only keeps the table
   * (and the Cloudinary folder) from growing forever.
   */
  @Cron(CronExpression.EVERY_HOUR, { name: 'purgeExpiredUserStories' })
  async purgeExpiredStories() {
    const threshold = new Date(Date.now() - STORY_PURGE_GRACE_MS);
    const expiredStories = await this.prisma.userStory.findMany({
      where: { expiresAt: { lt: threshold } },
      select: {
        id: true,
        mediaType: true,
        mediaUrl: true,
        mediaPublicId: true,
      },
      take: 200,
    });
    if (expiredStories.length === 0) {
      return;
    }

    await this.prisma.userStory.deleteMany({
      where: { id: { in: expiredStories.map((story) => story.id) } },
    });
    for (const story of expiredStories) {
      await this.deleteAssetQuietly(story);
    }
    this.logger.log(`Purged ${expiredStories.length} expired stories`);
  }

  /** Everyone whose row shows this author's stories (used for realtime). */
  private async resolveAudienceUserIds(authorUserId: string) {
    const [followerLinks, followingLinks, conversations] = await Promise.all([
      this.prisma.sellerFollow.findMany({
        where: { sellerProfile: { userId: authorUserId } },
        select: { followerUserId: true },
      }),
      this.prisma.sellerFollow.findMany({
        where: { followerUserId: authorUserId },
        select: { sellerProfile: { select: { userId: true } } },
      }),
      this.prisma.chatConversation.findMany({
        where: {
          OR: [{ buyerUserId: authorUserId }, { sellerUserId: authorUserId }],
        },
        select: { buyerUserId: true, sellerUserId: true },
      }),
    ]);

    const audience = new Set<string>();
    for (const link of followerLinks) {
      audience.add(link.followerUserId);
    }
    for (const link of followingLinks) {
      audience.add(link.sellerProfile.userId);
    }
    for (const conversation of conversations) {
      audience.add(conversation.buyerUserId);
      audience.add(conversation.sellerUserId);
    }
    audience.delete(authorUserId);
    return [...audience];
  }

  private async deleteAssetQuietly(story: {
    id: string;
    mediaType: StoryMediaType;
    mediaUrl: string;
    mediaPublicId: string | null;
  }) {
    try {
      await this.cloudinaryService.deleteAsset({
        mediaType: story.mediaType === 'VIDEO' ? 'video' : 'image',
        publicId: story.mediaPublicId,
        publicUrl: story.mediaUrl,
      });
    } catch (error) {
      this.logger.warn(
        `Could not delete Cloudinary asset for story ${story.id}: ${
          error instanceof Error ? error.message : String(error)
        }`,
      );
    }
  }

  /**
   * The mobile multipart helper may label the part `application/octet-stream`
   * on older builds, so the extension (then the client's hint) is consulted
   * before rejecting. Cloudinary re-validates on upload.
   */
  private resolveMediaType(
    file: Express.Multer.File,
    hint: 'IMAGE' | 'VIDEO' | undefined,
  ): StoryMediaType | null {
    const mimeType = file.mimetype?.trim().toLowerCase() ?? '';
    if (mimeType.startsWith('image/')) {
      return 'IMAGE';
    }
    if (mimeType.startsWith('video/')) {
      return 'VIDEO';
    }
    if (mimeType.length > 0 && mimeType !== 'application/octet-stream') {
      return null;
    }
    const extension =
      (file.originalname ?? '').toLowerCase().split('.').pop() ?? '';
    if (IMAGE_EXTENSIONS.includes(extension)) {
      return 'IMAGE';
    }
    if (VIDEO_EXTENSIONS.includes(extension)) {
      return 'VIDEO';
    }
    return hint ?? null;
  }

  private resolveAuthorName(author: StoryAuthor) {
    const studioName = author.sellerProfile?.studioName?.trim() ?? '';
    return studioName.length > 0 ? studioName : author.displayName;
  }

  private presentStory(
    story: StoryRow,
    flags: { isOwner: boolean; isViewed: boolean; viewCount: number | null },
  ): PresentedStory {
    return {
      id: story.id,
      authorUserId: story.userId,
      mediaType: story.mediaType,
      mediaUrl: story.mediaUrl,
      thumbnailUrl: story.thumbnailUrl,
      durationSeconds: story.durationSeconds,
      caption: story.caption,
      createdAt: story.createdAt.toISOString(),
      expiresAt: story.expiresAt.toISOString(),
      isViewed: flags.isViewed,
      isOwner: flags.isOwner,
      viewCount: flags.viewCount,
    };
  }
}
