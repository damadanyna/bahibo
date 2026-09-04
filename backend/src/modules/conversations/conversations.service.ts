import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from "@nestjs/common";
import { Prisma } from "@prisma/client";

import { PrismaService } from "../prisma/prisma.service";
import { PushNotificationsService } from "../push-notifications/push-notifications.service";
import { CloudinaryService } from "../auth/cloudinary.service";
import { CreateMediaMessageDto } from "./dto/create-media-message.dto";
import { CreateMessageDto } from "./dto/create-message.dto";
import { ConversationsRealtimeGateway } from "./realtime/conversations-realtime.gateway";

const conversationDetailInclude =
  Prisma.validator<Prisma.ChatConversationInclude>()({
    buyer: true,
    seller: true,
    product: {
      include: {
        category: true,
        sellerProfile: {
          include: {
            user: true,
          },
        },
      },
    },
  });

type ConversationDetail = Prisma.ChatConversationGetPayload<{
  include: typeof conversationDetailInclude;
}>;

const conversationMessageInclude =
  Prisma.validator<Prisma.ChatMessageInclude>()({
    media: true,
    sender: true,
  });

type ConversationMessageDetail = Prisma.ChatMessageGetPayload<{
  include: typeof conversationMessageInclude;
}>;

const conversationListInclude =
  Prisma.validator<Prisma.ChatConversationInclude>()({
    buyer: true,
    seller: true,
    product: {
      include: {
        category: true,
        sellerProfile: {
          include: {
            user: true,
          },
        },
      },
    },
    messages: {
      include: {
        media: true,
        sender: true,
      },
      orderBy: {
        createdAt: "desc",
      },
      take: 1,
    },
  });

type ConversationListItem = Prisma.ChatConversationGetPayload<{
  include: typeof conversationListInclude;
}>;

type ConversationThreadMessage = {
  id: string;
  clientMessageId: string | null;
  content: string;
  kind: "TEXT" | "IMAGE" | "DOCUMENT" | "PRODUCT";
  acceptedAt: string | null;
  createdAt: string;
  deliveredAt: string | null;
  readAt: string | null;
  isMine: boolean;
  reply: {
    messageId: string | null;
    senderLabel: string;
    content: string;
  } | null;
  sender: {
    id: string;
    displayName: string;
    avatarUrl: string | null;
  };
  media: ConversationMessageMediaPayload | null;
  product: ConversationMessageProductSnapshot | null;
};

type ConversationRealtimeMessage = Omit<ConversationThreadMessage, "isMine">;

type ConversationMessageMediaPayload = {
  mediaType: "image" | "document";
  publicUrl: string;
  previewUrl: string | null;
  thumbnailUrl: string | null;
  fileName: string | null;
  mimeType: string | null;
  fileSizeBytes: number | null;
  storageProvider: string;
  storageKey: string | null;
  mediaGroupId: string | null;
  width: number | null;
  height: number | null;
  encryptionScheme: string | null;
  encryptionKeyB64: string | null;
  encryptionIvB64: string | null;
  fileSha256B64: string | null;
};

type ConversationMessageProductSnapshot = {
  id: string | null;
  title: string;
  subtitle: string;
  priceLabel: string;
  imageUrl: string;
};

type MessageProductSnapshotFields = {
  kind?: "TEXT" | "IMAGE" | "DOCUMENT" | "PRODUCT";
  productId: string | null;
  productTitle: string | null;
  productSubtitle: string | null;
  productPriceLabel: string | null;
  productImageUrl: string | null;
  media?: {
    mediaType: string;
    publicUrl: string;
    previewUrl: string | null;
    thumbnailUrl: string | null;
    fileName: string | null;
    mimeType: string | null;
    fileSizeBytes: number | null;
    storageProvider: string;
    storageKey: string | null;
    mediaGroupId: string | null;
    width: number | null;
    height: number | null;
    encryptionScheme: string | null;
    encryptionKeyB64: string | null;
    encryptionIvB64: string | null;
    fileSha256B64: string | null;
  } | null;
};

const DEFAULT_MESSAGES_PAGE_SIZE = 8;
const MAX_MESSAGES_PAGE_SIZE = 50;

type ConversationMessagesPageOptions = {
  limit?: number;
  beforeMessageId?: string;
};

type ConversationMessagesPage = {
  messages: ConversationMessageDetail[];
  limit: number;
  hasOlderMessages: boolean;
  oldestLoadedMessageId: string | null;
};

type ChatMediaCleanupCandidate = {
  mediaType: "image" | "document";
  storageProvider: string;
  storageKey: string | null;
  publicUrl: string;
};

type ChatMediaAuditCursorState = {
  mediaType: "image" | "document";
  cloudinaryCursor: string | null;
};

type MessageReplyFields = {
  replyToMessageId?: string | null;
  replyToSenderUserId?: string | null;
  replyToSenderName?: string | null;
  replyToContent?: string | null;
};

const maxPhotoAttachmentBytes = 10 * 1024 * 1024;
const maxDocumentAttachmentBytes = 12 * 1024 * 1024;
const allowedPhotoAttachmentExtensions = new Set([
  "jpg",
  "jpeg",
  "png",
  "webp",
  "heic",
  "heif",
]);
const allowedDocumentAttachmentExtensions = new Set([
  "pdf",
  "doc",
  "docx",
  "txt",
]);

@Injectable()
export class ConversationsService {
  private readonly logger = new Logger(ConversationsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly pushNotificationsService: PushNotificationsService,
    private readonly conversationsRealtimeGateway: ConversationsRealtimeGateway,
    private readonly cloudinaryService: CloudinaryService,
  ) {}

  async uploadAttachment(
    userId: string,
    file: Express.Multer.File | undefined,
    type: "photo" | "document",
  ) {
    if (!file) {
      throw new BadRequestException("Attachment file is required");
    }

    this.validateAttachment(file, type);

    if (type === "photo") {
      const uploadResult = await this.cloudinaryService.uploadChatImage(
        file,
        userId,
      );

      return {
        attachmentType: type,
        fileName: file.originalname,
        attachmentUrl: uploadResult.imageUrl,
        originalUrl: uploadResult.originalUrl,
        previewUrl: uploadResult.previewUrl,
        thumbnailUrl: uploadResult.thumbnailUrl,
        publicId: uploadResult.publicId,
      };
    }

    const uploadResult = await this.cloudinaryService.uploadChatDocument(
      file,
      userId,
    );

    return {
      attachmentType: type,
      fileName: file.originalname,
      attachmentUrl: uploadResult.fileUrl,
      originalUrl: uploadResult.originalUrl,
    };
  }

  createDirectPhotoUploadSignature(userId: string) {
    return this.cloudinaryService.createDirectChatImageUploadSignature(userId);
  }

  createDirectDocumentUploadSignature(userId: string) {
    return this.cloudinaryService.createDirectChatDocumentUploadSignature(
      userId,
    );
  }

  private validateAttachment(
    file: Express.Multer.File,
    type: "photo" | "document",
  ) {
    const fileName = file.originalname?.trim() ?? "";
    const extension = this.extractFileExtension(fileName);
    const fileSize = file.size ?? file.buffer?.length ?? 0;

    if (type === "photo") {
      if (!allowedPhotoAttachmentExtensions.has(extension)) {
        throw new BadRequestException(
          "Format de photo non pris en charge. Utilisez JPG, PNG, WEBP ou HEIC.",
        );
      }
      const mimeType = file.mimetype?.trim().toLowerCase() ?? "";
      if (mimeType.length > 0 && !mimeType.startsWith("image/")) {
        throw new BadRequestException(
          "Le fichier envoye n'est pas une image valide.",
        );
      }
      if (fileSize > maxPhotoAttachmentBytes) {
        throw new BadRequestException("La photo depasse la limite de 10 Mo.");
      }
      return;
    }

    if (!allowedDocumentAttachmentExtensions.has(extension)) {
      throw new BadRequestException(
        "Format de document non pris en charge. Utilisez PDF, DOC, DOCX ou TXT.",
      );
    }
    if (fileSize > maxDocumentAttachmentBytes) {
      throw new BadRequestException("Le document depasse la limite de 12 Mo.");
    }
  }

