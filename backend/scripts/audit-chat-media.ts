import 'reflect-metadata';

import { NestFactory } from '@nestjs/core';

import { AppModule } from '../src/app.module';
import { ConversationsService } from '../src/modules/conversations/conversations.service';

type CliOptions = {
  deleteOrphans: boolean;
  olderThanDays: number;
  maxAssets: number;
  maxPages: number;
};

function parseCliOptions(argv: string[]): CliOptions {
  const options: CliOptions = {
    deleteOrphans: false,
    olderThanDays: 7,
    maxAssets: 100,
    maxPages: 20,
  };

  for (const argument of argv) {
    if (argument === '--delete') {
      options.deleteOrphans = true;
      continue;
    }

    if (argument.startsWith('--older-than-days=')) {
      options.olderThanDays = Number(argument.split('=')[1] ?? '7');
      continue;
    }

    if (argument.startsWith('--max-assets=')) {
      options.maxAssets = Number(argument.split('=')[1] ?? '100');
      continue;
    }

    if (argument.startsWith('--max-pages=')) {
      options.maxPages = Number(argument.split('=')[1] ?? '20');
    }
  }

  return options;
}

async function run() {
  const options = parseCliOptions(process.argv.slice(2));
  const app = await NestFactory.createApplicationContext(AppModule, {
    logger: ['log', 'warn', 'error'],
  });

  try {
    const conversationsService = app.get(ConversationsService);
    let nextCursor: string | null = null;
    let pageCount = 0;
    let totalDeleted = 0;
    let totalFailed = 0;
    let totalOrphans = 0;

    do {
      const result = await conversationsService.auditOrphanedChatMediaAssets({
        actorUserId: 'cli',
        deleteOrphans: options.deleteOrphans,
        olderThanDays: options.olderThanDays,
        maxAssets: options.maxAssets,
        nextCursor,
      });

      pageCount += 1;
      totalDeleted += result.summary.deletedAssets;
      totalFailed += result.summary.failedAssets;
      totalOrphans += result.summary.orphanedAssets;
      nextCursor = result.nextCursor;

      console.log(JSON.stringify({ page: pageCount, summary: result.summary }, null, 2));
    } while (nextCursor && pageCount < Math.max(1, options.maxPages));

    console.log(
      JSON.stringify(
        {
          pageCount,
          totalOrphans,
          totalDeleted,
          totalFailed,
          hasMore: Boolean(nextCursor),
        },
        null,
        2,
      ),
    );
  } finally {
    await app.close();
  }
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});