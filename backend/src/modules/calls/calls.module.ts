import { Module } from '@nestjs/common';

import { ConversationsModule } from '../conversations/conversations.module';
import { LivekitModule } from '../livekit/livekit.module';
import { PrismaModule } from '../prisma/prisma.module';
import { PushNotificationsModule } from '../push-notifications/push-notifications.module';
import { CallsController } from './calls.controller';
import { CallsService } from './calls.service';

@Module({
  imports: [PrismaModule, ConversationsModule, PushNotificationsModule, LivekitModule],
  controllers: [CallsController],
  providers: [CallsService],
})
export class CallsModule {}
