import { Module } from '@nestjs/common';

import { PrismaModule } from '../prisma/prisma.module';
import { ShipmentsController } from './shipments.controller';
import { ShipmentsService } from './shipments.service';

@Module({
  imports: [PrismaModule],
  controllers: [ShipmentsController],
  providers: [ShipmentsService],
})
export class ShipmentsModule {}