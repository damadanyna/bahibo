import { Module } from '@nestjs/common';

import { CloudinaryService } from '../auth/cloudinary.service';
import { PrismaModule } from '../prisma/prisma.module';
import { ProfilesController } from './profiles.controller';
import { ProfilesService } from './profiles.service';

@Module({
  imports: [PrismaModule],
  controllers: [ProfilesController],
  providers: [ProfilesService, CloudinaryService],
  exports: [ProfilesService],
})
export class ProfilesModule {}