  private extractFileExtension(fileName: string) {
    const lastDot = fileName.lastIndexOf(".");
    if (lastDot < 0 || lastDot === fileName.length - 1) {
      return "";
    }

    return fileName.slice(lastDot + 1).toLowerCase();
  }

  private buildDirectConversationKey(
    firstUserId: string,
    secondUserId: string,
  ) {
    return [firstUserId, secondUserId].sort().join(":");
  }

  private resolveRoleLabel(user: { role: string }) {
    if (user.role === "SELLER") {
      return "Vendeur";
    }
    if (user.role === "ADMIN") {
      return "Administrateur";
    }
    return "Utilisateur";
  }

  private async findUserBlock(firstUserId: string, secondUserId: string) {
    return this.prisma.userBlock.findFirst({
      where: {
        OR: [
          {
            blockerUserId: firstUserId,
            blockedUserId: secondUserId,
          },
          {
            blockerUserId: secondUserId,
            blockedUserId: firstUserId,
          },
        ],
      },
      orderBy: {
        createdAt: "desc",
      },
    });
  }

  private async presentConversationBlockState(
    firstUserId: string,
    secondUserId: string,
  ) {
    const userBlock = await this.findUserBlock(firstUserId, secondUserId);

    return {
      isBlocked: userBlock != null,
      blockedParticipantUserId: userBlock == null ? null : secondUserId,
      blockedMessage:
        userBlock == null
          ? null
          : "Cette conversation est bloquee. Vous pouvez lire l'historique, mais vous ne pouvez plus envoyer de nouveaux messages.",
    };
  }

  private async assertUsersCanInteract(
    firstUserId: string,
    secondUserId: string,
  ) {
    const userBlock = await this.findUserBlock(firstUserId, secondUserId);

    if (userBlock != null) {
      throw new ForbiddenException(
        "Cette conversation est bloquee. Vous ne pouvez plus envoyer de messages.",
      );
    }
  }

  async listConversations(userId: string) {
    const conversations = await this.prisma.chatConversation.findMany({
      where: {
        OR: [{ buyerUserId: userId }, { sellerUserId: userId }],
      },
      include: conversationListInclude,
      orderBy: {
        lastMessageAt: "desc",
      },
    });

    return Promise.all(
      conversations.map(async (conversation) => {
        const unreadCount = await this.prisma.chatMessage.count({
          where: {
            conversationId: conversation.id,
            senderUserId: {
              not: userId,
            },
            readAt: null,
          },
        });

        return this.presentConversationListItem(
          conversation,
          userId,
          unreadCount,
        );
      }),
    );
  }

  /**
   * Buyer/seller relationships are per-pair, not per-product: every product
   * a buyer discusses with the same seller must land in the one
   * conversation for that pair, so `directKey` (symmetric — either user can
   * initiate) is the sole identity, not `buyerUserId`/`sellerUserId`.
   */
  private async getOrCreateDirectConversation(
    userId: string,
    targetUserId: string,
    pageOptions?: ConversationMessagesPageOptions,
  ) {
    if (!targetUserId.trim()) {
      throw new BadRequestException("Target user is required");
    }

    if (targetUserId === userId) {
      throw new BadRequestException(
        "You cannot start a conversation with yourself",
      );
    }

    const targetUser = await this.prisma.user.findUnique({
      where: { id: targetUserId },
    });

    if (!targetUser) {
      throw new NotFoundException("User not found");
    }

    const directKey = this.buildDirectConversationKey(userId, targetUserId);

    const existingConversation = await this.prisma.chatConversation.findFirst({
      where: { directKey },
      include: conversationDetailInclude,
    });

    if (existingConversation) {
      return this.presentConversationDetail(
        existingConversation,
        userId,
        pageOptions,
      );
    }

    await this.assertUsersCanInteract(userId, targetUserId);

    const createdConversation = await this.prisma.chatConversation.create({
      data: {
        buyerUserId: userId,
        sellerUserId: targetUserId,
        kind: "DIRECT",
        directKey,
      },
      include: conversationDetailInclude,
    });

    return this.presentConversationDetail(
      createdConversation,
      userId,
      pageOptions,
    );
  }

  private async resolveSellerForProduct(userId: string, productId: string) {
    const product = await this.prisma.product.findUnique({
      where: { id: productId },
      include: {
        category: true,
        sellerProfile: {
          include: {
            user: true,
          },
        },
      },
    });

    if (!product) {
      throw new NotFoundException("Product not found");
    }

    const sellerUserId = product.sellerProfile.userId;

    if (sellerUserId === userId) {
      throw new BadRequestException(
        "You cannot start a conversation with your own product",
      );
    }

    return { sellerUserId, product };
  }

  async getOrCreateConversationForProduct(
    userId: string,
    productId: string,
    pageOptions?: ConversationMessagesPageOptions,
  ) {
    const { sellerUserId } = await this.resolveSellerForProduct(
      userId,
      productId,
    );

    return this.getOrCreateDirectConversation(
      userId,
      sellerUserId,
      pageOptions,
    );
  }

  async getOrCreateConversationForUser(
    userId: string,
    targetUserId: string,
    pageOptions?: ConversationMessagesPageOptions,
  ) {
    return this.getOrCreateDirectConversation(
      userId,
      targetUserId,
      pageOptions,
    );
  }

  async getConversation(
    userId: string,
    conversationId: string,
    pageOptions?: ConversationMessagesPageOptions,
  ) {
    const conversation = await this.findAccessibleConversation(
      userId,
      conversationId,
    );
    return this.presentConversationDetail(conversation, userId, pageOptions);
  }

  async markConversationRead(userId: string, conversationId: string) {
    const conversation = await this.findAccessibleConversation(
      userId,
      conversationId,
    );
    const readCount = await this.markConversationAsRead(
      conversation.id,
      userId,
    );
    if (readCount > 0) {
      this.emitConversationRead(conversation, userId);
    }

    return {
      conversationId: conversation.id,
      readCount,
      readAt: new Date().toISOString(),
    };
  }

  async deleteMessage(
    userId: string,
    conversationId: string,
    messageId: string,
    scope: "FOR_ME" | "FOR_EVERYONE" = "FOR_EVERYONE",
  ) {
    const conversation = await this.findAccessibleConversation(
      userId,
      conversationId,
    );
    const message = await this.prisma.chatMessage.findFirst({
      where: { id: messageId, conversationId },
      include: { media: true },
    });

    if (!message) {
      throw new NotFoundException("Message not found");
    }

    if (scope === "FOR_ME") {
      // Soft-delete: hidden only for the sender, recipient still sees it.
      await this.prisma.chatMessage.update({
        where: { id: messageId },
        data:
          conversation.buyerUserId === userId
            ? { deletedForBuyerAt: new Date() }
            : { deletedForSellerAt: new Date() },
      });
    } else {
      if (message.senderUserId !== userId) {
        throw new ForbiddenException("You can only delete your own messages.");
      }

      const mediaCleanupCandidate = this.buildMediaCleanupCandidate(message);

      // Replace the content for everyone instead of removing the row so the
      // conversation keeps a stable "message deleted" placeholder.
      await this.prisma.$transaction(async (transaction) => {
        if (message.media != null) {
          await transaction.chatMessageMedia.delete({
            where: { messageId },
          });
        }

        await transaction.chatMessage.update({
          where: { id: messageId },
          data: {
            content: "Message supprime",
            kind: "TEXT",
            replyToMessageId: null,
            replyToSenderUserId: null,
            replyToSenderName: null,
            replyToContent: null,
            productId: null,
            productTitle: null,
            productSubtitle: null,
            productPriceLabel: null,
            productImageUrl: null,
            deletedForSenderAt: null,
            deletedForBuyerAt: null,
            deletedForSellerAt: null,
          },
        });
      });

      this.conversationsRealtimeGateway.emitConversationEvent(
        [conversation.buyerUserId, conversation.sellerUserId],
        {
          type: "message:deleted",
          conversationId: conversation.id,
          actorUserId: userId,
          mediaGroupId: message.media?.mediaGroupId ?? null,
          messageId,
        },
      );

      await this.tryDeleteMessageMediaAsset(mediaCleanupCandidate);
    }

    return this.getConversation(userId, conversationId, {
      limit: DEFAULT_MESSAGES_PAGE_SIZE,
    });
  }

