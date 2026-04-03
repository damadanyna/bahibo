import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ConfigModule, ConfigService } from '@nestjs/config';

import { PrismaModule } from '../prisma/prisma.module';
import { PushNotificationsModule } from '../push-notifications/push-notifications.module';
import { ConversationsController } from './conversations.controller';
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
  providers: [ConversationsService, ConversationsRealtimeGateway],
  exports: [ConversationsService],
})
export class ConversationsModule {}