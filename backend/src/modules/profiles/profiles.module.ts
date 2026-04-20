import { Module } from '@nestjs/common';

import { CloudinaryService } from '../auth/cloudinary.service';
import { ConversationsModule } from '../conversations/conversations.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { PrismaModule } from '../prisma/prisma.module';
import { PushNotificationsModule } from '../push-notifications/push-notifications.module';
import { ProfilesController } from './profiles.controller';
import { ProfilesService } from './profiles.service';

@Module({
  imports: [
    PrismaModule,
    ConversationsModule,
    NotificationsModule,
    PushNotificationsModule,
  ],
  controllers: [ProfilesController],
  providers: [ProfilesService, CloudinaryService],
  exports: [ProfilesService],
})
export class ProfilesModule {}