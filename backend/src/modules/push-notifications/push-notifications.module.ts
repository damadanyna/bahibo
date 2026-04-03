import { Module } from '@nestjs/common';

import { PrismaModule } from '../prisma/prisma.module';
import { PushNotificationsService } from './push-notifications.service';

@Module({
  imports: [PrismaModule],
  providers: [PushNotificationsService],
  exports: [PushNotificationsService],
})
export class PushNotificationsModule {}