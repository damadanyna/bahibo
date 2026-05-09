import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { PushNotificationsService } from '../push-notifications/push-notifications.service';
import { CloudinaryService } from '../auth/cloudinary.service';
import { CreateMediaMessageDto } from './dto/create-media-message.dto';
import { CreateMessageDto } from './dto/create-message.dto';
import { ConversationsRealtimeGateway } from './realtime/conversations-realtime.gateway';

const conversationDetailInclude = Prisma.validator<Prisma.ChatConversationInclude>()({
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
      createdAt: 'asc',
    },
  },
});

type ConversationDetail = Prisma.ChatConversationGetPayload<{
  include: typeof conversationDetailInclude;
}>;

const conversationListInclude = Prisma.validator<Prisma.ChatConversationInclude>()({
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
      createdAt: 'desc',
    },
    take: 1,
  },
});

type ConversationListItem = Prisma.ChatConversationGetPayload<{
  include: typeof conversationListInclude;
}>;

type ConversationThreadMessage = {
  id: string;
  content: string;
  kind: 'TEXT' | 'IMAGE' | 'DOCUMENT' | 'PRODUCT';
  createdAt: string;
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

type ConversationMessageMediaPayload = {
  mediaType: 'image' | 'document';
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
  kind?: 'TEXT' | 'IMAGE' | 'DOCUMENT' | 'PRODUCT';
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

const PRESENCE_RECENT_ACTIVITY_WINDOW_MS = 90 * 1000;

type MessageReplyFields = {
  replyToMessageId?: string | null;
  replyToSenderUserId?: string | null;
  replyToSenderName?: string | null;
  replyToContent?: string | null;
};

const maxPhotoAttachmentBytes = 10 * 1024 * 1024;
const maxDocumentAttachmentBytes = 12 * 1024 * 1024;
const allowedPhotoAttachmentExtensions = new Set([
  'jpg',
  'jpeg',
  'png',
  'webp',
  'heic',
  'heif',
]);
const allowedDocumentAttachmentExtensions = new Set([
  'pdf',
  'doc',
  'docx',
  'txt',
]);

@Injectable()
export class ConversationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly pushNotificationsService: PushNotificationsService,
    private readonly conversationsRealtimeGateway: ConversationsRealtimeGateway,
    private readonly cloudinaryService: CloudinaryService,
  ) {}

  async uploadAttachment(
    userId: string,
    file: Express.Multer.File | undefined,
    type: 'photo' | 'document',
  ) {
    if (!file) {
      throw new BadRequestException('Attachment file is required');
    }

    this.validateAttachment(file, type);

    if (type === 'photo') {
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

  private validateAttachment(
    file: Express.Multer.File,
    type: 'photo' | 'document',
  ) {
    const fileName = file.originalname?.trim() ?? '';
    const extension = this.extractFileExtension(fileName);
    const fileSize = file.size ?? file.buffer?.length ?? 0;

    if (type === 'photo') {
      if (!allowedPhotoAttachmentExtensions.has(extension)) {
        throw new BadRequestException(
          'Format de photo non pris en charge. Utilisez JPG, PNG, WEBP ou HEIC.',
        );
      }
      const mimeType = file.mimetype?.trim().toLowerCase() ?? '';
      if (mimeType.length > 0 && !mimeType.startsWith('image/')) {
        throw new BadRequestException('Le fichier envoye n\'est pas une image valide.');
      }
      if (fileSize > maxPhotoAttachmentBytes) {
        throw new BadRequestException('La photo depasse la limite de 10 Mo.');
      }
      return;
    }

    if (!allowedDocumentAttachmentExtensions.has(extension)) {
      throw new BadRequestException(
        'Format de document non pris en charge. Utilisez PDF, DOC, DOCX ou TXT.',
      );
    }
    if (fileSize > maxDocumentAttachmentBytes) {
      throw new BadRequestException('Le document depasse la limite de 12 Mo.');
    }
  }

  private extractFileExtension(fileName: string) {
    const lastDot = fileName.lastIndexOf('.');
    if (lastDot < 0 || lastDot === fileName.length - 1) {
      return '';
    }

    return fileName.slice(lastDot + 1).toLowerCase();
  }

  private buildDirectConversationKey(firstUserId: string, secondUserId: string) {
    return [firstUserId, secondUserId].sort().join(':');
  }

  private resolveRoleLabel(user: { role: string }) {
    if (user.role === 'SELLER') {
      return 'Vendeur';
    }
    if (user.role === 'ADMIN') {
      return 'Administrateur';
    }
    return 'Utilisateur';
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
        createdAt: 'desc',
      },
    });
  }

  private async presentConversationBlockState(
    firstUserId: string,
    secondUserId: string,
  ) {
    const userBlock = await this.findUserBlock(
      firstUserId,
      secondUserId,
    );

    return {
      isBlocked: userBlock != null,
      blockedParticipantUserId: userBlock == null ? null : secondUserId,
      blockedMessage:
        userBlock == null
          ? null
          : 'Cette conversation est bloquee. Vous pouvez lire l\'historique, mais vous ne pouvez plus envoyer de nouveaux messages.',
    };
  }

  private async assertUsersCanInteract(firstUserId: string, secondUserId: string) {
    const userBlock = await this.findUserBlock(firstUserId, secondUserId);

    if (userBlock != null) {
      throw new ForbiddenException(
        'Cette conversation est bloquee. Vous ne pouvez plus envoyer de messages.',
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
        lastMessageAt: 'desc',
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

  async getOrCreateConversationForProduct(userId: string, productId: string) {
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
      throw new NotFoundException('Product not found');
    }

    const sellerUserId = product.sellerProfile.userId;

    if (sellerUserId === userId) {
      throw new BadRequestException(
        'You cannot start a conversation with your own product',
      );
    }

    const existingConversation = await this.prisma.chatConversation.findUnique({
      where: {
        buyerUserId_sellerUserId_productId: {
          buyerUserId: userId,
          sellerUserId,
          productId,
        },
      },
      include: conversationDetailInclude,
    });

    if (existingConversation) {
      const readCount = await this.markConversationAsRead(existingConversation.id, userId);
      if (readCount > 0) {
        this.emitConversationRead(existingConversation, userId);
      }
      return this.presentConversationDetail(existingConversation, userId);
    }

    await this.assertUsersCanInteract(userId, sellerUserId);

    const conversation = await this.prisma.chatConversation.create({
      data: {
        buyerUserId: userId,
        sellerUserId,
        productId,
        kind: 'PRODUCT',
      },
      include: conversationDetailInclude,
    });

    return this.presentConversationDetail(conversation, userId);
  }

  async getOrCreateConversationForUser(userId: string, targetUserId: string) {
    if (!targetUserId.trim()) {
      throw new BadRequestException('Target user is required');
    }

    if (targetUserId === userId) {
      throw new BadRequestException(
        'You cannot start a conversation with yourself',
      );
    }

    const targetUser = await this.prisma.user.findUnique({
      where: { id: targetUserId },
    });

    if (!targetUser) {
      throw new NotFoundException('User not found');
    }

    const directKey = this.buildDirectConversationKey(userId, targetUserId);

    const directConversation = await this.prisma.chatConversation.findFirst({
      where: { directKey },
      include: conversationDetailInclude,
    });

    const conversations = await this.prisma.chatConversation.findMany({
      where: {
        OR: [
          {
            buyerUserId: userId,
            sellerUserId: targetUserId,
          },
          {
            buyerUserId: targetUserId,
            sellerUserId: userId,
          },
        ],
      },
      include: conversationDetailInclude,
      orderBy: {
        lastMessageAt: 'asc',
      },
    });

    if (conversations.length > 0) {
      const readCounts = await Promise.all(
        conversations.map((conversation) =>
          this.markConversationAsRead(conversation.id, userId),
        ),
      );

      for (var index = 0; index < conversations.length; index += 1) {
        if (readCounts[index] > 0) {
          this.emitConversationRead(conversations[index], userId);
        }
      }

      return this.presentConversationThreadDetail(
        directConversation ?? conversations[conversations.length - 1],
        conversations,
        userId,
      );
    }

    await this.assertUsersCanInteract(userId, targetUserId);

    const createdConversation = await this.prisma.chatConversation.create({
      data: {
        buyerUserId: userId,
        sellerUserId: targetUserId,
        kind: 'DIRECT',
        directKey,
      },
      include: conversationDetailInclude,
    });

    return this.presentConversationThreadDetail(
      createdConversation,
      [createdConversation],
      userId,
    );
  }

  async getConversation(userId: string, conversationId: string) {
    const conversation = await this.findAccessibleConversation(
      userId,
      conversationId,
    );
    const readCount = await this.markConversationAsRead(conversation.id, userId);
    if (readCount > 0) {
      this.emitConversationRead(conversation, userId);
    }
    return this.presentConversationDetail(conversation, userId);
  }

  async sendMessageForProduct(
    userId: string,
    productId: string,
    dto: CreateMessageDto,
  ) {
    const conversation = await this.getOrCreateConversationForProduct(
      userId,
      productId,
    );

    return this.sendMessage(
      userId,
      conversation.id,
      dto,
      this.extractDtoProductSnapshot(dto) ?? {
        id: conversation.product?.id ?? null,
        title: conversation.product?.title ?? '',
        subtitle: conversation.product?.subtitle ?? '',
        priceLabel: conversation.product
          ? `${conversation.product.price} ${conversation.product.currency}`
          : '',
        imageUrl: conversation.product?.imageUrl ?? '',
      },
    );
  }

  async sendMediaMessageForProduct(
    userId: string,
    productId: string,
    dto: CreateMediaMessageDto,
  ) {
    const conversation = await this.getOrCreateConversationForProduct(
      userId,
      productId,
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
      throw new BadRequestException('Message content is required');
    }

    const conversation = await this.findAccessibleConversation(
      userId,
      conversationId,
    );
    const recipientUserId = conversation.buyerUserId === userId
      ? conversation.sellerUserId
      : conversation.buyerUserId;
    const sender = conversation.buyerUserId === userId
      ? conversation.buyer
      : conversation.seller;
    const recipient = conversation.buyerUserId === userId
      ? conversation.seller
      : conversation.buyer;

    await this.assertUsersCanInteract(userId, recipientUserId);

    const effectiveProductSnapshot =
      this.extractDtoProductSnapshot(dto) ?? productSnapshot;

    await this.prisma.$transaction(async (transaction) => {
      await transaction.chatMessage.create({
        data: {
          conversationId: conversation.id,
          senderUserId: userId,
          content,
          replyToMessageId: dto.replyToMessageId?.trim() || undefined,
          replyToSenderUserId: dto.replyToSenderUserId?.trim() || undefined,
          replyToSenderName: dto.replyToSenderName?.trim() || undefined,
          replyToContent: dto.replyToContent?.trim() || undefined,
          productId: effectiveProductSnapshot?.id ?? undefined,
          productTitle: effectiveProductSnapshot?.title || undefined,
          productSubtitle: effectiveProductSnapshot?.subtitle || undefined,
          productPriceLabel: effectiveProductSnapshot?.priceLabel || undefined,
          productImageUrl: effectiveProductSnapshot?.imageUrl || undefined,
        },
      });

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
        type: 'message:new',
        conversationId: conversation.id,
        actorUserId: userId,
      },
    );

    if (!this.conversationsRealtimeGateway.isUserConnected(recipientUserId)) {
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
    }

    return this.getConversation(userId, conversationId);
  }

  async sendMediaMessage(
    userId: string,
    conversationId: string,
    dto: CreateMediaMessageDto,
  ) {
    const mediaPayload = this.extractMediaPayload(dto);
    const content = (dto.content?.trim() ?? '').length > 0
      ? dto.content!.trim()
      : dto.kind === 'IMAGE'
      ? 'Photo envoyee'
      : 'Document envoye';

    const conversation = await this.findAccessibleConversation(
      userId,
      conversationId,
    );
    const recipientUserId = conversation.buyerUserId === userId
      ? conversation.sellerUserId
      : conversation.buyerUserId;
    const sender = conversation.buyerUserId === userId
      ? conversation.buyer
      : conversation.seller;
    const recipient = conversation.buyerUserId === userId
      ? conversation.seller
      : conversation.buyer;

    await this.assertUsersCanInteract(userId, recipientUserId);

    await this.prisma.$transaction(async (transaction) => {
      await transaction.chatMessage.create({
        data: {
          conversationId: conversation.id,
          senderUserId: userId,
          content,
          kind: dto.kind,
          replyToMessageId: dto.replyToMessageId?.trim() || undefined,
          replyToSenderUserId: dto.replyToSenderUserId?.trim() || undefined,
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
              encryptionScheme: mediaPayload.encryptionScheme ?? undefined,
              encryptionKeyB64: mediaPayload.encryptionKeyB64 ?? undefined,
              encryptionIvB64: mediaPayload.encryptionIvB64 ?? undefined,
              fileSha256B64: mediaPayload.fileSha256B64 ?? undefined,
                mediaGroupId: mediaPayload.mediaGroupId ?? undefined,
            },
          },
        },
      });

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
        type: 'message:new',
        conversationId: conversation.id,
        actorUserId: userId,
      },
    );

    if (!this.conversationsRealtimeGateway.isUserConnected(recipientUserId)) {
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
    }

    return this.getConversation(userId, conversationId);
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
      title: dto.productTitle?.trim() ?? '',
      subtitle: dto.productSubtitle?.trim() ?? '',
      priceLabel: dto.productPriceLabel?.trim() ?? '',
      imageUrl: dto.productImageUrl?.trim() ?? '',
    };
  }

  private isUserOnline(participant: { id: string; lastSeenAt?: Date | null }) {
    if (this.conversationsRealtimeGateway.isUserConnected(participant.id)) {
      return true;
    }

    if (participant.lastSeenAt == null) {
      return false;
    }

    return Date.now() - participant.lastSeenAt.getTime() <= PRESENCE_RECENT_ACTIVITY_WINDOW_MS;
  }

  private async findAccessibleConversation(userId: string, conversationId: string) {
    const conversation = await this.prisma.chatConversation.findUnique({
      where: { id: conversationId },
      include: conversationDetailInclude,
    });

    if (!conversation) {
      throw new NotFoundException('Conversation not found');
    }

    if (
      conversation.buyerUserId !== userId &&
      conversation.sellerUserId !== userId
    ) {
      throw new ForbiddenException(
        'You do not have access to this conversation',
      );
    }

    return conversation;
  }

  private async markConversationAsRead(conversationId: string, userId: string) {
    const result = await this.prisma.chatMessage.updateMany({
      where: {
        conversationId,
        senderUserId: {
          not: userId,
        },
        readAt: null,
      },
      data: {
        readAt: new Date(),
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
        type: 'conversation:read',
        conversationId: conversation.id,
        actorUserId: userId,
      },
    );
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
          }
        : null,
      unreadCount,
      kind: conversation.kind,
      lastMessageAt: conversation.lastMessageAt.toISOString(),
      ...blockState,
    };
  }

  private async presentConversationDetail(
    conversation: ConversationDetail,
    userId: string,
  ) {
    const isBuyer = conversation.buyerUserId === userId;
    const participant = isBuyer ? conversation.seller : conversation.buyer;
    const blockState = await this.presentConversationBlockState(
      userId,
      participant.id,
    );
    const currentProductSnapshots = await this.buildCurrentProductSnapshotMap(
      conversation.messages,
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
            subtitle: `${conversation.product.category.name} • ${conversation.product.isAvailable ? 'Disponible' : 'Indisponible'}`,
            imageUrl: conversation.product.imageUrl,
            price: conversation.product.priceAmount.toNumber(),
            currency: conversation.product.currencyCode,
          }
        : null,
      messages: conversation.messages.map((message) => ({
        id: message.id,
        content: message.content,
        kind: message.kind,
        createdAt: message.createdAt.toISOString(),
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
      ...blockState,
    };
  }

  private async presentConversationThreadDetail(
    anchorConversation: ConversationDetail,
    conversations: ConversationDetail[],
    userId: string,
  ) {
    const anchorIsBuyer = anchorConversation.buyerUserId === userId;
    const participant = anchorIsBuyer
      ? anchorConversation.seller
      : anchorConversation.buyer;
    const blockState = await this.presentConversationBlockState(
      userId,
      participant.id,
    );
    const currentProductSnapshots = await this.buildCurrentProductSnapshotMap(
      conversations.flatMap((conversation) => conversation.messages),
    );

    const messages = conversations
      .flatMap((conversation) =>
        conversation.messages.map<ConversationThreadMessage>((message) => ({
          id: message.id,
          content: message.content,
          kind: message.kind,
          createdAt: message.createdAt.toISOString(),
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
      )
      .sort(
        (first, second) =>
          new Date(first.createdAt).getTime() -
          new Date(second.createdAt).getTime(),
      );

    const createdAt = conversations
      .map((conversation) => conversation.createdAt)
      .sort((first, second) => first.getTime() - second.getTime())[0];
    const lastMessageAt = conversations
      .map((conversation) => conversation.lastMessageAt)
      .sort((first, second) => second.getTime() - first.getTime())[0];

    return {
      id: anchorConversation.id,
      participant: {
        id: participant.id,
        displayName: participant.displayName,
        avatarUrl: participant.avatarUrl,
        roleLabel: this.resolveRoleLabel(participant),
        isOnline: this.isUserOnline(participant),
        lastSeenAt: participant.lastSeenAt?.toISOString() ?? null,
      },
      product: null,
      messages,
      kind: 'DIRECT',
      createdAt: createdAt.toISOString(),
      lastMessageAt: lastMessageAt.toISOString(),
      ...blockState,
    };
  }

  private async buildCurrentProductSnapshotMap(
    messages: MessageProductSnapshotFields[],
  ) {
    const productIds = Array.from(
      new Set(
        messages
          .map((message) => message.productId?.trim() ?? '')
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
          subtitle: `${product.category.name} • ${product.isAvailable ? 'Disponible' : 'Indisponible'}`,
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
    if (message.kind === 'IMAGE' || message.kind === 'DOCUMENT') {
      return null;
    }

    const currentProductId = message.productId?.trim() ?? '';
    if (
      currentProductId.length > 0 &&
      currentProductSnapshots?.has(currentProductId) === true
    ) {
      return currentProductSnapshots!.get(currentProductId)!;
    }

    const title = message.productTitle?.trim() ?? '';
    const subtitle = message.productSubtitle?.trim() ?? '';
    const priceLabel = message.productPriceLabel?.trim() ?? '';
    const imageUrl = message.productImageUrl?.trim() ?? '';

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
    if (mediaType !== 'image' && mediaType !== 'document') {
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
    const normalizedStorageProvider = dto.storageProvider?.trim() || 'cloudinary';
    const normalizedStorageKey = dto.storageKey?.trim() || null;
    const normalizedPublicUrl = dto.publicUrl.trim();
    const imageVariants =
      dto.mediaType === 'image' && normalizedStorageProvider.toLowerCase() == 'cloudinary'
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
    const content = message.replyToContent?.trim() ?? '';

    if (content.length === 0) {
      return null;
    }

    return {
      messageId: message.replyToMessageId ?? null,
      senderLabel:
        message.replyToSenderUserId != null &&
            message.replyToSenderUserId === currentUserId
        ? 'Vous'
        : (((message.replyToSenderName?.trim().length ?? 0) > 0)
              ? message.replyToSenderName!.trim()
              : 'Message'),
      content,
    };
  }
}