  async auditOrphanedChatMediaAssets(options?: {
    deleteOrphans?: boolean;
    olderThanDays?: number;
    maxAssets?: number;
    actorUserId?: string;
    nextCursor?: string | null;
  }) {
    const olderThanDays = Math.max(1, Math.trunc(options?.olderThanDays ?? 7));
    const maxAssets = Math.min(Math.max(options?.maxAssets ?? 100, 1), 500);
    const deleteOrphans = options?.deleteOrphans === true;
    const cutoff = new Date(Date.now() - olderThanDays * 24 * 60 * 60 * 1000);

    const cursorState = this.decodeChatMediaAuditCursor(options?.nextCursor);
    const pageMediaType = cursorState?.mediaType ?? "image";
    const assetPage = await this.cloudinaryService.listChatAssets({
      mediaType: pageMediaType,
      maxResults: maxAssets,
      nextCursor: cursorState?.cloudinaryCursor ?? null,
    });

    const eligibleAssets = assetPage.assets.filter((asset) => {
      if (!asset.publicId || !asset.createdAt) {
        return false;
      }

      const createdAt = new Date(asset.createdAt);
      return !Number.isNaN(createdAt.getTime()) && createdAt <= cutoff;
    });

    const referencedAssets =
      await this.findReferencedCloudinaryChatAssets(eligibleAssets);
    const orphanedAssets = eligibleAssets.filter(
      (asset) =>
        !referencedAssets.has(asset.publicId) &&
        !(asset.secureUrl && referencedAssets.has(asset.secureUrl)),
    );

    const deleted: string[] = [];
    const failed: Array<{ publicId: string; reason: string }> = [];

    if (deleteOrphans) {
      for (const asset of orphanedAssets) {
        const mediaType = asset.resourceType === "raw" ? "document" : "image";

        try {
          const result = await this.cloudinaryService.deleteAsset({
            mediaType,
            publicId: asset.publicId,
          });

          if (result.result === "ok" || result.result === "not found") {
            deleted.push(asset.publicId);
            this.logger.log(
              `Chat media audit deleted orphaned Cloudinary asset publicId=${asset.publicId} actorUserId=${options?.actorUserId ?? "unknown"}`,
            );
            continue;
          }

          failed.push({
            publicId: asset.publicId,
            reason: `unexpected result: ${result.result}`,
          });
          this.logger.warn(
            `Chat media audit received unexpected Cloudinary deletion result publicId=${asset.publicId} result=${result.result}`,
          );
        } catch (error) {
          const reason = error instanceof Error ? error.message : String(error);
          failed.push({ publicId: asset.publicId, reason });
          this.logger.warn(
            `Chat media audit failed to delete orphaned Cloudinary asset publicId=${asset.publicId} reason=${reason}`,
          );
        }
      }
    }

    const summary = {
      pageMediaType,
      olderThanDays,
      deleteOrphans,
      maxAssets,
      scannedAssets: eligibleAssets.length,
      referencedAssets: eligibleAssets.length - orphanedAssets.length,
      orphanedAssets: orphanedAssets.length,
      deletedAssets: deleted.length,
      failedAssets: failed.length,
    };

    const nextCursor = this.buildChatMediaAuditNextCursor({
      currentMediaType: pageMediaType,
      cloudinaryNextCursor: assetPage.nextCursor,
    });

    this.logger.log(
      `Chat media audit summary actorUserId=${options?.actorUserId ?? "unknown"} ${JSON.stringify(summary)}`,
    );

    return {
      summary,
      nextCursor,
      orphanedAssets: orphanedAssets.map((asset) => ({
        publicId: asset.publicId,
        createdAt: asset.createdAt,
        secureUrl: asset.secureUrl,
        bytes: asset.bytes,
        resourceType: asset.resourceType,
      })),
      deleted,
      failed,
    };
  }

  /**
   * One-off cleanup for the pre-migration data model, where every product
   * discussed with the same seller created its own `ChatConversation` row
   * (unique on buyer/seller/product). Groups existing conversations by
   * symmetric pair, merges every group with more than one row into a single
   * DIRECT conversation, and reassigns their messages accordingly. Dry-run
   * by default (`apply: false`) — must be explicitly told to apply changes.
   */
  async mergeDuplicateConversations(options?: { apply?: boolean }) {
    const apply = options?.apply === true;

    const conversations = await this.prisma.chatConversation.findMany({
      select: {
        id: true,
        buyerUserId: true,
        sellerUserId: true,
        kind: true,
        directKey: true,
        createdAt: true,
        lastMessageAt: true,
        _count: { select: { messages: true } },
      },
      orderBy: { createdAt: "asc" },
    });

    const groupsByPairKey = new Map<string, typeof conversations>();
    for (const conversation of conversations) {
      const pairKey = this.buildDirectConversationKey(
        conversation.buyerUserId,
        conversation.sellerUserId,
      );
      const group = groupsByPairKey.get(pairKey) ?? [];
      group.push(conversation);
      groupsByPairKey.set(pairKey, group);
    }

    let pairsWithDuplicates = 0;
    let conversationsMerged = 0;
    let messagesMoved = 0;
    let reportsRepointed = 0;
    const mergedPairs: Array<{
      pairKey: string;
      canonicalConversationId: string;
      mergedConversationIds: string[];
      messagesMoved: number;
    }> = [];

    for (const [pairKey, group] of groupsByPairKey) {
      if (group.length <= 1) {
        continue;
      }

      pairsWithDuplicates += 1;
      const canonical =
        group.find((conversation) => conversation.kind === "DIRECT") ??
        group[0]; // group is sorted by createdAt asc, so group[0] is the oldest
      const duplicates = group.filter(
        (conversation) => conversation.id !== canonical.id,
      );
      const duplicateIds = duplicates.map((conversation) => conversation.id);
      const groupMessagesMoved = duplicates.reduce(
        (sum, conversation) => sum + conversation._count.messages,
        0,
      );
      const latestMessageAt = group.reduce(
        (latest, conversation) =>
          conversation.lastMessageAt > latest
            ? conversation.lastMessageAt
            : latest,
        canonical.lastMessageAt,
      );

      mergedPairs.push({
        pairKey,
        canonicalConversationId: canonical.id,
        mergedConversationIds: duplicateIds,
        messagesMoved: groupMessagesMoved,
      });
      conversationsMerged += duplicateIds.length;
      messagesMoved += groupMessagesMoved;

      if (!apply) {
        continue;
      }

      await this.prisma.$transaction(async (transaction) => {
        await transaction.chatMessage.updateMany({
          where: { conversationId: { in: duplicateIds } },
          data: { conversationId: canonical.id },
        });

        const repointedReports = await transaction.userReport.updateMany({
          where: { conversationId: { in: duplicateIds } },
          data: { conversationId: canonical.id },
        });
        reportsRepointed += repointedReports.count;

        await transaction.chatConversation.update({
          where: { id: canonical.id },
          data: {
            kind: "DIRECT",
            directKey: canonical.directKey ?? pairKey,
            lastMessageAt: latestMessageAt,
          },
        });

        await transaction.chatConversation.deleteMany({
          where: { id: { in: duplicateIds } },
        });
      });
    }

    const summary = {
      apply,
      pairsInspected: groupsByPairKey.size,
      pairsWithDuplicates,
      conversationsMerged,
      messagesMoved,
      reportsRepointed,
    };

    this.logger.log(
      `Conversation merge ${apply ? "applied" : "dry-run"}: ${JSON.stringify(summary)}`,
    );

    return { summary, mergedPairs };
  }

