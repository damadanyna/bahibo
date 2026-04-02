import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(configService: ConfigService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.get<string>('JWT_ACCESS_SECRET', 'change-me-access'),
    });
  }

  validate(payload: { sub: string; phoneE164: string; role: string }) {
    return {
      userId: payload.sub,
      phoneE164: payload.phoneE164,
      role: payload.role,
    };
  }
}
