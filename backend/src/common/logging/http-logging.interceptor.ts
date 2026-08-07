import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import type { Request, Response } from 'express';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';

import { JsonFileLoggerService } from './json-file-logger.service';
import { redactSensitiveData } from './redact';

type AuthenticatedRequest = Request & { user?: { userId?: string } };

/**
 * Logs every successful HTTP request as JSON (method, path, status, duration,
 * response body). Errors are logged separately by AllExceptionsFilter, which
 * is the only place that knows the final status code Nest will actually send
 * back.
 */
@Injectable()
export class HttpLoggingInterceptor implements NestInterceptor {
  constructor(private readonly jsonFileLogger: JsonFileLoggerService) {}

  intercept(
    context: ExecutionContext,
    next: CallHandler,
  ): Observable<unknown> {
    if (context.getType() !== 'http') {
      return next.handle();
    }

    const httpContext = context.switchToHttp();
    const request = httpContext.getRequest<AuthenticatedRequest>();
    const startedAt = Date.now();

    return next.handle().pipe(
      tap((responseBody) => {
        const response = httpContext.getResponse<Response>();
        this.jsonFileLogger.write({
          timestamp: new Date().toISOString(),
          level: response.statusCode >= 400 ? 'warn' : 'info',
          type: 'http_request',
          method: request.method,
          path: request.originalUrl ?? request.url,
          statusCode: response.statusCode,
          durationMs: Date.now() - startedAt,
          userId: request.user?.userId ?? null,
          ip: request.ip ?? null,
          userAgent: request.headers?.['user-agent'] ?? null,
          responseBody: redactSensitiveData(responseBody),
        });
      }),
    );
  }
}
