import {
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
  OnModuleDestroy,
} from '@nestjs/common';
import { VoiceCallStatus } from '@prisma/client';
import { TrackSource } from 'livekit-server-sdk';
import { randomUUID } from 'node:crypto';

import { ConversationsService } from '../conversations/conversations.service';
import { ConversationsRealtimeGateway } from '../conversations/realtime/conversations-realtime.gateway';
import { LivekitService } from '../livekit/livekit.service';
import { PrismaService } from '../prisma/prisma.service';
import { PushNotificationsService } from '../push-notifications/push-notifications.service';

/** How long the callee's phone rings before the call is marked missed. */
const RING_TIMEOUT_MS = 45_000;
/** A RINGING row older than this outlived its timer (server restart). */
const STALE_RINGING_MS = 60_000;
/** An ACCEPTED row older than this was never hung up (app killed). */
const STALE_ACTIVE_MS = 6 * 60 * 60 * 1000;

const ACTIVE_STATUSES: VoiceCallStatus[] = [
  VoiceCallStatus.RINGING,
  VoiceCallStatus.ACCEPTED,
];

const callParticipantSelect = {
  id: true,
  displayName: true,
  avatarUrl: true,
} as const;

type CallRecord = {
  id: string;
  conversationId: string;
  callerUserId: string;
  calleeUserId: string;
  status: VoiceCallStatus;
  roomName: string;
  createdAt: Date;
  answeredAt: Date | null;
  endedAt: Date | null;
  endedByUserId: string | null;
  caller: { id: string; displayName: string; avatarUrl: string | null };
  callee: { id: string; displayName: string; avatarUrl: string | null };
};

const callInclude = {
  caller: { select: callParticipantSelect },
  callee: { select: callParticipantSelect },
} as const;

/**
 * Voice calls between the two sides of a conversation. The row is the
 * signalling truth; both apps follow it through `calls:updated` realtime
 * events, the callee's phone is woken by a push, and the audio itself is a
 * LiveKit room named after the call.
 */
@Injectable()
export class CallsService implements OnModuleDestroy {
  private readonly logger = new Logger(CallsService.name);
  private readonly ringTimers = new Map<string, NodeJS.Timeout>();

  constructor(
    private readonly prisma: PrismaService,
    private readonly conversationsService: ConversationsService,
    private readonly conversationsRealtimeGateway: ConversationsRealtimeGateway,
    private readonly pushNotificationsService: PushNotificationsService,
    private readonly livekitService: LivekitService,
  ) {}

  onModuleDestroy() {
    for (const timer of this.ringTimers.values()) {
      clearTimeout(timer);
    }
    this.ringTimers.clear();
  }

  async startCall(userId: string, conversationId: string) {
    const conversation = await this.prisma.chatConversation.findUnique({
      where: { id: conversationId },
      include: {
        buyer: { select: callParticipantSelect },
        seller: { select: callParticipantSelect },
      },
    });

    if (!conversation) {
      throw new NotFoundException('Conversation not found');
    }
    if (
      conversation.buyerUserId !== userId &&
      conversation.sellerUserId !== userId
    ) {
      throw new ForbiddenException('You do not have access to this conversation');
    }

    const caller =
      conversation.buyerUserId === userId ? conversation.buyer : conversation.seller;
    const callee =
      conversation.buyerUserId === userId ? conversation.seller : conversation.buyer;

    await this.conversationsService.assertUsersCanInteract(userId, callee.id);

    if (await this.hasActiveCall(userId)) {
      throw new ConflictException('Vous êtes déjà en appel.');
    }
    if (await this.hasActiveCall(callee.id)) {
      throw new ConflictException(`${callee.displayName} est déjà en appel.`);
    }

    const callId = randomUUID();
    const call = await this.prisma.voiceCall.create({
      data: {
        id: callId,
        conversationId: conversation.id,
        callerUserId: caller.id,
        calleeUserId: callee.id,
        status: VoiceCallStatus.RINGING,
        roomName: `call-${callId}`,
      },
      include: callInclude,
    });

    this.conversationsRealtimeGateway.emitCallEvent([callee.id], {
      type: 'call:incoming',
      callId: call.id,
      conversationId: call.conversationId,
      callerUserId: caller.id,
      calleeUserId: callee.id,
      caller: {
        id: caller.id,
        displayName: caller.displayName,
        avatarUrl: caller.avatarUrl,
      },
    });

    // The caller is already listening for the answer: the push must neither
    // delay nor fail the start.
    void this.pushNotificationsService
      .sendIncomingCallNotification({
        recipientUserId: callee.id,
        callId: call.id,
        conversationId: call.conversationId,
        callerDisplayName: caller.displayName,
        callerAvatarUrl: caller.avatarUrl ?? undefined,
      })
      .catch((error: unknown) => {
        this.logger.warn(
          `Incoming call push failed for call ${call.id}: ${
            error instanceof Error ? error.message : String(error)
          }`,
        );
      });

    this.scheduleRingTimeout(call.id);

    return {
      ...this.presentCall(call),
      url: this.livekitService.requireUrl(),
      token: await this.buildParticipantToken(call, caller),
    };
  }

