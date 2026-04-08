import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { getApps, initializeApp, cert, type App, type ServiceAccount } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';

import { PrismaService } from '../prisma/prisma.service';
import { RegisterDeviceTokenDto } from '../auth/dto/register-device-token.dto';

type SendChatMessageNotificationArgs = {
  recipientUserId: string;
  conversationId: string;
  senderDisplayName: string;
  senderAvatarUrl?: string;
  senderRoleLabel: string;
  recipientDisplayName: string;
  content: string;
  conversationKind: 'DIRECT' | 'PRODUCT';
  productId?: string;
};

type SendProductPublishedNotificationArgs = {
  sellerProfileId: string;
  sellerUserId: string;
  sellerDisplayName: string;
  sellerAvatarUrl?: string;
  productId: string;
  productTitle: string;
  productImageUrl?: string;
};

type SendProductUpdatedNotificationArgs = {
  sellerProfileId: string;
  sellerUserId: string;
  sellerDisplayName: string;
  sellerAvatarUrl?: string;
  productId: string;
  productTitle: string;
  productImageUrl?: string;
};

type SendFollowedProductCommentNotificationArgs = {
  sellerProfileId: string;
  sellerUserId: string;
  sellerDisplayName: string;
  sellerAvatarUrl?: string;
  commenterUserId: string;
  commenterDisplayName: string;
  productId: string;
  productTitle: string;
  productImageUrl?: string;
};

@Injectable()
export class PushNotificationsService {
  private readonly logger = new Logger(PushNotificationsService.name);
  private readonly firebaseApp?: App;

  constructor(
    private readonly prisma: PrismaService,
    private readonly configService: ConfigService,
  ) {
    this.firebaseApp = this.initializeFirebaseApp();
  }

  async registerDeviceToken(userId: string, dto: RegisterDeviceTokenDto) {
    const token = dto.token.trim();

    await this.prisma.userDeviceToken.upsert({
      where: { token },
      update: {
        userId,
        platform: dto.platform,
        lastSeenAt: new Date(),
      },
      create: {
        userId,
        token,
        platform: dto.platform,
        lastSeenAt: new Date(),
      },
    });
  }

