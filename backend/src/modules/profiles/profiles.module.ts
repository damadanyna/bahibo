import { Module } from '@nestjs/common';

import { CloudinaryService } from '../auth/cloudinary.service';
import { ConversationsModule } from '../conversations/conversations.module';
import { LivekitModule } from '../livekit/livekit.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { PrismaModule } from '../prisma/prisma.module';
import { PushNotificationsModule } from '../push-notifications/push-notifications.module';
import { ProfilesController } from './profiles.controller';
import { ProfilesLiveScheduler } from './profiles-live.scheduler';
import { ProfilesService } from './profiles.service';

@Module({
  imports: [
    PrismaModule,
    ConversationsModule,
    NotificationsModule,
    PushNotificationsModule,
    LivekitModule,
  ],
  controllers: [ProfilesController],
  providers: [ProfilesService, ProfilesLiveScheduler, CloudinaryService],
  exports: [ProfilesService],
})
export class ProfilesModule {}