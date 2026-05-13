import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  OnGatewayInit,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Server, Socket } from 'socket.io';

import { PrismaService } from '../../prisma/prisma.service';

type ConversationRealtimePayload = {
  type: 'message:new' | 'conversation:read' | 'conversation:blocked';
  conversationId: string;
  actorUserId: string;
  readAt?: string | null;
  message?: {
    id: string;
    content: string;
    kind: 'TEXT' | 'IMAGE' | 'DOCUMENT' | 'PRODUCT';
    createdAt: string;
    readAt: string | null;
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
    media: Record<string, unknown> | null;
    product: {
      id: string | null;
      title: string;
      subtitle: string;
      priceLabel: string;
      imageUrl: string;
    } | null;
  } | null;
};

type ConversationTypingPayload = {
  conversationId: string;
  recipientUserId: string;
  isTyping: boolean;
};

type ProfileRealtimePayload = {
  type:
    | 'profile:updated'
    | 'profile:shop-request-updated'
    | 'profile:public-updated';
  userId: string;
  profile: {
    id: string;
    role?: string;
    displayName?: string;
    avatarUrl?: string | null;
    coverImageUrl?: string | null;
    shopRequestStatus?: string;
    shopRequestSubmittedAt?: string | null;
    shopRequestReviewedAt?: string | null;
    sellerVerificationRequestStatus?: string;
    sellerVerificationRequestedAt?: string | null;
    sellerVerificationReviewedAt?: string | null;
    isSellerCertified?: boolean;
    sellerProfile: Record<string, unknown> | null;
  };
};

type NotificationRealtimePayload = {
  type: 'notifications:updated';
  userId: string;
  reason:
    | 'product_like'
    | 'product_comment'
    | 'followed_seller_activity'
    | 'seller_follow';
  unreadCount?: number;
};

type PresenceRealtimePayload = {
  type: 'presence:updated';
  userId: string;
  isOnline: boolean;
  lastSeenAt?: string | null;
};

type LiveRealtimePayload = {
  type: 'live:updated';
  sellerProfileId: string;
  isLive: boolean;
  title: string | null;
  category: string | null;
  startedAt: string | null;
};

type ProductRealtimePayload = {
  type: 'product:updated';
  productId: string;
  actorUserId: string;
  action:
    | 'liked'
    | 'unliked'
    | 'commented'
    | 'shared'
    | 'updated'
    | 'availability_changed';
  product: Record<string, unknown>;
  comment?: Record<string, unknown> | null;
};

@Injectable()
@WebSocketGateway({
  cors: {
    origin: '*',
    credentials: true,
  },
  transports: ['websocket', 'polling'],
  pingInterval: 5000,
  pingTimeout: 8000,
})
export class ConversationsRealtimeGateway
  implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer()
  private server!: Server;

  private readonly logger = new Logger(ConversationsRealtimeGateway.name);

  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  afterInit() {
    this.logger.log('Conversations realtime gateway ready');
  }

  async handleConnection(client: Socket) {
    const token = this.extractAccessToken(client);
    if (!token) {
      client.disconnect();
      return;
    }

    try {
      const payload = await this.jwtService.verifyAsync<{
        sub: string;
        type?: string;
      }>(token, {
        secret: this.configService.get<string>(
          'JWT_ACCESS_SECRET',
          'change-me-access',
        ),
      });

      if (!payload.sub || payload.type === 'refresh') {
        client.disconnect();
        return;
      }

      client.data.userId = payload.sub;
      await client.join(this.userRoom(payload.sub));
      await this.prisma.user.update({
        where: { id: payload.sub },
        data: { lastSeenAt: new Date() },
      });
      this.emitPresenceEvent({
        type: 'presence:updated',
        userId: payload.sub,
        isOnline: true,
        lastSeenAt: null,
      });
      this.logger.debug(`Socket connected for user ${payload.sub}`);
    } catch {
      client.disconnect();
    }
  }

  handleDisconnect(client: Socket) {
    const userId = client.data.userId as string | undefined;
    if (userId != null) {
      const lastSeenAt = new Date();
      void this.prisma.user.update({
        where: { id: userId },
        data: { lastSeenAt },
      }).catch(() => undefined);
      this.emitPresenceEvent({
        type: 'presence:updated',
        userId,
        isOnline: this.isUserConnected(userId),
        lastSeenAt: lastSeenAt.toISOString(),
      });
      this.logger.debug(`Socket disconnected for user ${userId}`);
    }
  }

  @SubscribeMessage('conversations:ping')
  handlePing(@ConnectedSocket() client: Socket) {
    return {
      ok: true,
      userId: client.data.userId as string | undefined,
      timestamp: new Date().toISOString(),
    };
  }

  @SubscribeMessage('conversations:typing')
  handleTyping(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: ConversationTypingPayload,
  ) {
    const actorUserId = client.data.userId as string | undefined;
    if (
      actorUserId == null ||
      payload.conversationId.trim().length === 0 ||
      payload.recipientUserId.trim().length === 0
    ) {
      return;
    }

    this.server.to(this.userRoom(payload.recipientUserId)).emit(
      'conversations:typing',
      {
        type: 'typing:update',
        conversationId: payload.conversationId,
        actorUserId,
        isTyping: payload.isTyping,
      },
    );
  }

  emitConversationEvent(
    participantUserIds: string[],
    payload: ConversationRealtimePayload,
  ) {
    if (!this.server) {
      return;
    }

    const uniqueUserIds = [...new Set(participantUserIds)];
    for (const userId of uniqueUserIds) {
      this.server.to(this.userRoom(userId)).emit('conversations:updated', payload);
    }
  }

  emitProfileEvent(userId: string, payload: ProfileRealtimePayload) {
    if (!this.server) {
      return;
    }

    this.server.to(this.userRoom(userId)).emit('profiles:updated', payload);
  }

  emitPublicProfileEvent(payload: ProfileRealtimePayload) {
    if (!this.server) {
      return;
    }

    this.server.emit('profiles:updated', payload);
  }

  emitNotificationEvent(userId: string, payload: NotificationRealtimePayload) {
    if (!this.server) {
      return;
    }

    this.server.to(this.userRoom(userId)).emit('notifications:updated', payload);
  }

  emitPresenceEvent(payload: PresenceRealtimePayload) {
    if (!this.server) {
      return;
    }

    this.server.emit('presence:updated', payload);
  }

  emitLiveEvent(userIds: string[], payload: LiveRealtimePayload) {
    if (!this.server) {
      return;
    }

    const uniqueUserIds = [...new Set(userIds)];
    for (const userId of uniqueUserIds) {
      this.server.to(this.userRoom(userId)).emit('live:updated', payload);
    }
  }

  emitProductEvent(payload: ProductRealtimePayload) {
    if (!this.server) {
      return;
    }

    this.server.emit('products:updated', payload);
  }

  isUserConnected(userId: string) {
    if (!this.server) {
      return false;
    }

    return (this.server.sockets.adapter.rooms.get(this.userRoom(userId))?.size ?? 0) > 0;
  }

  private extractAccessToken(client: Socket) {
    const authToken = client.handshake.auth.token;
    if (typeof authToken === 'string' && authToken.trim().length > 0) {
      return authToken.trim();
    }

    const authorizationHeader = client.handshake.headers.authorization;
    if (typeof authorizationHeader === 'string') {
      const [scheme, credentials] = authorizationHeader.split(' ');
      if (scheme?.toLowerCase() === 'bearer' && credentials != null && credentials.trim().length > 0) {
        return credentials.trim();
      }
    }

    return undefined;
  }

  private userRoom(userId: string) {
    return `user:${userId}`;
  }
}