  private buildMediaCleanupCandidate(
    message: {
      media: {
        mediaType: string;
        storageProvider: string;
        storageKey: string | null;
        publicUrl: string;
      } | null;
    } | null,
  ) {
    const media = message?.media;
    if (!media) {
      return null;
    }

    const mediaType = media.mediaType.trim().toLowerCase();
    if (mediaType !== "image" && mediaType !== "document") {
      return null;
    }

    const storageProvider = media.storageProvider.trim().toLowerCase();
    if (storageProvider !== "cloudinary") {
      return null;
    }

    return {
      mediaType: mediaType as "image" | "document",
      storageProvider,
      storageKey: media.storageKey?.trim() || null,
      publicUrl: media.publicUrl.trim(),
    };
  }

  private async tryDeleteMessageMediaAsset(
    media: ChatMediaCleanupCandidate | null,
  ) {
    if (!media) {
      return;
    }

    const hasRemainingReferences =
      await this.hasRemainingMediaReferences(media);
    if (hasRemainingReferences) {
      this.logger.log(
        `Skipped Cloudinary deletion for chat media because a DB reference still exists storageKey=${media.storageKey ?? "none"} publicUrl=${media.publicUrl}`,
      );
      return;
    }

    try {
      const result = await this.cloudinaryService.deleteAsset({
        mediaType: media.mediaType,
        storageKey: media.storageKey,
        publicUrl: media.publicUrl,
      });

      this.logger.log(
        `Cloudinary deletion completed for chat media result=${result.result} publicId=${result.publicId ?? "unknown"}`,
      );
    } catch (error) {
      const reason = error instanceof Error ? error.message : String(error);
      this.logger.warn(
        `Failed to delete Cloudinary asset after message deletion: ${reason}`,
      );
    }
  }

  private async hasRemainingMediaReferences(media: ChatMediaCleanupCandidate) {
    const orFilters: Prisma.ChatMessageMediaWhereInput[] = [];

    if (media.storageKey) {
      orFilters.push({
        storageProvider: media.storageProvider,
        storageKey: media.storageKey,
      });
    }

    if (media.publicUrl) {
      orFilters.push({
        storageProvider: media.storageProvider,
        publicUrl: media.publicUrl,
      });
    }

    if (orFilters.length === 0) {
      return false;
    }

    const remainingReferences = await this.prisma.chatMessageMedia.count({
      where: {
        OR: orFilters,
      },
    });

    return remainingReferences > 0;
  }

  private async findReferencedCloudinaryChatAssets(
    assets: Array<{ publicId: string; secureUrl: string | null }>,
  ) {
    const publicIds = Array.from(
      new Set(
        assets
          .map((asset) => asset.publicId)
          .filter((value) => value.length > 0),
      ),
    );
    const secureUrls = Array.from(
      new Set(
        assets
          .map((asset) => asset.secureUrl)
          .filter((value): value is string =>
            Boolean(value && value.length > 0),
          ),
      ),
    );

    if (publicIds.length === 0 && secureUrls.length === 0) {
      return new Set<string>();
    }

    const references = await this.prisma.chatMessageMedia.findMany({
      where: {
        storageProvider: "cloudinary",
        OR: [
          ...(publicIds.length > 0 ? [{ storageKey: { in: publicIds } }] : []),
          ...(secureUrls.length > 0 ? [{ publicUrl: { in: secureUrls } }] : []),
        ],
      },
      select: {
        storageKey: true,
        publicUrl: true,
      },
    });

    const referenced = new Set<string>();
    for (const reference of references) {
      if (reference.storageKey) {
        referenced.add(reference.storageKey);
      }

      if (reference.publicUrl) {
        referenced.add(reference.publicUrl);
      }
    }

    return referenced;
  }

  private decodeChatMediaAuditCursor(nextCursor?: string | null) {
    const normalized = nextCursor?.trim() ?? "";
    if (!normalized) {
      return null;
    }

    try {
      const decoded = Buffer.from(normalized, "base64url").toString("utf8");
      const parsed = JSON.parse(decoded) as Partial<ChatMediaAuditCursorState>;

      if (parsed.mediaType !== "image" && parsed.mediaType !== "document") {
        throw new Error("Invalid mediaType");
      }

      return {
        mediaType: parsed.mediaType,
        cloudinaryCursor:
          typeof parsed.cloudinaryCursor === "string" &&
          parsed.cloudinaryCursor.length > 0
            ? parsed.cloudinaryCursor
            : null,
      } satisfies ChatMediaAuditCursorState;
    } catch {
      throw new BadRequestException("Invalid nextCursor");
    }
  }

  private buildChatMediaAuditNextCursor(input: {
    currentMediaType: "image" | "document";
    cloudinaryNextCursor: string | null;
  }) {
    if (input.cloudinaryNextCursor) {
      return Buffer.from(
        JSON.stringify({
          mediaType: input.currentMediaType,
          cloudinaryCursor: input.cloudinaryNextCursor,
        } satisfies ChatMediaAuditCursorState),
        "utf8",
      ).toString("base64url");
    }

    if (input.currentMediaType === "image") {
      return Buffer.from(
        JSON.stringify({
          mediaType: "document",
          cloudinaryCursor: null,
        } satisfies ChatMediaAuditCursorState),
        "utf8",
      ).toString("base64url");
    }

    return null;
  }

  async editMessage(
    userId: string,
    conversationId: string,
    messageId: string,
    content: string,
  ) {
    await this.findAccessibleConversation(userId, conversationId);

    const message = await this.prisma.chatMessage.findFirst({
      where: { id: messageId, conversationId },
    });

    if (!message) {
      throw new NotFoundException("Message not found");
    }

    if (message.senderUserId !== userId) {
      throw new ForbiddenException("You can only edit your own messages.");
    }

    if (message.kind !== "TEXT") {
      throw new BadRequestException("Only text messages can be edited.");
    }

    const trimmed = content.trim();
    if (!trimmed) {
      throw new BadRequestException("Message content cannot be empty.");
    }

    await this.prisma.chatMessage.update({
      where: { id: messageId },
      data: { content: trimmed, editedAt: new Date() },
    });

    return this.getConversation(userId, conversationId, {
      limit: DEFAULT_MESSAGES_PAGE_SIZE,
    });
  }

  async sendMessageForProduct(
    userId: string,
    productId: string,
    dto: CreateMessageDto,
  ) {
    const { sellerUserId, product } = await this.resolveSellerForProduct(
      userId,
      productId,
    );
    const conversation = await this.getOrCreateDirectConversation(
      userId,
      sellerUserId,
    );

    return this.sendMessage(
      userId,
      conversation.id,
      dto,
      this.extractDtoProductSnapshot(dto) ?? {
        id: product.id,
        title: product.title,
        subtitle: `${product.category.name} • ${product.isAvailable ? "Disponible" : "Indisponible"}`,
        priceLabel: `${product.priceAmount.toNumber()} ${product.currencyCode}`,
        imageUrl: product.imageUrl,
      },
    );
  }

