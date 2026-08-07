import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Cron, CronExpression } from '@nestjs/schedule';
import type { Prisma } from '@prisma/client';
import { promises as fs } from 'fs';
import * as path from 'path';

import { PrismaService } from '../../modules/prisma/prisma.service';
import type { ServerLogEntry } from './log-entry.types';

const LOG_FILE_PATTERN = /^server-(\d{4}-\d{2}-\d{2})\.jsonl$/;
const DEFAULT_RETENTION_DAYS = 14;
const DEFAULT_LOOKBACK_DAYS = 7;

/**
 * Writes structured server logs (HTTP requests + errors) as JSON Lines,
 * one file per day, so QA/admins can inspect real server behaviour instead
 * of only client-side QA events. Files are pruned after LOG_RETENTION_DAYS.
 */
@Injectable()
export class JsonFileLoggerService implements OnModuleInit {
  private readonly logger = new Logger(JsonFileLoggerService.name);
  private readonly logsDir: string;
  private readonly retentionDays: number;

  constructor(
    private readonly configService: ConfigService,
    private readonly prisma: PrismaService,
  ) {
    this.logsDir = this.configService.get<string>(
      'LOG_DIR',
      path.resolve(process.cwd(), 'logs'),
    );
    this.retentionDays = Number(
      this.configService.get<string>(
        'LOG_RETENTION_DAYS',
        String(DEFAULT_RETENTION_DAYS),
      ),
    );
  }

  async onModuleInit(): Promise<void> {
    await fs.mkdir(this.logsDir, { recursive: true });
  }

  write(entry: ServerLogEntry): void {
    const filePath = this.filePathForDate(entry.timestamp);
    fs.appendFile(filePath, `${JSON.stringify(entry)}\n`, 'utf8').catch(
      (error) => {
        this.logger.error(
          `Failed to write server log entry: ${(error as Error).message}`,
        );
      },
    );

    this.persistToDatabase(entry);
  }

  /**
   * Best-effort DB mirror of the entry so it's queryable/joinable by userId
   * with SQL. Never awaited from write(): a slow or failing DB must not add
   * latency to the request the log entry describes, and the JSONL file
   * already is the durable copy.
   */
  private persistToDatabase(entry: ServerLogEntry): void {
    this.prisma.serverLog
      .create({
        data: {
          timestamp: new Date(entry.timestamp),
          level: entry.level,
          type: entry.type,
          userId: entry.userId,
          payload: entry as unknown as Prisma.InputJsonValue,
        },
      })
      .catch((error) => {
        this.logger.error(
          `Failed to persist server log entry to database: ${(error as Error).message}`,
        );
      });
  }

  async readRecentEntries(options?: {
    limit?: number;
    level?: 'error' | 'all';
    /** When set, only entries produced by this user's own requests are returned. */
    userId?: string;
  }): Promise<ServerLogEntry[]> {
    const limit = options?.limit ?? 200;
    const level = options?.level ?? 'all';
    const userId = options?.userId;

    const entries: ServerLogEntry[] = [];

    for (let dayOffset = 0; dayOffset < DEFAULT_LOOKBACK_DAYS; dayOffset += 1) {
      const date = new Date();
      date.setUTCDate(date.getUTCDate() - dayOffset);
      const filePath = this.filePathForDate(date.toISOString());

      const fileEntries = await this.readLogFile(filePath);
      for (const fileEntry of fileEntries) {
        if (level === 'error' && fileEntry.level !== 'error') {
          continue;
        }
        if (userId != null && fileEntry.userId !== userId) {
          continue;
        }
        entries.push(fileEntry);
      }

      if (entries.length >= limit) {
        break;
      }
    }

    return entries
      .sort((a, b) => b.timestamp.localeCompare(a.timestamp))
      .slice(0, limit);
  }

  @Cron(CronExpression.EVERY_DAY_AT_3AM)
  async pruneOldLogFiles(): Promise<void> {
    try {
      const files = await fs.readdir(this.logsDir);
      const cutoff = Date.now() - this.retentionDays * 24 * 60 * 60 * 1000;

      for (const file of files) {
        const match = LOG_FILE_PATTERN.exec(file);
        if (!match) {
          continue;
        }
        const fileDate = new Date(`${match[1]}T00:00:00Z`).getTime();
        if (Number.isFinite(fileDate) && fileDate < cutoff) {
          await fs.unlink(path.join(this.logsDir, file)).catch(() => {
            // Best effort cleanup only.
          });
        }
      }
    } catch (error) {
      this.logger.error(
        `Failed to prune old server logs: ${(error as Error).message}`,
      );
    }
  }

  @Cron(CronExpression.EVERY_DAY_AT_3AM)
  async pruneOldServerLogRows(): Promise<void> {
    try {
      const cutoff = new Date(
        Date.now() - this.retentionDays * 24 * 60 * 60 * 1000,
      );
      await this.prisma.serverLog.deleteMany({
        where: { timestamp: { lt: cutoff } },
      });
    } catch (error) {
      this.logger.error(
        `Failed to prune old server log rows: ${(error as Error).message}`,
      );
    }
  }

  private async readLogFile(filePath: string): Promise<ServerLogEntry[]> {
    try {
      const content = await fs.readFile(filePath, 'utf8');
      const entries: ServerLogEntry[] = [];
      for (const line of content.split('\n')) {
        const trimmedLine = line.trim();
        if (trimmedLine.length === 0) {
          continue;
        }
        try {
          entries.push(JSON.parse(trimmedLine) as ServerLogEntry);
        } catch {
          // Skip a malformed line rather than failing the whole read.
        }
      }
      return entries;
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === 'ENOENT') {
        return [];
      }
      this.logger.error(
        `Failed to read server log file ${filePath}: ${(error as Error).message}`,
      );
      return [];
    }
  }

  private filePathForDate(isoTimestamp: string): string {
    const datePart = isoTimestamp.slice(0, 10);
    return path.join(this.logsDir, `server-${datePart}.jsonl`);
  }
}
