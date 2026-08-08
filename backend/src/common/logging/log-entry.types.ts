export type LogLevel = 'info' | 'warn' | 'error';

export type HttpRequestLogEntry = {
  timestamp: string;
  level: LogLevel;
  type: 'http_request';
  method: string;
  path: string;
  statusCode: number;
  durationMs: number;
  userId: string | null;
  ip: string | null;
  userAgent: string | null;
  responseBody: unknown;
};

export type ErrorLogEntry = {
  timestamp: string;
  level: 'error';
  type: 'error';
  method: string;
  path: string;
  statusCode: number;
  message: string;
  stack: string | null;
  userId: string | null;
  ip: string | null;
  body: unknown;
};

/**
 * Message delivery/read acknowledgements happen over WebSocket, never as an
 * HTTP request, so HttpLoggingInterceptor never sees them. This entry type
 * lets the realtime gateway log them explicitly with a real timestamp.
 */
export type MessageStatusLogEntry = {
  timestamp: string;
  level: 'info';
  type: 'message_status';
  event: 'delivered' | 'read';
  conversationId: string;
  messageId: string | null;
  actorUserId: string;
  userId: string;
};

/**
 * A client-side failure (e.g. a background upload that never reached the
 * server) reported via the QA event log batch endpoint. Lets admins see
 * these in the same server log stream as real HTTP errors instead of only
 * in the per-user QA event export.
 */
export type ClientErrorLogEntry = {
  timestamp: string;
  level: LogLevel;
  type: 'client_error';
  eventName: string;
  status: string;
  source: string;
  userId: string | null;
  parameters: unknown;
};

export type ServerLogEntry =
  | HttpRequestLogEntry
  | ErrorLogEntry
  | MessageStatusLogEntry
  | ClientErrorLogEntry;
