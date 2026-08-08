import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';

import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    configService: ConfigService,
    private readonly prisma: PrismaService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.get<string>('JWT_ACCESS_SECRET', 'change-me-access'),
    });
  }

  /**
   * Deleted accounts must lose access immediately, not just once their
   * (short-lived) access token happens to expire — so this checks
   * deletedAt on every request rather than trusting the JWT payload alone.
   */
  async validate(payload: { sub: string; phoneE164: string; role: string }) {
    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
      select: { deletedAt: true },
    });

    if (!user || user.deletedAt != null) {
      throw new UnauthorizedException('Account no longer available');
    }

    return {
      userId: payload.sub,
      phoneE164: payload.phoneE164,
      role: payload.role,
    };
  }
}
