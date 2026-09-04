import { Injectable } from '@nestjs/common';
import { ThrottlerGuard } from '@nestjs/throttler';

/**
 * Global rate limiter keyed on client IP, plus the target phone number for
 * auth requests that carry one (login, OTP request / verify, register).
 *
 * Adding the phone number to the key does two things:
 * - brute force is limited per account, not only per attacker IP;
 * - if nginx ever stops forwarding X-Forwarded-For, every client shares
 *   127.0.0.1 as its IP, and without the phone in the key a handful of
 *   logins would lock the whole user base out.
 */
@Injectable()
export class AuthThrottlerGuard extends ThrottlerGuard {
  protected async getTracker(req: Record<string, any>): Promise<string> {
    const ip: string =
      (Array.isArray(req.ips) && req.ips.length > 0 ? req.ips[0] : req.ip) ??
      'unknown';
    const phone = this.readPhone(req.body);
    return phone ? `${ip}|${phone}` : ip;
  }

  private readPhone(body: unknown): string | null {
    if (!body || typeof body !== 'object') {
      return null;
    }
    const value = (body as Record<string, unknown>).phoneE164;
    return typeof value === 'string' && value.trim() !== '' ? value.trim() : null;
  }
}
