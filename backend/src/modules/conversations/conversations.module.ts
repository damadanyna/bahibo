import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ConfigModule, ConfigService } from '@nestjs/config';

import { CloudinaryService } from '../auth/cloudinary.service';
import { PrismaModule } from '../prisma/prisma.module';
import { PushNotificationsModule } from '../push-notifications/push-notifications.module';
import { ConversationsController } from './conversations.controller';
import { ConversationsMediaAuditScheduler } from './conversations-media-audit.scheduler';
import { ConversationsRealtimeGateway } from './realtime/conversations-realtime.gateway';
import { ConversationsService } from './conversations.service';

@Module({
  imports: [
    PrismaModule,
    PushNotificationsModule,
    ConfigModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        secret: configService.get<string>('JWT_ACCESS_SECRET', 'change-me-access'),
      }),
    }),
  ],
  controllers: [ConversationsController],
  providers: [
    ConversationsService,
    ConversationsRealtimeGateway,
    ConversationsMediaAuditScheduler,
    CloudinaryService,
  ],
  exports: [ConversationsService, ConversationsRealtimeGateway],
})
export class ConversationsModule {}