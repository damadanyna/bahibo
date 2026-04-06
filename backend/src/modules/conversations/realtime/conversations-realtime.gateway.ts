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

type ConversationRealtimePayload = {
  type: 'message:new' | 'conversation:read';
  conversationId: string;
  actorUserId: string;
};

type ConversationTypingPayload = {
  conversationId: string;
  recipientUserId: string;
  isTyping: boolean;
};

type ProfileRealtimePayload = {
  type: 'profile:updated' | 'profile:shop-request-updated';
  userId: string;
  profile: {
    id: string;
    role: string;
    shopRequestStatus: string;
    shopRequestSubmittedAt: string | null;
    shopRequestReviewedAt: string | null;
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
  reason: 'product_like' | 'product_comment';
};

type PresenceRealtimePayload = {
  type: 'presence:updated';
  userId: string;
  isOnline: boolean;
};

@Injectable()
@WebSocketGateway({
  cors: {
    origin: '*',
    credentials: true,
  },
  transports: ['websocket', 'polling'],
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
      this.emitPresenceEvent({
        type: 'presence:updated',
        userId: payload.sub,
        isOnline: true,
      });
      this.logger.debug(`Socket connected for user ${payload.sub}`);
    } catch {
      client.disconnect();
    }
  }

  handleDisconnect(client: Socket) {
    const userId = client.data.userId as string | undefined;
    if (userId != null) {
      this.emitPresenceEvent({
        type: 'presence:updated',
        userId,
        isOnline: this.isUserConnected(userId),
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