  /**
   * The callee's phone got the invitation and rings: tells the caller, who
   * moves from "Appel…" to "Appel en cours…" (WhatsApp-style). Idempotent;
   * silently ignored once the call left the ringing state.
   */
  async markRinging(userId: string, callId: string) {
    const call = await this.findCallForUser(userId, callId);
    if (call.calleeUserId !== userId) {
      throw new ForbiddenException('Only the callee can acknowledge a call');
    }
    if (call.status === VoiceCallStatus.RINGING) {
      this.conversationsRealtimeGateway.emitCallEvent([call.callerUserId], {
        type: 'call:ringing',
        callId: call.id,
        conversationId: call.conversationId,
        callerUserId: call.callerUserId,
        calleeUserId: call.calleeUserId,
      });
    }
    return this.presentCall(call);
  }

  async acceptCall(userId: string, callId: string) {
    const call = await this.findCallForUser(userId, callId);
    if (call.calleeUserId !== userId) {
      throw new ForbiddenException('Only the callee can accept a call');
    }
    if (call.status !== VoiceCallStatus.RINGING) {
      throw new ConflictException("Cet appel n'est plus disponible.");
    }

    this.clearRingTimeout(call.id);
    const accepted = await this.prisma.voiceCall.update({
      where: { id: call.id },
      data: { status: VoiceCallStatus.ACCEPTED, answeredAt: new Date() },
      include: callInclude,
    });

    this.conversationsRealtimeGateway.emitCallEvent(
      [accepted.callerUserId, accepted.calleeUserId],
      {
        type: 'call:accepted',
        callId: accepted.id,
        conversationId: accepted.conversationId,
        callerUserId: accepted.callerUserId,
        calleeUserId: accepted.calleeUserId,
      },
    );

    return {
      ...this.presentCall(accepted),
      url: this.livekitService.requireUrl(),
      token: await this.buildParticipantToken(accepted, accepted.callee),
    };
  }

  async declineCall(userId: string, callId: string) {
    const call = await this.findCallForUser(userId, callId);
    if (call.calleeUserId !== userId) {
      throw new ForbiddenException('Only the callee can decline a call');
    }
    if (call.status !== VoiceCallStatus.RINGING) {
      return this.presentCall(call);
    }

    return this.presentCall(
      await this.closeCall(call, VoiceCallStatus.DECLINED, 'declined', userId),
    );
  }

  /** Either side hangs up: cancels a ringing call, ends an accepted one. */
  async endCall(userId: string, callId: string) {
    const call = await this.findCallForUser(userId, callId);

    if (call.status === VoiceCallStatus.RINGING) {
      const isCaller = call.callerUserId === userId;
      return this.presentCall(
        await this.closeCall(
          call,
          isCaller ? VoiceCallStatus.CANCELLED : VoiceCallStatus.DECLINED,
          isCaller ? 'cancelled' : 'declined',
          userId,
        ),
      );
    }

    if (call.status === VoiceCallStatus.ACCEPTED) {
      return this.presentCall(
        await this.closeCall(call, VoiceCallStatus.ENDED, 'ended', userId),
      );
    }

    return this.presentCall(call);
  }

  /** Used by the app opened from a notification to know if it still rings. */
  async getCall(userId: string, callId: string) {
    const call = await this.findCallForUser(userId, callId);
    if (
      call.status === VoiceCallStatus.RINGING &&
      Date.now() - call.createdAt.getTime() > STALE_RINGING_MS
    ) {
      return this.presentCall(
        await this.closeCall(call, VoiceCallStatus.MISSED, 'missed', null),
      );
    }

    return this.presentCall(call);
  }

  private async findCallForUser(userId: string, callId: string) {
    const call = await this.prisma.voiceCall.findUnique({
      where: { id: callId },
      include: callInclude,
    });

    if (!call) {
      throw new NotFoundException('Call not found');
    }
    if (call.callerUserId !== userId && call.calleeUserId !== userId) {
      throw new ForbiddenException('You do not have access to this call');
    }

    return call;
  }

  private async hasActiveCall(userId: string) {
    const active = await this.prisma.voiceCall.findFirst({
      where: {
        OR: [{ callerUserId: userId }, { calleeUserId: userId }],
        status: { in: ACTIVE_STATUSES },
      },
      orderBy: { createdAt: 'desc' },
      include: callInclude,
    });

    if (!active) {
      return false;
    }

    // Rows that outlived their lifecycle (server restart, app killed) must
    // not lock the user out of calling forever.
    const age = Date.now() - active.createdAt.getTime();
    if (active.status === VoiceCallStatus.RINGING && age > STALE_RINGING_MS) {
      await this.closeCall(active, VoiceCallStatus.MISSED, 'missed', null);
      return false;
    }
    if (active.status === VoiceCallStatus.ACCEPTED && age > STALE_ACTIVE_MS) {
      await this.closeCall(active, VoiceCallStatus.ENDED, 'ended', null);
      return false;
    }

    return true;
  }