  async sendMediaMessageForProduct(
    userId: string,
    productId: string,
    dto: CreateMediaMessageDto,
  ) {
    const { sellerUserId } = await this.resolveSellerForProduct(
      userId,
      productId,
    );
    const conversation = await this.getOrCreateDirectConversation(
      userId,
      sellerUserId,
    );

    return this.sendMediaMessage(userId, conversation.id, dto);
  }

  async sendMessageForUser(
    userId: string,
    targetUserId: string,
    dto: CreateMessageDto,
  ) {
    const conversation = await this.getOrCreateConversationForUser(
      userId,
      targetUserId,
    );

    return this.sendMessage(
      userId,
      conversation.id,
      dto,
      this.extractDtoProductSnapshot(dto),
    );
  }

  async sendMediaMessageForUser(
    userId: string,
    targetUserId: string,
    dto: CreateMediaMessageDto,
  ) {
    const conversation = await this.getOrCreateConversationForUser(
      userId,
      targetUserId,
    );

    return this.sendMediaMessage(userId, conversation.id, dto);
  }

  async sendMessage(
    userId: string,
    conversationId: string,
    dto: CreateMessageDto,
    productSnapshot?: ConversationMessageProductSnapshot | null,
  ) {
    const content = dto.content.trim();

    if (!content) {
      throw new BadRequestException("Message content is required");
    }

    const conversation = await this.findAccessibleConversation(
      userId,
      conversationId,
    );
    const recipientUserId =
      conversation.buyerUserId === userId
        ? conversation.sellerUserId
        : conversation.buyerUserId;
    const sender =
      conversation.buyerUserId === userId
        ? conversation.buyer
        : conversation.seller;
    const recipient =
      conversation.buyerUserId === userId
        ? conversation.seller
        : conversation.buyer;

    await this.assertUsersCanInteract(userId, recipientUserId);

    const effectiveProductSnapshot =
      this.extractDtoProductSnapshot(dto) ?? productSnapshot;
    const normalizedClientMessageId = dto.clientMessageId?.trim() || undefined;

    let createdMessage: ConversationMessageDetail | null = null;
    let createdMessageId: string | null = null;
    await this.prisma.$transaction(async (transaction) => {
      createdMessage =
        normalizedClientMessageId == null
          ? await transaction.chatMessage.create({
              data: {
                conversationId: conversation.id,
                senderUserId: userId,
                content,
                replyToMessageId: dto.replyToMessageId?.trim() || undefined,
                replyToSenderUserId:
                  dto.replyToSenderUserId?.trim() || undefined,
                replyToSenderName: dto.replyToSenderName?.trim() || undefined,
                replyToContent: dto.replyToContent?.trim() || undefined,
                productId: effectiveProductSnapshot?.id ?? undefined,
                productTitle: effectiveProductSnapshot?.title || undefined,
                productSubtitle:
                  effectiveProductSnapshot?.subtitle || undefined,
                productPriceLabel:
                  effectiveProductSnapshot?.priceLabel || undefined,
                productImageUrl:
                  effectiveProductSnapshot?.imageUrl || undefined,
              },
              include: conversationMessageInclude,
            })
          : await transaction.chatMessage.upsert({
              where: {
                senderUserId_clientMessageId: {
                  senderUserId: userId,
                  clientMessageId: normalizedClientMessageId,
                },
              },
              update: {},
              create: {
                conversationId: conversation.id,
                senderUserId: userId,
                clientMessageId: normalizedClientMessageId,
                content,
                replyToMessageId: dto.replyToMessageId?.trim() || undefined,
                replyToSenderUserId:
                  dto.replyToSenderUserId?.trim() || undefined,
                replyToSenderName: dto.replyToSenderName?.trim() || undefined,
                replyToContent: dto.replyToContent?.trim() || undefined,
                productId: effectiveProductSnapshot?.id ?? undefined,
                productTitle: effectiveProductSnapshot?.title || undefined,
                productSubtitle:
                  effectiveProductSnapshot?.subtitle || undefined,
                productPriceLabel:
                  effectiveProductSnapshot?.priceLabel || undefined,
                productImageUrl:
                  effectiveProductSnapshot?.imageUrl || undefined,
              },
              include: conversationMessageInclude,
            });
      createdMessageId = createdMessage.id;

      await transaction.chatConversation.update({
        where: { id: conversation.id },
        data: {
          lastMessageAt: new Date(),
        },
      });
    });

    this.conversationsRealtimeGateway.emitConversationEvent(
      [conversation.buyerUserId, conversation.sellerUserId],
      {
        type: "message:new",
        conversationId: conversation.id,
        actorUserId: userId,
        message: createdMessage
          ? this.presentRealtimeMessage(createdMessage)
          : null,
      },
    );

    const recipientConnected =
      this.conversationsRealtimeGateway.isUserConnected(recipientUserId);
    const notificationDelivered =
      await this.pushNotificationsService.sendChatMessageNotification({
        recipientUserId,
        conversationId: conversation.id,
        senderDisplayName: sender.displayName,
        senderAvatarUrl: sender.avatarUrl ?? undefined,
        senderRoleLabel: this.resolveRoleLabel(sender),
        recipientDisplayName: recipient.displayName,
        content,
        conversationKind: conversation.kind,
        productId: conversation.productId ?? undefined,
      });

    this.logger.debug(
      `[DELIVERY CHECK] recipientId=${recipientUserId} | ` +
        `connected=${recipientConnected} | ` +
        `pushSent=${notificationDelivered} | ` +
        `willDeliver=${recipientConnected}`,
    );

    // Marquer comme distribué uniquement si le destinataire est connecté
    // Les messages hors-ligne seront marqués distribués par emitPendingMessageDeliveries lors de la reconnexion
    if (createdMessageId && recipientConnected) {
      const deliveredAt = new Date();
      await this.prisma.chatMessage.update({
        where: { id: createdMessageId },
        data: { deliveredAt },
      });
      this.emitConversationDelivered(
        conversation,
        recipientUserId,
        createdMessageId,
        deliveredAt,
      );
    }

    return this.getConversation(userId, conversationId);
  }

