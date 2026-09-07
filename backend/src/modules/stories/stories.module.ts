import { Module } from '@nestjs/common';

import { CloudinaryService } from '../auth/cloudinary.service';
import { ConversationsModule } from '../conversations/conversations.module';
import { PrismaModule } from '../prisma/prisma.module';
import { PushNotificationsModule } from '../push-notifications/push-notifications.module';
import { StoriesController } from './stories.controller';
import { StoriesService } from './stories.service';

@Module({
  imports: [PrismaModule, ConversationsModule, PushNotificationsModule],
  controllers: [StoriesController],
  providers: [StoriesService, CloudinaryService],
  exports: [StoriesService],
})
export class StoriesModule {}
