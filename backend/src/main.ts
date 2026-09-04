import { ValidationPipe } from '@nestjs/common';
import { NestFactory, HttpAdapterHost } from '@nestjs/core';
import { ConfigService } from '@nestjs/config';
import { NestExpressApplication } from '@nestjs/platform-express';

import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/logging/all-exceptions.filter';
import { HttpLoggingInterceptor } from './common/logging/http-logging.interceptor';
import { JsonFileLoggerService } from './common/logging/json-file-logger.service';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    cors: true,
  });

  // Behind nginx: read the real client IP from X-Forwarded-For so the
  // rate limiter and logs do not see 127.0.0.1 for everyone.
  app.set('trust proxy', 1);

  // Express defaults to 100 KB, which rejected the mobile app's event-log
  // batches (200 events ~ 140 KB) and stalled that sync forever.
  app.useBodyParser('json', { limit: '1mb' });

  app.setGlobalPrefix('api/v1');
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );

  const jsonFileLogger = app.get(JsonFileLoggerService);
  app.useGlobalInterceptors(new HttpLoggingInterceptor(jsonFileLogger));
  app.useGlobalFilters(
    new AllExceptionsFilter(app.get(HttpAdapterHost), jsonFileLogger),
  );

  const configService = app.get(ConfigService);
  const host = configService.get<string>('HOST', '0.0.0.0');
  const port = configService.get<number>('PORT', 4000);

  await app.listen(port, host);
  console.log(`BANAY backend running on http://${host}:${port}/api/v1`);
}

bootstrap();