  async sendMediaMessage(
    userId: string,
    conversationId: string,
    dto: CreateMediaMessageDto,
  ) {
    const mediaPayload = this.extractMediaPayload(dto);
    const content =
      (dto.content?.trim() ?? "").length > 0
        ? dto.content!.trim()
        : dto.kind === "IMAGE"
          ? "Photo envoyee"
          : "Document envoye";

    const conversation = await this.findAccessibleConversation(
      userId,
      conversationId,
    );
    const recipientUserId =
      conversation.buyerUserId === userId
        ? conversation.sellerUserId
        : conversation.buyerUserId;
    const sender =
      conversation.buyerUserId === userId
        ? conversation.buyer
        : conversation.seller;
    const recipient =
      conversation.buyerUserId === userId
        ? conversation.seller
        : conversation.buyer;

    await this.assertUsersCanInteract(userId, recipientUserId);
    const normalizedClientMessageId = dto.clientMessageId?.trim() || undefined;

    let createdMessage: ConversationMessageDetail | null = null;
    let createdMessageId: string | null = null;
    await this.prisma.$transaction(async (transaction) => {
      createdMessage =
        normalizedClientMessageId == null
          ? await transaction.chatMessage.create({
              data: {
                conversationId: conversation.id,
                senderUserId: userId,
                content,
                kind: dto.kind,
                replyToMessageId: dto.replyToMessageId?.trim() || undefined,
                replyToSenderUserId:
                  dto.replyToSenderUserId?.trim() || undefined,
                replyToSenderName: dto.replyToSenderName?.trim() || undefined,
                replyToContent: dto.replyToContent?.trim() || undefined,
                media: {
                  create: {
                    mediaType: mediaPayload.mediaType,
                    mimeType: mediaPayload.mimeType ?? undefined,
                    fileName: mediaPayload.fileName ?? undefined,
                    fileSizeBytes: mediaPayload.fileSizeBytes ?? undefined,
                    storageProvider: mediaPayload.storageProvider,
                    storageKey: mediaPayload.storageKey ?? undefined,
                    publicUrl: mediaPayload.publicUrl,
                    previewUrl: mediaPayload.previewUrl ?? undefined,
                    thumbnailUrl: mediaPayload.thumbnailUrl ?? undefined,
                    width: mediaPayload.width ?? undefined,
                    height: mediaPayload.height ?? undefined,
                    encryptionScheme:
                      mediaPayload.encryptionScheme ?? undefined,
                    encryptionKeyB64:
                      mediaPayload.encryptionKeyB64 ?? undefined,
                    encryptionIvB64: mediaPayload.encryptionIvB64 ?? undefined,
                    fileSha256B64: mediaPayload.fileSha256B64 ?? undefined,
                    mediaGroupId: mediaPayload.mediaGroupId ?? undefined,
                  },
                },
              },
              include: conversationMessageInclude,
            })
          : await transaction.chatMessage.upsert({
              where: {
                senderUserId_clientMessageId: {
                  senderUserId: userId,
                  clientMessageId: normalizedClientMessageId,
                },
              },
              update: {},
              create: {
                conversationId: conversation.id,
                senderUserId: userId,
                clientMessageId: normalizedClientMessageId,
                content,
                kind: dto.kind,
                replyToMessageId: dto.replyToMessageId?.trim() || undefined,
                replyToSenderUserId:
                  dto.replyToSenderUserId?.trim() || undefined,
                replyToSenderName: dto.replyToSenderName?.trim() || undefined,
                replyToContent: dto.replyToContent?.trim() || undefined,
                media: {
                  create: {
                    mediaType: mediaPayload.mediaType,
                    mimeType: mediaPayload.mimeType ?? undefined,
                    fileName: mediaPayload.fileName ?? undefined,
                    fileSizeBytes: mediaPayload.fileSizeBytes ?? undefined,
                    storageProvider: mediaPayload.storageProvider,
                    storageKey: mediaPayload.storageKey ?? undefined,
                    publicUrl: mediaPayload.publicUrl,
                    previewUrl: mediaPayload.previewUrl ?? undefined,
                    thumbnailUrl: mediaPayload.thumbnailUrl ?? undefined,
                    width: mediaPayload.width ?? undefined,
                    height: mediaPayload.height ?? undefined,
                    encryptionScheme:
                      mediaPayload.encryptionScheme ?? undefined,
                    encryptionKeyB64:
                      mediaPayload.encryptionKeyB64 ?? undefined,
                    encryptionIvB64: mediaPayload.encryptionIvB64 ?? undefined,
                    fileSha256B64: mediaPayload.fileSha256B64 ?? undefined,
                    mediaGroupId: mediaPayload.mediaGroupId ?? undefined,
                  },
                },
              },
              include: conversationMessageInclude,
            });
      createdMessageId = createdMessage.id;

      await transaction.chatConversation.update({
        where: { id: conversation.id },
        data: {
          lastMessageAt: new Date(),
        },
      });
    });

    this.conversationsRealtimeGateway.emitConversationEvent(
      [conversation.buyerUserId, conversation.sellerUserId],
      {
        type: "message:new",
        conversationId: conversation.id,
        actorUserId: userId,
        message: createdMessage
          ? this.presentRealtimeMessage(createdMessage)
          : null,
      },
    );

    const recipientConnected =
      this.conversationsRealtimeGateway.isUserConnected(recipientUserId);
    const notificationDelivered =
      await this.pushNotificationsService.sendChatMessageNotification({
        recipientUserId,
        conversationId: conversation.id,
        senderDisplayName: sender.displayName,
        senderAvatarUrl: sender.avatarUrl ?? undefined,
        senderRoleLabel: this.resolveRoleLabel(sender),
        recipientDisplayName: recipient.displayName,
        content,
        conversationKind: conversation.kind,
        productId: conversation.productId ?? undefined,
      });

    this.logger.debug(
      `[DELIVERY CHECK] recipientId=${recipientUserId} | ` +
        `connected=${recipientConnected} | ` +
        `pushSent=${notificationDelivered} | ` +
        `willDeliver=${recipientConnected}`,
    );

    // Marquer comme distribué uniquement si le destinataire est connecté
    // Les messages hors-ligne seront marqués distribués par emitPendingMessageDeliveries lors de la reconnexion
    if (createdMessageId && recipientConnected) {
      const deliveredAt = new Date();
      await this.prisma.chatMessage.update({
        where: { id: createdMessageId },
        data: { deliveredAt },
      });
      this.emitConversationDelivered(
        conversation,
        recipientUserId,
        createdMessageId,
        deliveredAt,
      );
    }

    return this.getConversation(userId, conversationId);
  }

  /**
   * Lets a device that has no live socket (app backgrounded/terminated but
   * reachable via a push notification) still flip its pending messages to
   * "delivered", instead of requiring the recipient to bring the app to
   * the foreground. See ConversationsController#acknowledgeDeliveryPing.
   */
  async acknowledgeDeliveryPing(userId: string) {
    await this.conversationsRealtimeGateway.emitPendingMessageDeliveries(
      userId,
    );
    return { acknowledged: true };
  }

  private extractDtoProductSnapshot(dto: CreateMessageDto) {
    const hasProductSnapshot =
      (dto.productId?.trim().length ?? 0) > 0 ||
      (dto.productTitle?.trim().length ?? 0) > 0 ||
      (dto.productSubtitle?.trim().length ?? 0) > 0 ||
      (dto.productPriceLabel?.trim().length ?? 0) > 0 ||
      (dto.productImageUrl?.trim().length ?? 0) > 0;

    if (!hasProductSnapshot) {
      return undefined;
    }

    return {
      id: dto.productId?.trim() || null,
      title: dto.productTitle?.trim() ?? "",
      subtitle: dto.productSubtitle?.trim() ?? "",
      priceLabel: dto.productPriceLabel?.trim() ?? "",
      imageUrl: dto.productImageUrl?.trim() ?? "",
    };
  }

  private isUserOnline(participant: { id: string; lastSeenAt?: Date | null }) {
    return this.conversationsRealtimeGateway.isUserConnected(participant.id);
  }

  private async findAccessibleConversation(
    userId: string,
    conversationId: string,
  ) {
    const conversation = await this.prisma.chatConversation.findUnique({
      where: { id: conversationId },
      include: conversationDetailInclude,
    });

    if (!conversation) {
      throw new NotFoundException("Conversation not found");
    }

    if (
      conversation.buyerUserId !== userId &&
      conversation.sellerUserId !== userId
    ) {
      throw new ForbiddenException(
        "You do not have access to this conversation",
      );
    }

    return conversation;
  }

  private async markConversationAsRead(conversationId: string, userId: string) {
    // Captured before the query runs so a message inserted by the other
    // party concurrently (e.g. sent the instant this read ack fires) has a
    // createdAt strictly after readBoundary and is excluded — otherwise it
    // could be swept into "read" despite not having existed yet when this
    // read action happened.
    const readBoundary = new Date();
    const result = await this.prisma.chatMessage.updateMany({
      where: {
        conversationId,
        senderUserId: {
          not: userId,
        },
        readAt: null,
        createdAt: {
          lte: readBoundary,
        },
      },
      data: {
        readAt: readBoundary,
      },
    });

    return result.count;
  }

