import { Module } from '@nestjs/common';

import { PrismaModule } from '../../modules/prisma/prisma.module';
import { JsonFileLoggerService } from './json-file-logger.service';

@Module({
  imports: [PrismaModule],
  providers: [JsonFileLoggerService],
  exports: [JsonFileLoggerService],
})
export class LoggingModule {}
