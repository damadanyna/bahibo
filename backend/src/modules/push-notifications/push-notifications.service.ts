import { Injectable, Logger } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import {
  getApps,
  initializeApp,
  cert,
  type App,
  type ServiceAccount,
} from "firebase-admin/app";
import { getMessaging, type MulticastMessage } from "firebase-admin/messaging";

import { PrismaService } from "../prisma/prisma.service";
import { RegisterDeviceTokenDto } from "../auth/dto/register-device-token.dto";

const ANDROID_NOTIFICATION_CHANNEL_ID = "banay_messages_v2";
const ANDROID_NOTIFICATION_SOUND = "notification";

type SendChatMessageNotificationArgs = {
  recipientUserId: string;
  conversationId: string;
  senderDisplayName: string;
  senderAvatarUrl?: string;
  senderRoleLabel: string;
  recipientDisplayName: string;
  content: string;
  conversationKind: "DIRECT" | "PRODUCT";
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

type SendSellerProductCommentNotificationArgs = {
  recipientUserId: string;
  commenterUserId: string;
  commenterDisplayName: string;
  commenterAvatarUrl?: string;
  productId: string;
  productTitle: string;
  productImageUrl?: string;
};

type SendSellerFollowNotificationArgs = {
  recipientUserId: string;
  followerUserId: string;
  followerDisplayName: string;
  followerAvatarUrl?: string;
  sellerProfileId: string;
};

type SendShopRequestApprovedNotificationArgs = {
  recipientUserId: string;
  sellerProfileId?: string;
  sellerDisplayName: string;
  sellerAvatarUrl?: string;
};

type SendStoryPublishedNotificationArgs = {
  sellerProfileId: string;
  sellerUserId: string;
  sellerDisplayName: string;
  sellerAvatarUrl?: string;
  storyId: string;
  storyImageUrl?: string;
};

type SendLiveStartedNotificationArgs = {
  sellerProfileId: string;
  sellerUserId: string;
  sellerDisplayName: string;
  sellerAvatarUrl?: string;
  liveTitle: string;
};

type SendIncomingCallNotificationArgs = {
  recipientUserId: string;
  callId: string;
  conversationId: string;
  callerDisplayName: string;
  callerAvatarUrl?: string;
};

type SendMissedCallNotificationArgs = {
  recipientUserId: string;
  callId: string;
  conversationId: string;
  callerDisplayName: string;
  callerAvatarUrl?: string;
};

/** A push fanned out to every follower of one shop (story, live). */
type ShopFollowersPushArgs = {
  sellerProfileId: string;
  sellerUserId: string;
  /** Same tag => the OS replaces the shop's previous tile of this kind. */
  groupKey: string;
  /** Names the event in the log line when Firebase Admin is not configured. */
  subject: string;
  notification: { title: string; body: string };
  data: Record<string, string>;
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
      this.logger.debug(
        `[PUSH] userId=${args.recipientUserId} has NO device tokens → false`,
      );
      return false;
    }

    if (!this.firebaseApp) {
      this.logger.warn(
        `Skipping push notification for conversation ${args.conversationId} because Firebase Admin is not configured.`,
      );
      return false;
    }

    const response = await getMessaging(this.firebaseApp).sendEachForMulticast({
      tokens: deviceTokens.map((deviceToken) => deviceToken.token),
      notification: {
        title: args.senderDisplayName,
        body: this.buildMessagePreview(args.content),
      },
      data: {
        type: "chat_message",
        conversationId: args.conversationId,
        participantName: args.senderDisplayName,
        participantRole: args.senderRoleLabel,
        participantAvatarUrl: args.senderAvatarUrl ?? "",
        conversationKind: args.conversationKind,
        productId: args.productId ?? "",
      },
      android: {
        priority: "high",
        notification: {
          channelId: ANDROID_NOTIFICATION_CHANNEL_ID,
          sound: ANDROID_NOTIFICATION_SOUND,
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
          // Same tag => the OS replaces the previous notification for this
          // conversation instead of stacking a new tile per message.
          tag: args.conversationId,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            // iOS-side equivalent of the Android tag: collapses/threads
            // notifications from the same conversation in Notification Center.
            "thread-id": args.conversationId,
          },
        },
      },
    });

    const invalidTokens = response.responses
      .map((item, index) => ({ item, index }))
      .filter(({ item }) => {
        const code = item.error?.code;
        return (
          code === "messaging/invalid-registration-token" ||
          code === "messaging/registration-token-not-registered"
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

    const result = response.successCount > 0;
    this.logger.debug(
      `[PUSH] userId=${args.recipientUserId} | ` +
        `sent=${response.successCount}/${deviceTokens.length} | ` +
        `failed=${response.failureCount} | ` +
        `result=${result}`,
    );

    await this.sendChatMessageDeliveryPing(
      deviceTokens.map((deviceToken) => deviceToken.token),
    );

    return result;
  }

  /**
   * A message carrying both `notification` and `data` is only delivered to
   * the app's Dart code when the app is in the foreground: while
   * backgrounded, FCM hands it straight to the OS tray and never invokes
   * firebaseMessagingBackgroundHandler. Sending this second, data-only
   * message right after guarantees the background handler still runs (FCM
   * always delivers data-only messages to it, regardless of app state), so
   * the recipient's device can flip pending messages to "delivered" the
   * moment it's reachable — see ConversationsApiService.pingDelivery on the
   * client and POST /conversations/delivery-ping on this server.
   */
  private async sendChatMessageDeliveryPing(tokens: string[]) {
    if (tokens.length === 0 || !this.firebaseApp) {
      return;
    }

    try {
      await getMessaging(this.firebaseApp).sendEachForMulticast({
        tokens,
        data: {
          type: "chat_message_delivery_ping",
        },
        android: {
          priority: "high",
        },
        apns: {
          headers: {
            "apns-priority": "5",
            "apns-push-type": "background",
          },
          payload: {
            aps: {
              "content-available": 1,
            },
          },
        },
      });
    } catch (error) {
      this.logger.warn(
        `Failed to send chat message delivery ping: ${(error as Error).message}`,
      );
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
        type: "product_added",
        sellerProfileId: args.sellerProfileId,
        sellerUserId: args.sellerUserId,
        sellerName: args.sellerDisplayName,
        sellerAvatarUrl: args.sellerAvatarUrl ?? "",
        productId: args.productId,
        productTitle: args.productTitle,
        productImageUrl: args.productImageUrl ?? "",
      },
      android: {
        priority: "high",
        notification: {
          channelId: ANDROID_NOTIFICATION_CHANNEL_ID,
          sound: ANDROID_NOTIFICATION_SOUND,
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });

    const invalidTokens = response.responses
      .map((item, index) => ({ item, index }))
      .filter(({ item }) => {
        const code = item.error?.code;
        return (
          code === "messaging/invalid-registration-token" ||
          code === "messaging/registration-token-not-registered"
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
        type: "product_updated",
        sellerProfileId: args.sellerProfileId,
        sellerUserId: args.sellerUserId,
        sellerName: args.sellerDisplayName,
        sellerAvatarUrl: args.sellerAvatarUrl ?? "",
        productId: args.productId,
        productTitle: args.productTitle,
        productImageUrl: args.productImageUrl ?? "",
      },
      android: {
        priority: "high",
        notification: {
          channelId: ANDROID_NOTIFICATION_CHANNEL_ID,
          sound: ANDROID_NOTIFICATION_SOUND,
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });

    const invalidTokens = response.responses
      .map((item, index) => ({ item, index }))
      .filter(({ item }) => {
        const code = item.error?.code;
        return (
          code === "messaging/invalid-registration-token" ||
          code === "messaging/registration-token-not-registered"
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
        type: "followed_product_comment",
        sellerProfileId: args.sellerProfileId,
        sellerUserId: args.sellerUserId,
        sellerName: args.sellerDisplayName,
        sellerAvatarUrl: args.sellerAvatarUrl ?? "",
        productId: args.productId,
        productTitle: args.productTitle,
        productImageUrl: args.productImageUrl ?? "",
      },
      android: {
        priority: "high",
        notification: {
          channelId: ANDROID_NOTIFICATION_CHANNEL_ID,
          sound: ANDROID_NOTIFICATION_SOUND,
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });

    const invalidTokens = response.responses
      .map((item, index) => ({ item, index }))
      .filter(({ item }) => {
        const code = item.error?.code;
        return (
          code === "messaging/invalid-registration-token" ||
          code === "messaging/registration-token-not-registered"
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

  async sendSellerProductCommentNotification(
    args: SendSellerProductCommentNotificationArgs,
  ) {
    const deviceTokens = await this.prisma.userDeviceToken.findMany({
      where: {
        userId: args.recipientUserId,
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
        `Skipping seller comment notification for ${args.productId} because Firebase Admin is not configured.`,
      );
      return;
    }

    const response = await getMessaging(this.firebaseApp).sendEachForMulticast({
      tokens: deviceTokens.map((deviceToken) => deviceToken.token),
      notification: {
        title: args.commenterDisplayName,
        body: `a commente votre produit ${args.productTitle}.`,
      },
      data: {
        type: "product_comment",
        sellerName: args.commenterDisplayName,
        sellerAvatarUrl: args.commenterAvatarUrl ?? "",
        commenterUserId: args.commenterUserId,
        productId: args.productId,
        productTitle: args.productTitle,
        productImageUrl: args.productImageUrl ?? "",
      },
      android: {
        priority: "high",
        notification: {
          channelId: ANDROID_NOTIFICATION_CHANNEL_ID,
          sound: ANDROID_NOTIFICATION_SOUND,
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });

    const invalidTokens = response.responses
      .map((item, index) => ({ item, index }))
      .filter(({ item }) => {
        const code = item.error?.code;
        return (
          code === "messaging/invalid-registration-token" ||
          code === "messaging/registration-token-not-registered"
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

  async sendSellerFollowNotification(args: SendSellerFollowNotificationArgs) {
    const deviceTokens = await this.prisma.userDeviceToken.findMany({
      where: {
        userId: args.recipientUserId,
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
        `Skipping seller follow notification for seller profile ${args.sellerProfileId} because Firebase Admin is not configured.`,
      );
      return;
    }

    const response = await getMessaging(this.firebaseApp).sendEachForMulticast({
      tokens: deviceTokens.map((deviceToken) => deviceToken.token),
      notification: {
        title: args.followerDisplayName,
        body: "vient de s'abonner a votre boutique.",
      },
      data: {
        type: "seller_follow",
        sellerProfileId: args.sellerProfileId,
        followerUserId: args.followerUserId,
        sellerName: args.followerDisplayName,
        sellerAvatarUrl: args.followerAvatarUrl ?? "",
      },
      android: {
        priority: "high",
        notification: {
          channelId: ANDROID_NOTIFICATION_CHANNEL_ID,
          sound: ANDROID_NOTIFICATION_SOUND,
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });

    const invalidTokens = response.responses
      .map((item, index) => ({ item, index }))
      .filter(({ item }) => {
        const code = item.error?.code;
        return (
          code === "messaging/invalid-registration-token" ||
          code === "messaging/registration-token-not-registered"
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

  /**
   * Wakes the callee's phone. Android gets a data-only message so the app
   * renders (and can dismiss) its own full-screen call notification; iOS
   * gets a plain alert, opened into the call screen if still ringing.
   */
  async sendIncomingCallNotification(args: SendIncomingCallNotificationArgs) {
    return this.sendToUser(args.recipientUserId, {
      data: {
        type: "incoming_call",
        callId: args.callId,
        conversationId: args.conversationId,
        callerName: args.callerDisplayName,
        callerAvatarUrl: args.callerAvatarUrl ?? "",
      },
      android: {
        priority: "high",
        // A call not delivered within the ring window is useless.
        ttl: 45_000,
      },
      apns: {
        headers: {
          "apns-priority": "10",
        },
        payload: {
          aps: {
            alert: {
              title: args.callerDisplayName,
              body: "Appel vocal entrant",
            },
            sound: "default",
            "thread-id": `call-${args.callId}`,
          },
        },
      },
    });
  }

  /**
   * The callee never picked up, or the caller gave up first: one clear tile
   * for the callee, opening the conversation (carries the same
   * `conversationId` / `participant*` keys as a chat push).
   */
  async sendMissedCallNotification(args: SendMissedCallNotificationArgs) {
    const groupKey = `missed-call-${args.callId}`;
    return this.sendToUser(args.recipientUserId, {
      notification: {
        title: "Appel manqué",
        body: `${args.callerDisplayName} a essayé de vous appeler.`,
      },
      data: {
        type: "missed_call",
        callId: args.callId,
        conversationId: args.conversationId,
        participantName: args.callerDisplayName,
        participantRole: "",
        participantAvatarUrl: args.callerAvatarUrl ?? "",
      },
      android: {
        priority: "high",
        notification: {
          channelId: ANDROID_NOTIFICATION_CHANNEL_ID,
          sound: ANDROID_NOTIFICATION_SOUND,
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
          tag: groupKey,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            "thread-id": groupKey,
          },
        },
      },
    });
  }

  /** Silent: lets the callee's app take down its ringing notification. */
  async sendCallCancelledNotification(args: {
    recipientUserId: string;
    callId: string;
  }) {
    return this.sendToUser(args.recipientUserId, {
      data: {
        type: "call_cancelled",
        callId: args.callId,
      },
      android: {
        priority: "high",
        ttl: 60_000,
      },
      apns: {
        headers: {
          "apns-push-type": "background",
          "apns-priority": "5",
        },
        payload: {
          aps: {
            "content-available": 1,
          },
        },
      },
    });
  }

  /** One user, every device; invalid tokens are pruned like elsewhere. */
  private async sendToUser(
    userId: string,
    message: Omit<MulticastMessage, "tokens">,
  ) {
    const deviceTokens = await this.prisma.userDeviceToken.findMany({
      where: { userId },
      select: { token: true },
    });

    if (deviceTokens.length === 0) {
      return false;
    }

    if (!this.firebaseApp) {
      this.logger.warn(
        `Skipping push for user ${userId} because Firebase Admin is not configured.`,
      );
      return false;
    }

    const response = await getMessaging(this.firebaseApp).sendEachForMulticast({
      ...message,
      tokens: deviceTokens.map((deviceToken) => deviceToken.token),
    });

    const invalidTokens = response.responses
      .map((item, index) => ({ item, index }))
      .filter(({ item }) => {
        const code = item.error?.code;
        return (
          code === "messaging/invalid-registration-token" ||
          code === "messaging/registration-token-not-registered"
        );
      })
      .map(({ index }) => deviceTokens[index].token);

    if (invalidTokens.length > 0) {
      await this.prisma.userDeviceToken.deleteMany({
        where: { token: { in: invalidTokens } },
      });
    }

    return response.successCount > 0;
  }

  /** Every follower of the shop gets one tile per seller (same tag). */
  async sendStoryPublishedNotification(
    args: SendStoryPublishedNotificationArgs,
  ) {
    // Several stories posted in a row by the same shop replace each other
    // instead of stacking (same mechanism as chat conversations).
    await this.sendToShopFollowers({
      sellerProfileId: args.sellerProfileId,
      sellerUserId: args.sellerUserId,
      groupKey: `story-${args.sellerProfileId}`,
      subject: `story ${args.storyId}`,
      notification: {
        title: args.sellerDisplayName,
        body: "a publié une nouvelle story.",
      },
      data: {
        type: "story_published",
        sellerProfileId: args.sellerProfileId,
        sellerUserId: args.sellerUserId,
        sellerName: args.sellerDisplayName,
        sellerAvatarUrl: args.sellerAvatarUrl ?? "",
        storyId: args.storyId,
        storyImageUrl: args.storyImageUrl ?? "",
      },
    });
  }

  /** Followers learn the shop went live; the tap opens the live directly. */
  async sendLiveStartedNotification(args: SendLiveStartedNotificationArgs) {
    const liveTitle = args.liveTitle.trim();

    await this.sendToShopFollowers({
      sellerProfileId: args.sellerProfileId,
      sellerUserId: args.sellerUserId,
      // A host who stops and restarts replaces the tile instead of stacking.
      groupKey: `live-${args.sellerProfileId}`,
      subject: `live of shop ${args.sellerProfileId}`,
      notification: {
        title: args.sellerDisplayName,
        body:
          liveTitle.length > 0
            ? `est en direct : ${liveTitle}`
            : "est en direct maintenant.",
      },
      data: {
        type: "live_started",
        sellerProfileId: args.sellerProfileId,
        sellerUserId: args.sellerUserId,
        sellerName: args.sellerDisplayName,
        sellerAvatarUrl: args.sellerAvatarUrl ?? "",
        liveTitle,
      },
    });
  }

  private async sendToShopFollowers(args: ShopFollowersPushArgs) {
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
        `Skipping follower notification for ${args.subject} because Firebase Admin is not configured.`,
      );
      return;
    }

    const response = await getMessaging(this.firebaseApp).sendEachForMulticast({
      tokens: deviceTokens.map((deviceToken) => deviceToken.token),
      notification: args.notification,
      data: args.data,
      android: {
        priority: "high",
        notification: {
          channelId: ANDROID_NOTIFICATION_CHANNEL_ID,
          sound: ANDROID_NOTIFICATION_SOUND,
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
          tag: args.groupKey,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            "thread-id": args.groupKey,
          },
        },
      },
    });

    const invalidTokens = response.responses
      .map((item, index) => ({ item, index }))
      .filter(({ item }) => {
        const code = item.error?.code;
        return (
          code === "messaging/invalid-registration-token" ||
          code === "messaging/registration-token-not-registered"
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

  async sendShopRequestApprovedNotification(
    args: SendShopRequestApprovedNotificationArgs,
  ) {
    const deviceTokens = await this.prisma.userDeviceToken.findMany({
      where: {
        userId: args.recipientUserId,
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
        `Skipping shop approval notification for user ${args.recipientUserId} because Firebase Admin is not configured.`,
      );
      return;
    }

    const response = await getMessaging(this.firebaseApp).sendEachForMulticast({
      tokens: deviceTokens.map((deviceToken) => deviceToken.token),
      notification: {
        title: "Demande boutique approuvee",
        body: "Votre compte a ete passe en boutique. Vous pouvez maintenant publier vos produits.",
      },
      data: {
        type: "shop_request_approved",
        sellerProfileId: args.sellerProfileId ?? "",
        sellerName: args.sellerDisplayName,
        sellerAvatarUrl: args.sellerAvatarUrl ?? "",
      },
      android: {
        priority: "high",
        notification: {
          channelId: ANDROID_NOTIFICATION_CHANNEL_ID,
          sound: ANDROID_NOTIFICATION_SOUND,
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });

    const invalidTokens = response.responses
      .map((item, index) => ({ item, index }))
      .filter(({ item }) => {
        const code = item.error?.code;
        return (
          code === "messaging/invalid-registration-token" ||
          code === "messaging/registration-token-not-registered"
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
        "Firebase Admin credentials are not configured. Set FIREBASE_SERVICE_ACCOUNT_JSON or FIREBASE_PROJECT_ID/FIREBASE_CLIENT_EMAIL/FIREBASE_PRIVATE_KEY to enable push delivery.",
      );
      return undefined;
    }

    return initializeApp({
      credential: cert(serviceAccount),
      projectId: serviceAccount.projectId,
    });
  }

  private resolveServiceAccount(): ServiceAccount | undefined {
    const rawJson = this.configService.get<string>(
      "FIREBASE_SERVICE_ACCOUNT_JSON",
    );
    if (rawJson?.trim()) {
      return this.parseServiceAccountJson(rawJson);
    }

    const projectId = this.configService.get<string>("FIREBASE_PROJECT_ID");
    const clientEmail = this.configService.get<string>("FIREBASE_CLIENT_EMAIL");
    const privateKey = this.configService.get<string>("FIREBASE_PRIVATE_KEY");

    if (!projectId || !clientEmail || !privateKey) {
      return undefined;
    }

    return {
      projectId,
      clientEmail,
      privateKey: privateKey.replace(/\\n/g, "\n"),
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
        privateKey: parsed.privateKey.replace(/\\n/g, "\n"),
      };
    } catch (error) {
      this.logger.error(
        "Unable to parse FIREBASE_SERVICE_ACCOUNT_JSON",
        error as Error,
      );
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