  private emitConversationRead(
    conversation: { id: string; buyerUserId: string; sellerUserId: string },
    userId: string,
  ) {
    this.conversationsRealtimeGateway.emitConversationEvent(
      [conversation.buyerUserId, conversation.sellerUserId],
      {
        type: "conversation:read",
        conversationId: conversation.id,
        actorUserId: userId,
        readAt: new Date().toISOString(),
      },
    );
  }

  private emitConversationDelivered(
    conversation: { id: string; buyerUserId: string; sellerUserId: string },
    recipientUserId: string,
    messageId: string,
    deliveredAt: Date,
  ) {
    const senderUserId =
      conversation.buyerUserId === recipientUserId
        ? conversation.sellerUserId
        : conversation.buyerUserId;
    this.conversationsRealtimeGateway.emitConversationDeliveredEvent(
      senderUserId,
      {
        type: "conversation:delivered",
        conversationId: conversation.id,
        actorUserId: recipientUserId,
        messageId,
        deliveredAt: deliveredAt.toISOString(),
      },
    );
  }

  private presentRealtimeMessage(
    message: ConversationMessageDetail,
  ): ConversationRealtimeMessage {
    return {
      id: message.id,
      clientMessageId: message.clientMessageId,
      content: message.content,
      kind: message.kind,
      acceptedAt: message.acceptedAt?.toISOString() ?? null,
      createdAt: message.createdAt.toISOString(),
      deliveredAt: message.deliveredAt?.toISOString() ?? null,
      readAt: message.readAt?.toISOString() ?? null,
      reply: this.presentRealtimeMessageReply(message),
      sender: {
        id: message.sender.id,
        displayName: message.sender.displayName,
        avatarUrl: message.sender.avatarUrl,
      },
      media: this.presentMessageMedia(message),
      product: this.presentMessageProductSnapshot(message),
    };
  }

  private async presentConversationListItem(
    conversation: ConversationListItem,
    userId: string,
    unreadCount: number,
  ) {
    const isBuyer = conversation.buyerUserId === userId;
    const participant = isBuyer ? conversation.seller : conversation.buyer;
    const lastMessage = conversation.messages[0] ?? null;
    const blockState = await this.presentConversationBlockState(
      userId,
      participant.id,
    );

    return {
      id: conversation.id,
      participant: {
        id: participant.id,
        displayName: participant.displayName,
        avatarUrl: participant.avatarUrl,
        roleLabel: this.resolveRoleLabel(participant),
        isOnline: this.isUserOnline(participant),
        lastSeenAt: participant.lastSeenAt?.toISOString() ?? null,
      },
      product: conversation.product
        ? {
            id: conversation.product.id,
            title: conversation.product.title,
            imageUrl: conversation.product.imageUrl,
            category: conversation.product.category.name,
            price: conversation.product.priceAmount.toNumber(),
            currency: conversation.product.currencyCode,
          }
        : null,
      lastMessage: lastMessage
        ? {
            id: lastMessage.id,
            content: lastMessage.content,
            createdAt: lastMessage.createdAt.toISOString(),
            isMine: lastMessage.senderUserId === userId,
            kind: lastMessage.kind,
            deliveredAt: lastMessage.deliveredAt?.toISOString() ?? null,
            readAt: lastMessage.readAt?.toISOString() ?? null,
          }
        : null,
      unreadCount,
      kind: conversation.kind,
      lastMessageAt: conversation.lastMessageAt.toISOString(),
      ...blockState,
    };
  }

  private normalizeMessagesPageLimit(limit?: number) {
    if (!Number.isFinite(limit)) {
      return DEFAULT_MESSAGES_PAGE_SIZE;
    }

    return Math.min(
      Math.max(Math.trunc(limit ?? DEFAULT_MESSAGES_PAGE_SIZE), 1),
      MAX_MESSAGES_PAGE_SIZE,
    );
  }

  private async resolveBeforeMessageCursor(
    beforeMessageId: string | undefined,
    matcher?: (message: {
      id: string;
      conversationId: string;
      senderUserId: string;
    }) => boolean,
  ) {
    const normalizedBeforeMessageId = beforeMessageId?.trim() ?? "";
    if (normalizedBeforeMessageId.length === 0) {
      return null;
    }

    const anchorMessage = await this.prisma.chatMessage.findUnique({
      where: { id: normalizedBeforeMessageId },
      select: {
        id: true,
        conversationId: true,
        senderUserId: true,
        createdAt: true,
      },
    });

    if (!anchorMessage || (matcher != null && !matcher(anchorMessage))) {
      return null;
    }

    return anchorMessage;
  }

  private buildBeforeMessageWhere(
    cursor: { id: string; createdAt: Date } | null,
  ) {
    if (cursor == null) {
      return undefined;
    }

    return {
      OR: [
        {
          createdAt: {
            lt: cursor.createdAt,
          },
        },
        {
          createdAt: cursor.createdAt,
          id: {
            lt: cursor.id,
          },
        },
      ],
    } satisfies Prisma.ChatMessageWhereInput;
  }

  private async loadConversationMessagesPage(
    conversationId: string,
    pageOptions?: ConversationMessagesPageOptions,
    requestingUserId?: string,
  ): Promise<ConversationMessagesPage> {
    const take = this.normalizeMessagesPageLimit(pageOptions?.limit);
    const cursor = await this.resolveBeforeMessageCursor(
      pageOptions?.beforeMessageId,
      (message) => message.conversationId === conversationId,
    );
    const beforeWhere = this.buildBeforeMessageWhere(cursor);
    const deletedForMeFilter = this.buildDeletedForMeFilter(requestingUserId);
    const records = await this.prisma.chatMessage.findMany({
      where: {
        conversationId,
        ...(deletedForMeFilter == null ? {} : deletedForMeFilter),
        ...(beforeWhere == null ? {} : beforeWhere),
      },
      include: conversationMessageInclude,
      orderBy: [{ createdAt: "desc" }, { id: "desc" }],
      take: take + 1,
    });
    const hasOlderMessages = records.length > take;
    const pageRecords = (hasOlderMessages ? records.slice(0, take) : records)
      .slice()
      .reverse();

    return {
      messages: pageRecords,
      limit: take,
      hasOlderMessages,
      oldestLoadedMessageId: pageRecords[0]?.id ?? null,
    };
  }

