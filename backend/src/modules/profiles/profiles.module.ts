import { Module } from '@nestjs/common';

import { CloudinaryService } from '../auth/cloudinary.service';
import { ConversationsModule } from '../conversations/conversations.module';
import { PrismaModule } from '../prisma/prisma.module';
import { ProfilesController } from './profiles.controller';
import { ProfilesService } from './profiles.service';

@Module({
  imports: [PrismaModule, ConversationsModule],
  controllers: [ProfilesController],
  providers: [ProfilesService, CloudinaryService],
  exports: [ProfilesService],
})
export class ProfilesModule {}