import { ArgumentsHost, Catch, HttpException, HttpStatus } from '@nestjs/common';
import { BaseExceptionFilter, HttpAdapterHost } from '@nestjs/core';
import type { Request } from 'express';

import { JsonFileLoggerService } from './json-file-logger.service';
import { redactSensitiveData } from './redact';

type AuthenticatedRequest = Request & { user?: { userId?: string } };

/**
 * Logs every thrown exception as JSON before delegating to Nest's default
 * BaseExceptionFilter, which keeps the existing HTTP response format intact.
 */
@Catch()
export class AllExceptionsFilter extends BaseExceptionFilter {
  constructor(
    httpAdapterHost: HttpAdapterHost,
    private readonly jsonFileLogger: JsonFileLoggerService,
  ) {
    super(httpAdapterHost.httpAdapter);
  }

  catch(exception: unknown, host: ArgumentsHost): void {
    if (host.getType() === 'http') {
      this.logException(exception, host);
    }
    super.catch(exception, host);
  }

  private logException(exception: unknown, host: ArgumentsHost): void {
    const httpContext = host.switchToHttp();
    const request = httpContext.getRequest<AuthenticatedRequest>();
    const statusCode =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;
    const message =
      exception instanceof Error ? exception.message : String(exception);
    const stack = exception instanceof Error ? (exception.stack ?? null) : null;

    this.jsonFileLogger.write({
      timestamp: new Date().toISOString(),
      level: 'error',
      type: 'error',
      method: request.method,
      path: request.originalUrl ?? request.url,
      statusCode,
      message,
      stack,
      userId: request.user?.userId ?? null,
      ip: request.ip ?? null,
      body: redactSensitiveData(request.body),
    });
  }
}