  private async presentConversationDetail(
    conversation: ConversationDetail,
    userId: string,
    pageOptions?: ConversationMessagesPageOptions,
  ) {
    const isBuyer = conversation.buyerUserId === userId;
    const participant = isBuyer ? conversation.seller : conversation.buyer;
    const blockState = await this.presentConversationBlockState(
      userId,
      participant.id,
    );
    const page = await this.loadConversationMessagesPage(
      conversation.id,
      pageOptions,
      userId,
    );
    const currentProductSnapshots = await this.buildCurrentProductSnapshotMap(
      page.messages,
    );

    return {
      id: conversation.id,
      participant: {
        id: participant.id,
        displayName: participant.displayName,
        avatarUrl: participant.avatarUrl,
        roleLabel: this.resolveRoleLabel(participant),
        isOnline: this.isUserOnline(participant),
        lastSeenAt: participant.lastSeenAt?.toISOString() ?? null,
      },
      product: conversation.product
        ? {
            id: conversation.product.id,
            title: conversation.product.title,
            description: conversation.product.description,
            subtitle: `${conversation.product.category.name} • ${conversation.product.isAvailable ? "Disponible" : "Indisponible"}`,
            imageUrl: conversation.product.imageUrl,
            price: conversation.product.priceAmount.toNumber(),
            currency: conversation.product.currencyCode,
          }
        : null,
      messages: page.messages.map((message) => ({
        id: message.id,
        clientMessageId: message.clientMessageId,
        content: message.content,
        kind: message.kind,
        acceptedAt: message.acceptedAt?.toISOString() ?? null,
        createdAt: message.createdAt.toISOString(),
        deliveredAt: message.deliveredAt?.toISOString() ?? null,
        readAt: message.readAt?.toISOString() ?? null,
        isMine: message.senderUserId === userId,
        reply: this.presentMessageReply(message, userId),
        sender: {
          id: message.sender.id,
          displayName: message.sender.displayName,
          avatarUrl: message.sender.avatarUrl,
        },
        media: this.presentMessageMedia(message),
        product: this.presentMessageProductSnapshot(
          message,
          currentProductSnapshots,
        ),
      })),
      kind: conversation.kind,
      createdAt: conversation.createdAt.toISOString(),
      lastMessageAt: conversation.lastMessageAt.toISOString(),
      pagination: {
        limit: page.limit,
        hasOlderMessages: page.hasOlderMessages,
        oldestLoadedMessageId: page.oldestLoadedMessageId,
      },
      ...blockState,
    };
  }

  private buildDeletedForMeFilter(requestingUserId?: string) {
    if (!requestingUserId) {
      return null;
    }

    return {
      NOT: {
        OR: [
          {
            conversation: { buyerUserId: requestingUserId },
            deletedForBuyerAt: { not: null },
          },
          {
            conversation: { sellerUserId: requestingUserId },
            deletedForSellerAt: { not: null },
          },
        ],
      },
    } satisfies Prisma.ChatMessageWhereInput;
  }

  private async buildCurrentProductSnapshotMap(
    messages: MessageProductSnapshotFields[],
  ) {
    const productIds = Array.from(
      new Set(
        messages
          .map((message) => message.productId?.trim() ?? "")
          .filter((productId) => productId.length > 0),
      ),
    );

    if (productIds.length === 0) {
      return new Map<string, ConversationMessageProductSnapshot>();
    }

    const products = await this.prisma.product.findMany({
      where: {
        id: {
          in: productIds,
        },
      },
      include: {
        category: true,
      },
    });

    return new Map<string, ConversationMessageProductSnapshot>(
      products.map((product) => [
        product.id,
        {
          id: product.id,
          title: product.title,
          subtitle: `${product.category.name} • ${product.isAvailable ? "Disponible" : "Indisponible"}`,
          priceLabel: `${product.priceAmount.toNumber()} ${product.currencyCode}`,
          imageUrl: product.imageUrl,
        },
      ]),
    );
  }

  private presentMessageProductSnapshot(
    message: MessageProductSnapshotFields,
    currentProductSnapshots?: Map<string, ConversationMessageProductSnapshot>,
  ) {
    if (message.kind === "IMAGE" || message.kind === "DOCUMENT") {
      return null;
    }

    const currentProductId = message.productId?.trim() ?? "";
    if (
      currentProductId.length > 0 &&
      currentProductSnapshots?.has(currentProductId) === true
    ) {
      return currentProductSnapshots!.get(currentProductId)!;
    }

    const title = message.productTitle?.trim() ?? "";
    const subtitle = message.productSubtitle?.trim() ?? "";
    const priceLabel = message.productPriceLabel?.trim() ?? "";
    const imageUrl = message.productImageUrl?.trim() ?? "";

    if (
      title.length === 0 &&
      subtitle.length === 0 &&
      priceLabel.length === 0 &&
      imageUrl.length === 0 &&
      (message.productId == null || message.productId.trim().length === 0)
    ) {
      return null;
    }

    return {
      id: message.productId,
      title,
      subtitle,
      priceLabel,
      imageUrl,
    };
  }

  private presentMessageMedia(message: MessageProductSnapshotFields) {
    if (!message.media) {
      return null;
    }

    const mediaType = message.media.mediaType.trim().toLowerCase();
    if (mediaType !== "image" && mediaType !== "document") {
      return null;
    }

    return {
      mediaType,
      publicUrl: message.media.publicUrl,
      previewUrl: message.media.previewUrl,
      thumbnailUrl: message.media.thumbnailUrl,
      fileName: message.media.fileName,
      mimeType: message.media.mimeType,
      fileSizeBytes: message.media.fileSizeBytes,
      storageProvider: message.media.storageProvider,
      storageKey: message.media.storageKey,
      mediaGroupId: message.media.mediaGroupId,
      width: message.media.width,
      height: message.media.height,
      encryptionScheme: message.media.encryptionScheme,
      encryptionKeyB64: message.media.encryptionKeyB64,
      encryptionIvB64: message.media.encryptionIvB64,
      fileSha256B64: message.media.fileSha256B64,
    } satisfies ConversationMessageMediaPayload;
  }

  private extractMediaPayload(dto: CreateMediaMessageDto) {
    const normalizedStorageProvider =
      dto.storageProvider?.trim() || "cloudinary";
    const normalizedStorageKey = dto.storageKey?.trim() || null;
    const normalizedPublicUrl = dto.publicUrl.trim();
    const imageVariants =
      dto.mediaType === "image" &&
      normalizedStorageProvider.toLowerCase() == "cloudinary"
        ? this.cloudinaryService.buildChatImageVariants({
            publicId: normalizedStorageKey,
            publicUrl: normalizedPublicUrl,
          })
        : { previewUrl: null, thumbnailUrl: null };

    return {
      mediaType: dto.mediaType,
      publicUrl: normalizedPublicUrl,
      previewUrl: dto.previewUrl?.trim() || imageVariants.previewUrl || null,
      thumbnailUrl:
        dto.thumbnailUrl?.trim() || imageVariants.thumbnailUrl || null,
      fileName: dto.fileName?.trim() || null,
      mimeType: dto.mimeType?.trim() || null,
      fileSizeBytes: dto.fileSizeBytes ?? null,
      storageProvider: normalizedStorageProvider,
      storageKey: normalizedStorageKey,
      mediaGroupId: dto.mediaGroupId?.trim() || null,
      width: dto.width ?? null,
      height: dto.height ?? null,
      encryptionScheme: dto.encryptionScheme?.trim() || null,
      encryptionKeyB64: dto.encryptionKeyB64?.trim() || null,
      encryptionIvB64: dto.encryptionIvB64?.trim() || null,
      fileSha256B64: dto.fileSha256B64?.trim() || null,
    } satisfies ConversationMessageMediaPayload;
  }

  private presentMessageReply(
    message: MessageReplyFields,
    currentUserId: string,
  ) {
    const content = message.replyToContent?.trim() ?? "";

    if (content.length === 0) {
      return null;
    }

    return {
      messageId: message.replyToMessageId ?? null,
      senderLabel:
        message.replyToSenderUserId != null &&
        message.replyToSenderUserId === currentUserId
          ? "Vous"
          : (message.replyToSenderName?.trim().length ?? 0) > 0
            ? message.replyToSenderName!.trim()
            : "Message",
      content,
    };
  }

  private presentRealtimeMessageReply(message: MessageReplyFields) {
    const content = message.replyToContent?.trim() ?? "";

    if (content.length === 0) {
      return null;
    }

    return {
      messageId: message.replyToMessageId ?? null,
      senderLabel:
        (message.replyToSenderName?.trim().length ?? 0) > 0
          ? message.replyToSenderName!.trim()
          : "Message",
      content,
    };
  }
}
