import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Cron, CronExpression } from '@nestjs/schedule';

import { ConversationsService } from './conversations.service';

@Injectable()
export class ConversationsMediaAuditScheduler {
  private readonly logger = new Logger(ConversationsMediaAuditScheduler.name);

  constructor(
    private readonly configService: ConfigService,
    private readonly conversationsService: ConversationsService,
  ) {}

  @Cron(CronExpression.EVERY_DAY_AT_3AM)
  async auditOrphanedChatMediaAssets() {
    const enabled =
      this.configService.get<string>('CHAT_MEDIA_AUDIT_SCHEDULE_ENABLED', 'false') ===
      'true';

    if (!enabled) {
      return;
    }

    const olderThanDays = Number(
      this.configService.get<string>('CHAT_MEDIA_AUDIT_OLDER_THAN_DAYS', '7'),
    );
    const maxAssets = Number(
      this.configService.get<string>('CHAT_MEDIA_AUDIT_MAX_ASSETS_PER_PAGE', '100'),
    );
    const maxPages = Math.max(
      1,
      Number(this.configService.get<string>('CHAT_MEDIA_AUDIT_MAX_PAGES_PER_RUN', '20')),
    );
    const deleteOrphans =
      this.configService.get<string>('CHAT_MEDIA_AUDIT_DELETE_ORPHANS', 'false') ===
      'true';

    let nextCursor: string | null = null;
    let pageCount = 0;
    let totalDeleted = 0;
    let totalFailed = 0;
    let totalOrphans = 0;

    do {
      const result = await this.conversationsService.auditOrphanedChatMediaAssets({
        actorUserId: 'scheduler',
        olderThanDays,
        maxAssets,
        deleteOrphans,
        nextCursor,
      });

      pageCount += 1;
      totalDeleted += result.summary.deletedAssets;
      totalFailed += result.summary.failedAssets;
      totalOrphans += result.summary.orphanedAssets;
      nextCursor = result.nextCursor;
    } while (nextCursor && pageCount < maxPages);

    this.logger.log(
      `Chat media scheduled audit finished pages=${pageCount} totalOrphans=${totalOrphans} totalDeleted=${totalDeleted} totalFailed=${totalFailed} hasMore=${Boolean(nextCursor)}`,
    );
  }
}