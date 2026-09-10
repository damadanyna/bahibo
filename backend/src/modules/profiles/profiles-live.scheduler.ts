import { Injectable, Logger } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';

import { ProfilesService } from './profiles.service';

/**
 * Closes lives whose host went silent (data exhausted, battery dead, app
 * killed): without this, a session stays "en direct" for days and viewers
 * land on an empty room. Every 30 s, so a dead live disappears at most
 * two minutes after the last heartbeat.
 */
@Injectable()
export class ProfilesLiveScheduler {
  private readonly logger = new Logger(ProfilesLiveScheduler.name);

  constructor(private readonly profilesService: ProfilesService) {}

  @Interval('expireStaleLiveSessions', 30_000)
  async expireStaleLiveSessions() {
    try {
      await this.profilesService.expireStaleLiveSessions();
    } catch (error) {
      this.logger.warn(
        `Stale live sweep failed: ${
          error instanceof Error ? error.message : String(error)
        }`,
      );
    }
  }
}
