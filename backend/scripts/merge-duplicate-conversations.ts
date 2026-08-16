import 'reflect-metadata';

import { NestFactory } from '@nestjs/core';

import { AppModule } from '../src/app.module';
import { ConversationsService } from '../src/modules/conversations/conversations.service';

async function run() {
  const apply = process.argv.slice(2).includes('--apply');
  const app = await NestFactory.createApplicationContext(AppModule, {
    logger: ['log', 'warn', 'error'],
  });

  try {
    const conversationsService = app.get(ConversationsService);
    const result = await conversationsService.mergeDuplicateConversations({
      apply,
    });

    console.log(JSON.stringify(result, null, 2));

    if (!apply && result.summary.pairsWithDuplicates > 0) {
      console.log(
        `\nDry run only — no changes made. Re-run with --apply to merge ${result.summary.pairsWithDuplicates} pair(s) (${result.summary.conversationsMerged} conversation(s), ${result.summary.messagesMoved} message(s)).`,
      );
    }
  } finally {
    await app.close();
  }
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
