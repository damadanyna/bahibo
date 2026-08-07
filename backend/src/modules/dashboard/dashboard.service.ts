import { Injectable } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { LogsQueryDto } from './dto/logs-query.dto';

type LogLevel = 'info' | 'warn' | 'error';

const LEVEL_SEVERITY: Record<LogLevel, string> = {
  error: 'critique',
  warn: 'moyen',
  info: 'faible',
};

@Injectable()
export class DashboardService {
  constructor(private readonly prisma: PrismaService) {}

  async getStats() {
    const [levelGroups, totalLogs, messagesSent, messagesDelivered, messagesSeen] = await Promise.all([
      this.prisma.serverLog.groupBy({ by: ['level'], _count: { _all: true } }),
      this.prisma.serverLog.count(),
      this.prisma.chatMessage.count(),
      this.prisma.chatMessage.count({ where: { deliveredAt: { not: null } } }),
      this.prisma.chatMessage.count({ where: { readAt: { not: null } } }),
    ]);

    const byLevel: Record<LogLevel, number> = { info: 0, warn: 0, error: 0 };
    for (const group of levelGroups) {
      if (group.level === 'info' || group.level === 'warn' || group.level === 'error') {
        byLevel[group.level] = group._count._all;
      }
    }

    return {
      logs: {
        total: totalLogs,
        success: totalLogs - byLevel.error,
        error: byLevel.error,
        severity: {
          critique: byLevel.error,
          moyen: byLevel.warn,
          faible: byLevel.info,
        },
      },
      messages: {
        sent: messagesSent,
        delivered: messagesDelivered,
        seen: messagesSeen,
      },
    };
  }

  async listLogs(query: LogsQueryDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 25;

    const where: { userId?: string; level?: string } = {};
    if (query.userId) where.userId = query.userId;
    if (query.level) where.level = query.level;

    const [items, total] = await Promise.all([
      this.prisma.serverLog.findMany({
        where,
        orderBy: { timestamp: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
        include: {
          user: { select: { id: true, displayName: true, phoneE164: true, role: true } },
        },
      }),
      this.prisma.serverLog.count({ where }),
    ]);

    return {
      items: items.map((log) => ({
        id: log.id,
        timestamp: log.timestamp,
        level: log.level,
        severity: LEVEL_SEVERITY[log.level as LogLevel] ?? 'faible',
        type: log.type,
        userId: log.userId,
        user: log.user,
        payload: log.payload,
      })),
      page,
      limit,
      total,
      totalPages: Math.max(1, Math.ceil(total / limit)),
    };
  }

  async listLogsByUser() {
    const groups = await this.prisma.serverLog.groupBy({
      by: ['userId', 'level'],
      _count: { _all: true },
      _max: { timestamp: true },
    });

    type UserAggregate = {
      userId: string | null;
      total: number;
      info: number;
      warn: number;
      error: number;
      lastActivity: Date | null;
    };

    const byUser = new Map<string | null, UserAggregate>();

    for (const group of groups) {
      const key = group.userId;
      const entry = byUser.get(key) ?? {
        userId: key,
        total: 0,
        info: 0,
        warn: 0,
        error: 0,
        lastActivity: null,
      };

      entry.total += group._count._all;
      if (group.level === 'info' || group.level === 'warn' || group.level === 'error') {
        entry[group.level] += group._count._all;
      }
      if (group._max.timestamp && (!entry.lastActivity || group._max.timestamp > entry.lastActivity)) {
        entry.lastActivity = group._max.timestamp;
      }

      byUser.set(key, entry);
    }

    const userIds = [...byUser.keys()].filter((id): id is string => Boolean(id));
    const users = userIds.length
      ? await this.prisma.user.findMany({
          where: { id: { in: userIds } },
          select: { id: true, displayName: true, phoneE164: true, role: true },
        })
      : [];
    const userMap = new Map(users.map((user) => [user.id, user]));

    return [...byUser.values()]
      .map((entry) => ({
        userId: entry.userId,
        user: entry.userId ? userMap.get(entry.userId) ?? null : null,
        total: entry.total,
        success: entry.total - entry.error,
        error: entry.error,
        severity: {
          critique: entry.error,
          moyen: entry.warn,
          faible: entry.info,
        },
        lastActivity: entry.lastActivity,
      }))
      .sort((a, b) => b.total - a.total);
  }
}
