import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AccessToken, RoomServiceClient, TrackSource } from 'livekit-server-sdk';

/**
 * Viewer-side buffer for seller-live rooms, in milliseconds. WebRTC plays
 * frames out as soon as they arrive (sub-second latency), so every jitter
 * or loss burst on a 4G viewer shows as a freeze or an audio cut. TikTok
 * hides those behind a few seconds of player buffer; LiveKit's playout
 * delay is the SFU-side equivalent: subscribers hold this much video before
 * rendering (RTP playout-delay extension, honoured by libwebrtc on
 * Android / iOS and by Chromium). Audio follows through `syncStreams`.
 * Voice-call rooms are not created through here and keep the real-time
 * default.
 *
 * One value, sent as both min and max, on purpose. Given a range, the SFU
 * moves the delay inside it from the jitter of every RTCP receiver report
 * (jitter × 10, at most 80 ms per second) and the phone applies each new
 * floor at once: every rise freezes the picture for the difference, every
 * drop skips ahead. With 1000–3000 a 4G viewer saw a freeze every few
 * seconds. Equal bounds are signalled once and never move.
 *
 * `LIVE_PLAYOUT_DELAY_MS` in the environment overrides the default; `0`
 * disables the buffer (rooms then behave as before 2026-09-13).
 */
const DEFAULT_LIVE_PLAYOUT_DELAY_MS = 800;
// libwebrtc caps the extension at 40 950 ms; anything near that is a bug.
const MAX_LIVE_PLAYOUT_DELAY_MS = 10_000;

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
    try {
      const client = this.roomServiceClient();
      if (client == null) {
        return null;
      }
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

  /**
   * Creates the seller-live room with the buffered playout profile before
   * anyone joins it. Idempotent: LiveKit hands back an existing room
   * unchanged. Never blocks a live start: on failure the room is
   * auto-created at the first join, with the real-time defaults.
   */
  async ensureLiveRoom(roomName: string): Promise<void> {
    const playoutDelayMs = this.livePlayoutDelayMs();
    if (playoutDelayMs === 0) {
      return;
    }
    try {
      const client = this.roomServiceClient();
      if (client == null) {
        return;
      }
      await client.createRoom({
        name: roomName,
        minPlayoutDelay: playoutDelayMs,
        maxPlayoutDelay: playoutDelayMs,
        syncStreams: true,
      });
    } catch (error) {
      this.logger.warn(
        `createRoom(${roomName}) failed, live will use real-time playout: ${
          error instanceof Error ? error.message : String(error)
        }`,
      );
    }
  }

  private livePlayoutDelayMs(): number {
    const raw = this.configService.get<string>('LIVE_PLAYOUT_DELAY_MS')?.trim() ?? '';
    if (raw.length === 0) {
      return DEFAULT_LIVE_PLAYOUT_DELAY_MS;
    }
    const parsed = Number.parseInt(raw, 10);
    if (!Number.isFinite(parsed) || parsed < 0) {
      this.logger.warn(`LIVE_PLAYOUT_DELAY_MS="${raw}" ignored, using ${DEFAULT_LIVE_PLAYOUT_DELAY_MS}`);
      return DEFAULT_LIVE_PLAYOUT_DELAY_MS;
    }
    return Math.min(parsed, MAX_LIVE_PLAYOUT_DELAY_MS);
  }

  /** `null` when the API key pair is not configured. */
  private roomServiceClient(): RoomServiceClient | null {
    const apiKey = this.configService.get<string>('LIVEKIT_API_KEY')?.trim() ?? '';
    const apiSecret = this.configService.get<string>('LIVEKIT_API_SECRET')?.trim() ?? '';
    if (apiKey.length === 0 || apiSecret.length === 0) {
      return null;
    }
    // The SDK turns the ws(s):// signalling URL into the http(s) API host.
    return new RoomServiceClient(this.requireUrl(), apiKey, apiSecret);
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
    /** Participant metadata, opaque to LiveKit, readable by every participant. */
    metadata?: string;
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
      metadata: params.metadata,
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
