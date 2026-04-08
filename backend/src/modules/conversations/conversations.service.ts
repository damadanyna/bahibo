import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { PushNotificationsService } from '../push-notifications/push-notifications.service';
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
  createdAt: string;
  isMine: boolean;
  sender: {
    id: string;
    displayName: string;
    avatarUrl: string | null;
  };
  product: ConversationMessageProductSnapshot | null;
};

type ConversationMessageProductSnapshot = {
  id: string | null;
  title: string;
  subtitle: string;
  priceLabel: string;
  imageUrl: string;
};

type MessageProductSnapshotFields = {
  productId: string | null;
  productTitle: string | null;
  productSubtitle: string | null;
  productPriceLabel: string | null;
  productImageUrl: string | null;
};

@Injectable()
export class ConversationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly pushNotificationsService: PushNotificationsService,
    private readonly conversationsRealtimeGateway: ConversationsRealtimeGateway,
  ) {}

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

    let directConversation = await this.prisma.chatConversation.findFirst({
      where: { directKey },
      include: conversationDetailInclude,
    });

    if (!directConversation) {
      directConversation = await this.prisma.chatConversation.create({
        data: {
          buyerUserId: userId,
          sellerUserId: targetUserId,
          kind: 'DIRECT',
          directKey,
        },
        include: conversationDetailInclude,
      });
    }

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
      directConversation,
      conversations,
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
    return this.sendMessage(userId, conversation.id, dto, {
      id: conversation.product?.id ?? null,
      title: conversation.product?.title ?? '',
      subtitle: conversation.product?.subtitle ?? '',
      priceLabel: conversation.product
        ? `${conversation.product.price} ${conversation.product.currency}`
        : '',
      imageUrl: conversation.product?.imageUrl ?? '',
    });
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

    const hasProductSnapshot =
      (dto.productId?.trim().length ?? 0) > 0 ||
      (dto.productTitle?.trim().length ?? 0) > 0 ||
      (dto.productSubtitle?.trim().length ?? 0) > 0 ||
      (dto.productPriceLabel?.trim().length ?? 0) > 0 ||
      (dto.productImageUrl?.trim().length ?? 0) > 0;

    return this.sendMessage(
      userId,
      conversation.id,
      dto,
      hasProductSnapshot
        ? {
            id: dto.productId?.trim() || null,
            title: dto.productTitle?.trim() ?? '',
            subtitle: dto.productSubtitle?.trim() ?? '',
            priceLabel: dto.productPriceLabel?.trim() ?? '',
            imageUrl: dto.productImageUrl?.trim() ?? '',
          }
        : undefined,
    );
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

    await this.prisma.$transaction(async (transaction) => {
      await transaction.chatMessage.create({
        data: {
          conversationId: conversation.id,
          senderUserId: userId,
          content,
          productId: productSnapshot?.id ?? undefined,
          productTitle: productSnapshot?.title || undefined,
          productSubtitle: productSnapshot?.subtitle || undefined,
          productPriceLabel: productSnapshot?.priceLabel || undefined,
          productImageUrl: productSnapshot?.imageUrl || undefined,
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

  private presentConversationListItem(
    conversation: ConversationListItem,
    userId: string,
    unreadCount: number,
  ) {
    const isBuyer = conversation.buyerUserId === userId;
    const participant = isBuyer ? conversation.seller : conversation.buyer;
    const lastMessage = conversation.messages[0] ?? null;

    return {
      id: conversation.id,
      participant: {
        id: participant.id,
        displayName: participant.displayName,
        avatarUrl: participant.avatarUrl,
        roleLabel: this.resolveRoleLabel(participant),
        isOnline: this.conversationsRealtimeGateway.isUserConnected(participant.id),
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
    };
  }

  private async presentConversationDetail(
    conversation: ConversationDetail,
    userId: string,
  ) {
    const isBuyer = conversation.buyerUserId === userId;
    const participant = isBuyer ? conversation.seller : conversation.buyer;
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
        isOnline: this.conversationsRealtimeGateway.isUserConnected(participant.id),
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
        createdAt: message.createdAt.toISOString(),
        isMine: message.senderUserId === userId,
        sender: {
          id: message.sender.id,
          displayName: message.sender.displayName,
          avatarUrl: message.sender.avatarUrl,
        },
        product: this.presentMessageProductSnapshot(
          message,
          currentProductSnapshots,
        ),
      })),
      kind: conversation.kind,
      createdAt: conversation.createdAt.toISOString(),
      lastMessageAt: conversation.lastMessageAt.toISOString(),
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
    const currentProductSnapshots = await this.buildCurrentProductSnapshotMap(
      conversations.flatMap((conversation) => conversation.messages),
    );

    const messages = conversations
      .flatMap((conversation) =>
        conversation.messages.map<ConversationThreadMessage>((message) => ({
          id: message.id,
          content: message.content,
          createdAt: message.createdAt.toISOString(),
          isMine: message.senderUserId === userId,
          sender: {
            id: message.sender.id,
            displayName: message.sender.displayName,
            avatarUrl: message.sender.avatarUrl,
          },
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
        isOnline: this.conversationsRealtimeGateway.isUserConnected(participant.id),
        lastSeenAt: participant.lastSeenAt?.toISOString() ?? null,
      },
      product: null,
      messages,
      kind: 'DIRECT',
      createdAt: createdAt.toISOString(),
      lastMessageAt: lastMessageAt.toISOString(),
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
}