import { ValidationPipe } from '@nestjs/common';
import { NestFactory, HttpAdapterHost } from '@nestjs/core';
import { ConfigService } from '@nestjs/config';

import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/logging/all-exceptions.filter';
import { HttpLoggingInterceptor } from './common/logging/http-logging.interceptor';
import { JsonFileLoggerService } from './common/logging/json-file-logger.service';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    cors: true,
  });

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


