import { ConflictException, Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { UserRole } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

import { PrismaService } from '../prisma/prisma.service';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { RegisterDto } from './dto/register.dto';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  async register(dto: RegisterDto) {
    const existingUser = await this.prisma.user.findUnique({
      where: { phoneE164: dto.phoneE164 },
    });

    if (existingUser) {
      throw new ConflictException('Phone number already registered');
    }

    const passwordHash = await bcrypt.hash(dto.password, 10);

    const user = await this.prisma.user.create({
      data: {
        phoneE164: dto.phoneE164,
        displayName: dto.displayName,
        passwordHash,
        role: dto.role ?? UserRole.CUSTOMER,
        cart: {
          create: {},
        },
      },
    });

    if (user.role === UserRole.SELLER) {
      await this.prisma.sellerProfile.create({
        data: {
          studioName: dto.displayName,
          userId: user.id,
        },
      });
    }

    return this.issueTokens(user.id, user.phoneE164, user.role);
  }

  async login(dto: LoginDto) {
    const user = await this.prisma.user.findUnique({
      where: { phoneE164: dto.phoneE164 },
    });

    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const isPasswordValid = await bcrypt.compare(dto.password, user.passwordHash);

    if (!isPasswordValid) {
      throw new UnauthorizedException('Invalid credentials');
    }

    return this.issueTokens(user.id, user.phoneE164, user.role);
  }

  async refresh(dto: RefreshTokenDto) {
    const tokenPayload = await this.verifyRefreshToken(dto.refreshToken);

    const storedToken = await this.prisma.refreshToken.findFirst({
      where: {
        userId: tokenPayload.sub,
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    if (!storedToken) {
      throw new UnauthorizedException('Refresh token not found');
    }

    const isValidHash = await bcrypt.compare(dto.refreshToken, storedToken.tokenHash);

    if (!isValidHash) {
      throw new UnauthorizedException('Invalid refresh token');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: tokenPayload.sub },
    });

    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    await this.prisma.refreshToken.delete({ where: { id: storedToken.id } });

    return this.issueTokens(user.id, user.phoneE164, user.role);
  }

  private async issueTokens(userId: string, phoneE164: string, role: UserRole) {
    const accessToken = await this.jwtService.signAsync(
      { sub: userId, phoneE164, role },
      {
        secret: this.configService.get<string>('JWT_ACCESS_SECRET', 'change-me-access'),
        expiresIn: this.configService.get<string>('JWT_ACCESS_EXPIRES_IN', '15m') as any,
      },
    );

    const refreshToken = await this.jwtService.signAsync(
      { sub: userId, phoneE164, role, type: 'refresh' },
      {
        secret: this.configService.get<string>('JWT_REFRESH_SECRET', 'change-me-refresh'),
        expiresIn: this.configService.get<string>('JWT_REFRESH_EXPIRES_IN', '7d') as any,
      },
    );

    const refreshTokenHash = await bcrypt.hash(refreshToken, 10);
    const refreshExpiresIn = this.configService.get<string>('JWT_REFRESH_EXPIRES_IN', '7d');
    const expiresAt = this.resolveRefreshExpiry(refreshExpiresIn);

    await this.prisma.refreshToken.create({
      data: {
        userId,
        tokenHash: refreshTokenHash,
        expiresAt,
      },
    });

    return {
      success: true,
      message: 'Authentication successful',
      data: {
        accessToken,
        refreshToken,
      },
    };
  }

  private async verifyRefreshToken(token: string) {
    try {
      return await this.jwtService.verifyAsync(token, {
        secret: this.configService.get<string>('JWT_REFRESH_SECRET', 'change-me-refresh'),
      });
    } catch {
      throw new UnauthorizedException('Invalid refresh token');
    }
  }

  private resolveRefreshExpiry(expiresIn: string) {
    if (expiresIn.endsWith('d')) {
      const days = Number(expiresIn.replace('d', ''));
      return new Date(Date.now() + days * 24 * 60 * 60 * 1000);
    }

    if (expiresIn.endsWith('h')) {
      const hours = Number(expiresIn.replace('h', ''));
      return new Date(Date.now() + hours * 60 * 60 * 1000);
    }

    return new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
  }
}
