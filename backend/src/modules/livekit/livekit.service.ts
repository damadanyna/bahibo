import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AccessToken, RoomServiceClient, TrackSource } from 'livekit-server-sdk';

/**
 * LiveKit access shared by every media feature (seller lives, voice calls):
 * one place for the server URL and for minting room tokens.
 */
@Injectable()
export class LivekitService {
  private readonly logger = new Logger(LivekitService.name);

  constructor(private readonly configService: ConfigService) {}

  /**
   * Identities currently connected to [roomName], or `null` when LiveKit
   * could not be asked (callers must then fall back to other signals).
   */
  async listParticipantIdentities(roomName: string): Promise<string[] | null> {
    const apiKey = this.configService.get<string>('LIVEKIT_API_KEY')?.trim() ?? '';
    const apiSecret = this.configService.get<string>('LIVEKIT_API_SECRET')?.trim() ?? '';
    if (apiKey.length === 0 || apiSecret.length === 0) {
      return null;
    }

    try {
      // The SDK turns the ws(s):// signalling URL into the http(s) API host.
      const client = new RoomServiceClient(this.requireUrl(), apiKey, apiSecret);
      const participants = await client.listParticipants(roomName);
      return participants.map((participant) => participant.identity);
    } catch (error) {
      this.logger.warn(
        `listParticipants(${roomName}) failed: ${
          error instanceof Error ? error.message : String(error)
        }`,
      );
      return null;
    }
  }

  requireUrl() {
    const livekitUrl = this.configService.get<string>('LIVEKIT_URL')?.trim() ?? '';
    if (livekitUrl.length === 0) {
      throw new BadRequestException('LIVEKIT_URL is not configured');
    }

    return livekitUrl;
  }

  async buildToken(params: {
    roomName: string;
    identity: string;
    name: string;
    canPublish: boolean;
    canSubscribe: boolean;
    /** Data channel (live comments / likes). Defaults to `canPublish`. */
    canPublishData?: boolean;
    /** Defaults to camera + microphone when `canPublish` is set. */
    canPublishSources?: TrackSource[];
    /** Token lifetime, e.g. `'2h'`. */
    ttl?: string;
  }) {
    const apiKey = this.configService.get<string>('LIVEKIT_API_KEY')?.trim() ?? '';
    const apiSecret = this.configService.get<string>('LIVEKIT_API_SECRET')?.trim() ?? '';

    if (apiKey.length === 0 || apiSecret.length === 0) {
      throw new BadRequestException('LiveKit credentials are not configured');
    }

    const token = new AccessToken(apiKey, apiSecret, {
      identity: params.identity,
      name: params.name,
      ttl: params.ttl ?? '2h',
    });

    token.addGrant({
      roomJoin: true,
      room: params.roomName,
      canPublish: params.canPublish,
      canSubscribe: params.canSubscribe,
      canPublishData: params.canPublishData ?? params.canPublish,
      canPublishSources: params.canPublish
        ? (params.canPublishSources ?? [TrackSource.CAMERA, TrackSource.MICROPHONE])
        : undefined,
    });

    return token.toJwt();
  }
}