  async sendChatMessageNotification(args: SendChatMessageNotificationArgs) {
    const deviceTokens = await this.prisma.userDeviceToken.findMany({
      where: {
        userId: args.recipientUserId,
      },
      select: {
        token: true,
      },
    });

    if (deviceTokens.length == 0) {
      return;
    }

    if (!this.firebaseApp) {
      this.logger.warn(
        `Skipping push notification for conversation ${args.conversationId} because Firebase Admin is not configured.`,
      );
      return;
    }

    const response = await getMessaging(this.firebaseApp).sendEachForMulticast({
      tokens: deviceTokens.map((deviceToken) => deviceToken.token),
      notification: {
        title: args.senderDisplayName,
        body: this.buildMessagePreview(args.content),
      },
      data: {
        type: 'chat_message',
        conversationId: args.conversationId,
        participantName: args.senderDisplayName,
        participantRole: args.senderRoleLabel,
        participantAvatarUrl: args.senderAvatarUrl ?? '',
        conversationKind: args.conversationKind,
        productId: args.productId ?? '',
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'bahibo_messages',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    });

    const invalidTokens = response.responses
      .map((item, index) => ({ item, index }))
      .filter(({ item }) => {
        const code = item.error?.code;
        return (
          code === 'messaging/invalid-registration-token' ||
          code === 'messaging/registration-token-not-registered'
        );
      })
      .map(({ index }) => deviceTokens[index].token);

    if (invalidTokens.length > 0) {
      await this.prisma.userDeviceToken.deleteMany({
        where: {
          token: {
            in: invalidTokens,
          },
        },
      });
    }
  }

  async sendProductPublishedNotification(
    args: SendProductPublishedNotificationArgs,
  ) {
    const followerLinks = await this.prisma.sellerFollow.findMany({
      where: {
        sellerProfileId: args.sellerProfileId,
        followerUserId: {
          not: args.sellerUserId,
        },
      },
      select: {
        followerUserId: true,
      },
    });

    const recipientUserIds = Array.from(
      new Set(followerLinks.map((link) => link.followerUserId)),
    );

    if (recipientUserIds.length === 0) {
      return;
    }

    const deviceTokens = await this.prisma.userDeviceToken.findMany({
      where: {
        userId: {
          in: recipientUserIds,
        },
      },
      select: {
        token: true,
      },
    });

    if (deviceTokens.length === 0) {
      return;
    }

    if (!this.firebaseApp) {
      this.logger.warn(
        `Skipping product notification for ${args.productId} because Firebase Admin is not configured.`,
      );
      return;
    }

    const response = await getMessaging(this.firebaseApp).sendEachForMulticast({
      tokens: deviceTokens.map((deviceToken) => deviceToken.token),
      notification: {
        title: args.sellerDisplayName,
        body: `a publie un nouveau produit : ${args.productTitle}.`,
      },
      data: {
        type: 'product_added',
        sellerProfileId: args.sellerProfileId,
        sellerUserId: args.sellerUserId,
        sellerName: args.sellerDisplayName,
        sellerAvatarUrl: args.sellerAvatarUrl ?? '',
        productId: args.productId,
        productTitle: args.productTitle,
        productImageUrl: args.productImageUrl ?? '',
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'bahibo_messages',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    });

    const invalidTokens = response.responses
      .map((item, index) => ({ item, index }))
      .filter(({ item }) => {
        const code = item.error?.code;
        return (
          code === 'messaging/invalid-registration-token' ||
          code === 'messaging/registration-token-not-registered'
        );
      })
      .map(({ index }) => deviceTokens[index].token);

    if (invalidTokens.length > 0) {
      await this.prisma.userDeviceToken.deleteMany({
        where: {
          token: {
            in: invalidTokens,
          },
        },
      });
    }
  }

  async sendProductUpdatedNotification(
    args: SendProductUpdatedNotificationArgs,
  ) {
    const followerLinks = await this.prisma.sellerFollow.findMany({
      where: {
        sellerProfileId: args.sellerProfileId,
        followerUserId: {
          not: args.sellerUserId,
        },
      },
      select: {
        followerUserId: true,
      },
    });

    const recipientUserIds = Array.from(
      new Set(followerLinks.map((link) => link.followerUserId)),
    );

    if (recipientUserIds.length === 0) {
      return;
    }

    const deviceTokens = await this.prisma.userDeviceToken.findMany({
      where: {
        userId: {
          in: recipientUserIds,
        },
      },
      select: {
        token: true,
      },
    });

    if (deviceTokens.length === 0) {
      return;
    }

    if (!this.firebaseApp) {
      this.logger.warn(
        `Skipping product update notification for ${args.productId} because Firebase Admin is not configured.`,
      );
      return;
    }

    const response = await getMessaging(this.firebaseApp).sendEachForMulticast({
      tokens: deviceTokens.map((deviceToken) => deviceToken.token),
      notification: {
        title: args.sellerDisplayName,
        body: `a mis a jour le produit : ${args.productTitle}.`,
      },
      data: {
        type: 'product_updated',
        sellerProfileId: args.sellerProfileId,
        sellerUserId: args.sellerUserId,
        sellerName: args.sellerDisplayName,
        sellerAvatarUrl: args.sellerAvatarUrl ?? '',
        productId: args.productId,
        productTitle: args.productTitle,
        productImageUrl: args.productImageUrl ?? '',
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'bahibo_messages',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    });

    const invalidTokens = response.responses
      .map((item, index) => ({ item, index }))
      .filter(({ item }) => {
        const code = item.error?.code;
        return (
          code === 'messaging/invalid-registration-token' ||
          code === 'messaging/registration-token-not-registered'
        );
      })
      .map(({ index }) => deviceTokens[index].token);

    if (invalidTokens.length > 0) {
      await this.prisma.userDeviceToken.deleteMany({
        where: {
          token: {
            in: invalidTokens,
          },
        },
      });
    }
  }

  async sendFollowedProductCommentNotification(
    args: SendFollowedProductCommentNotificationArgs,
  ) {
    const followerLinks = await this.prisma.sellerFollow.findMany({
      where: {
        sellerProfileId: args.sellerProfileId,
        followerUserId: {
          notIn: [args.sellerUserId, args.commenterUserId],
        },
      },
      select: {
        followerUserId: true,
      },
    });

    const recipientUserIds = Array.from(
      new Set(followerLinks.map((link) => link.followerUserId)),
    );

    if (recipientUserIds.length === 0) {
      return;
    }

    const deviceTokens = await this.prisma.userDeviceToken.findMany({
      where: {
        userId: {
          in: recipientUserIds,
        },
      },
      select: {
        token: true,
      },
    });

    if (deviceTokens.length === 0) {
      return;
    }

    if (!this.firebaseApp) {
      this.logger.warn(
        `Skipping follower comment notification for ${args.productId} because Firebase Admin is not configured.`,
      );
      return;
    }

    const response = await getMessaging(this.firebaseApp).sendEachForMulticast({
      tokens: deviceTokens.map((deviceToken) => deviceToken.token),
      notification: {
        title: args.sellerDisplayName,
        body: `${args.commenterDisplayName} a commente le produit ${args.productTitle}.`,
      },
      data: {
        type: 'followed_product_comment',
        sellerProfileId: args.sellerProfileId,
        sellerUserId: args.sellerUserId,
        sellerName: args.sellerDisplayName,
        sellerAvatarUrl: args.sellerAvatarUrl ?? '',
        productId: args.productId,
        productTitle: args.productTitle,
        productImageUrl: args.productImageUrl ?? '',
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'bahibo_messages',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    });

    const invalidTokens = response.responses
      .map((item, index) => ({ item, index }))
      .filter(({ item }) => {
        const code = item.error?.code;
        return (
          code === 'messaging/invalid-registration-token' ||
          code === 'messaging/registration-token-not-registered'
        );
      })
      .map(({ index }) => deviceTokens[index].token);

    if (invalidTokens.length > 0) {
      await this.prisma.userDeviceToken.deleteMany({
        where: {
          token: {
            in: invalidTokens,
          },
        },
      });
    }
  }

  private initializeFirebaseApp() {
    const existingApps = getApps();
    if (existingApps.length > 0) {
      return existingApps[0];
    }

    const serviceAccount = this.resolveServiceAccount();
    if (!serviceAccount) {
      this.logger.warn(
        'Firebase Admin credentials are not configured. Set FIREBASE_SERVICE_ACCOUNT_JSON or FIREBASE_PROJECT_ID/FIREBASE_CLIENT_EMAIL/FIREBASE_PRIVATE_KEY to enable push delivery.',
      );
      return undefined;
    }

    return initializeApp({
      credential: cert(serviceAccount),
      projectId: serviceAccount.projectId,
    });
  }

  private resolveServiceAccount(): ServiceAccount | undefined {
    const rawJson = this.configService.get<string>('FIREBASE_SERVICE_ACCOUNT_JSON');
    if (rawJson?.trim()) {
      return this.parseServiceAccountJson(rawJson);
    }

    const projectId = this.configService.get<string>('FIREBASE_PROJECT_ID');
    const clientEmail = this.configService.get<string>('FIREBASE_CLIENT_EMAIL');
    const privateKey = this.configService.get<string>('FIREBASE_PRIVATE_KEY');

    if (!projectId || !clientEmail || !privateKey) {
      return undefined;
    }

    return {
      projectId,
      clientEmail,
      privateKey: privateKey.replace(/\\n/g, '\n'),
    };
  }

  private parseServiceAccountJson(rawJson: string): ServiceAccount | undefined {
    try {
      const parsed = JSON.parse(rawJson) as ServiceAccount;
      if (!parsed.projectId || !parsed.clientEmail || !parsed.privateKey) {
        return undefined;
      }

      return {
        ...parsed,
        privateKey: parsed.privateKey.replace(/\\n/g, '\n'),
      };
    } catch (error) {
      this.logger.error('Unable to parse FIREBASE_SERVICE_ACCOUNT_JSON', error as Error);
      return undefined;
    }
  }

  private buildMessagePreview(content: string) {
    const trimmed = content.trim();
    if (trimmed.length <= 120) {
      return trimmed;
    }

    return `${trimmed.slice(0, 117)}...`;
  }
}