  private scheduleRingTimeout(callId: string) {
    this.clearRingTimeout(callId);
    const timer = setTimeout(() => {
      this.ringTimers.delete(callId);
      void this.expireRingingCall(callId).catch((error: unknown) => {
        this.logger.warn(
          `Ring timeout failed for call ${callId}: ${
            error instanceof Error ? error.message : String(error)
          }`,
        );
      });
    }, RING_TIMEOUT_MS);
    this.ringTimers.set(callId, timer);
  }

  private clearRingTimeout(callId: string) {
    const timer = this.ringTimers.get(callId);
    if (timer) {
      clearTimeout(timer);
      this.ringTimers.delete(callId);
    }
  }

  private async expireRingingCall(callId: string) {
    const call = await this.prisma.voiceCall.findUnique({
      where: { id: callId },
      include: callInclude,
    });
    if (!call || call.status !== VoiceCallStatus.RINGING) {
      return;
    }
    await this.closeCall(call, VoiceCallStatus.MISSED, 'missed', null);
  }

  /**
   * Single exit path: persists the final status, tells both apps, takes the
   * callee's ringing notification down when it never answered, and leaves
   * the call line in the chat.
   */
  private async closeCall(
    call: CallRecord,
    status: VoiceCallStatus,
    reason: 'ended' | 'declined' | 'missed' | 'cancelled',
    endedByUserId: string | null,
  ) {
    this.clearRingTimeout(call.id);
    const closed = await this.prisma.voiceCall.update({
      where: { id: call.id },
      data: { status, endedAt: new Date(), endedByUserId },
      include: callInclude,
    });

    this.conversationsRealtimeGateway.emitCallEvent(
      [closed.callerUserId, closed.calleeUserId],
      {
        type: 'call:ended',
        callId: closed.id,
        conversationId: closed.conversationId,
        callerUserId: closed.callerUserId,
        calleeUserId: closed.calleeUserId,
        reason,
        endedByUserId,
      },
    );

    if (reason === 'missed' || reason === 'cancelled') {
      // Ringing UI down first, then the one notification the callee keeps.
      void this.pushNotificationsService
        .sendCallCancelledNotification({
          recipientUserId: closed.calleeUserId,
          callId: closed.id,
        })
        .catch(() => undefined);
      void this.pushNotificationsService
        .sendMissedCallNotification({
          recipientUserId: closed.calleeUserId,
          callId: closed.id,
          conversationId: closed.conversationId,
          callerDisplayName: closed.caller.displayName,
          callerAvatarUrl: closed.caller.avatarUrl ?? undefined,
        })
        .catch((error: unknown) => {
          this.logger.warn(
            `Missed call push failed for call ${closed.id}: ${
              error instanceof Error ? error.message : String(error)
            }`,
          );
        });
    }

    await this.postCallLine(closed, reason);
    return closed;
  }

  /** "📞 Appel vocal · 2 min 05" / "📞 Appel vocal manqué" in the chat. */
  private async postCallLine(
    call: CallRecord,
    reason: 'ended' | 'declined' | 'missed' | 'cancelled',
  ) {
    let content: string;
    switch (reason) {
      case 'ended': {
        const seconds =
          call.answeredAt && call.endedAt
            ? Math.max(
                0,
                Math.round(
                  (call.endedAt.getTime() - call.answeredAt.getTime()) / 1000,
                ),
              )
            : 0;
        content = `📞 Appel vocal · ${this.formatDuration(seconds)}`;
        break;
      }
      case 'declined':
        content = '📞 Appel vocal refusé';
        break;
      default:
        content = '📞 Appel vocal manqué';
    }

    try {
      // Always silent: a missed call has its own dedicated push (see
      // closeCall), everything else is already known to both sides.
      await this.conversationsService.sendMessage(
        call.callerUserId,
        call.conversationId,
        { content },
        null,
        { skipPush: true },
      );
    } catch (error) {
      this.logger.warn(
        `Call line not posted for call ${call.id}: ${
          error instanceof Error ? error.message : String(error)
        }`,
      );
    }
  }

  private formatDuration(totalSeconds: number) {
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    if (minutes === 0) {
      return `${seconds} s`;
    }
    return `${minutes} min ${seconds.toString().padStart(2, '0')}`;
  }

  private buildParticipantToken(
    call: CallRecord,
    participant: { id: string; displayName: string },
  ) {
    return this.livekitService.buildToken({
      roomName: call.roomName,
      identity: `user-${participant.id}`,
      name: participant.displayName,
      canPublish: true,
      canSubscribe: true,
      canPublishData: false,
      canPublishSources: [TrackSource.MICROPHONE],
      // Only needed to join, which happens at once; the session outlives
      // the token (LiveKit refreshes it in-band for reconnects).
      ttl: '15m',
    });
  }

  private presentCall(call: CallRecord) {
    return {
      callId: call.id,
      conversationId: call.conversationId,
      status: call.status,
      roomName: call.roomName,
      caller: call.caller,
      callee: call.callee,
      createdAt: call.createdAt.toISOString(),
      answeredAt: call.answeredAt?.toISOString() ?? null,
      endedAt: call.endedAt?.toISOString() ?? null,
    };
  }
}
