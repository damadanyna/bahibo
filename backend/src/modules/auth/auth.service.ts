import {
  BadRequestException,
  ConflictException,
  HttpException,
  HttpStatus,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService, JwtSignOptions } from '@nestjs/jwt';
import { UserRole } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

import { PrismaService } from '../prisma/prisma.service';
import { ProfilesService } from '../profiles/profiles.service';
import { PushNotificationsService } from '../push-notifications/push-notifications.service';
import { CloudinaryService } from './cloudinary.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDeviceTokenDto } from './dto/register-device-token.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { RegisterDto } from './dto/register.dto';
import { RequestOtpDto } from './dto/request-otp.dto';
import { UploadProfileImageDto } from './dto/upload-profile-image.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly profilesService: ProfilesService,
    private readonly pushNotificationsService: PushNotificationsService,
    private readonly cloudinaryService: CloudinaryService,
  ) {}

  async requestOtp(dto: RequestOtpDto) {
    const latestChallenge = await this.prisma.phoneOtpChallenge.findFirst({
      where: {
        phoneE164: dto.phoneE164,
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    if (latestChallenge && Date.now() - latestChallenge.createdAt.getTime() < 45_000) {
      throw new HttpException(
        'Please wait before requesting another OTP',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    await this.prisma.phoneOtpChallenge.deleteMany({
      where: {
        phoneE164: dto.phoneE164,
        verifiedAt: null,
      },
    });

    const otpCode = this.generateOtpCode();
    const codeHash = await bcrypt.hash(otpCode, 10);
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000);

    await this.prisma.phoneOtpChallenge.create({
      data: {
        phoneE164: dto.phoneE164,
        countryName: dto.countryName,
        countryDialCode: dto.countryDialCode,
        codeHash,
        expiresAt,
      },
    });

    const deliveryMode = await this.sendOtpCode(
      dto.phoneE164,
      otpCode,
      dto.appSignature,
    );

    return {
      success: true,
      message: 'OTP sent successfully',
      data: {
        phoneE164: dto.phoneE164,
        countryName: dto.countryName,
        countryDialCode: dto.countryDialCode,
        expiresInSeconds: 300,
        resendAvailableInSeconds: 45,
        deliveryMode,
        autoDetectionReady: Boolean(dto.appSignature),
        debugCode: deliveryMode === 'console' ? otpCode : null,
      },
    };
  }

  async verifyOtp(dto: VerifyOtpDto) {
    const challenge = await this.prisma.phoneOtpChallenge.findFirst({
      where: {
        phoneE164: dto.phoneE164,
        verifiedAt: null,
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    if (!challenge || challenge.expiresAt.getTime() < Date.now()) {
      throw new UnauthorizedException('OTP expired or not found');
    }

    if (challenge.attempts >= 5) {
      throw new HttpException(
        'Too many invalid OTP attempts',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    const isValid = await bcrypt.compare(dto.otpCode, challenge.codeHash);

    if (!isValid) {
      await this.prisma.phoneOtpChallenge.update({
        where: { id: challenge.id },
        data: {
          attempts: {
            increment: 1,
          },
        },
      });

      throw new UnauthorizedException('Invalid OTP code');
    }

    await this.prisma.phoneOtpChallenge.update({
      where: { id: challenge.id },
      data: {
        verifiedAt: new Date(),
      },
    });

    const existingUser = await this.prisma.user.findUnique({
      where: { phoneE164: challenge.phoneE164 },
    });

    if (existingUser) {
      const authResult = await this.issueTokens(existingUser.id);

      return {
        success: true,
        message: 'Phone number verified successfully',
        data: {
          verified: true,
          authenticated: true,
          hasAccount: true,
          phoneE164: challenge.phoneE164,
          countryName: challenge.countryName,
          countryDialCode: challenge.countryDialCode,
          ...authResult.data,
        },
      };
    }

    return {
      success: true,
      message: 'Phone number verified successfully',
      data: {
        verified: true,
        authenticated: false,
        hasAccount: false,
        phoneE164: challenge.phoneE164,
        countryName: challenge.countryName,
        countryDialCode: challenge.countryDialCode,
      },
    };
  }

  async uploadProfileImage(file: Express.Multer.File | undefined, dto: UploadProfileImageDto) {
    if (!file) {
      throw new BadRequestException('Profile image file is required');
    }

    const latestVerifiedChallenge = await this.prisma.phoneOtpChallenge.findFirst({
      where: {
        phoneE164: dto.phoneE164,
        verifiedAt: {
          not: null,
        },
      },
      orderBy: {
        verifiedAt: 'desc',
      },
    });

    if (!latestVerifiedChallenge) {
      throw new BadRequestException('Phone number must be verified before uploading profile image');
    }

    const uploadResult = await this.cloudinaryService.uploadProfileImage(file, dto.phoneE164);

    return {
      success: true,
      message: 'Profile image uploaded successfully',
      data: {
        ...uploadResult,
        avatarUrl: uploadResult.imageUrl,
      },
    };
  }

  async register(dto: RegisterDto) {
    const latestVerifiedChallenge = await this.prisma.phoneOtpChallenge.findFirst({
      where: {
        phoneE164: dto.phoneE164,
        verifiedAt: {
          not: null,
        },
      },
      orderBy: {
        verifiedAt: 'desc',
      },
    });

    if (!latestVerifiedChallenge) {
      throw new BadRequestException('Phone number must be verified before registration');
    }

    const existingUser = await this.prisma.user.findUnique({
      where: { phoneE164: dto.phoneE164 },
    });

    if (existingUser) {
      return this.issueTokens(existingUser.id);
    }

    const passwordHash = await bcrypt.hash(
      `otp-only:${dto.phoneE164}:${Date.now()}`,
      10,
    );

    const user = await this.prisma.user.create({
      data: {
        phoneE164: dto.phoneE164,
        countryName: dto.countryName ?? latestVerifiedChallenge.countryName,
        countryDialCode: dto.countryDialCode ?? latestVerifiedChallenge.countryDialCode,
        displayName: dto.displayName,
        avatarUrl: dto.avatarUrl,
        passwordHash,
        role: dto.role ?? UserRole.CUSTOMER,
        isVerified: true,
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

    return this.issueTokens(user.id);
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

    return this.issueTokens(user.id);
  }

  async refresh(dto: RefreshTokenDto) {
    const tokenPayload = await this.verifyRefreshToken(dto.refreshToken);

    const storedToken = await this.findStoredRefreshToken(tokenPayload.sub, dto.refreshToken);

    if (!storedToken) {
      throw new UnauthorizedException('Refresh token not found');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: tokenPayload.sub },
    });

    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    await this.prisma.refreshToken.delete({ where: { id: storedToken.id } });

    return this.issueTokens(user.id);
  }

  async logout(dto: RefreshTokenDto) {
    const tokenPayload = await this.verifyRefreshToken(dto.refreshToken);
    const storedToken = await this.findStoredRefreshToken(tokenPayload.sub, dto.refreshToken);

    if (!storedToken) {
      throw new UnauthorizedException('Refresh token not found');
    }

    await this.prisma.refreshToken.delete({ where: { id: storedToken.id } });

    return {
      success: true,
      message: 'Logged out successfully',
      data: {
        loggedOut: true,
      },
    };
  }

  getAuthenticatedUser(userId: string) {
    return this.profilesService.getCurrentUserProfile(userId);
  }

  async registerDeviceToken(userId: string, dto: RegisterDeviceTokenDto) {
    await this.pushNotificationsService.registerDeviceToken(userId, dto);

    return {
      tokenRegistered: true,
    };
  }

  private async issueTokens(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
    });

    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    const accessToken = await this.jwtService.signAsync(
      { sub: user.id, phoneE164: user.phoneE164, role: user.role },
      {
        secret: this.configService.get<string>('JWT_ACCESS_SECRET', 'change-me-access'),
        expiresIn: this.configService.get<string>('JWT_ACCESS_EXPIRES_IN', '15m') as JwtSignOptions['expiresIn'],
      },
    );

    const refreshToken = await this.jwtService.signAsync(
      { sub: user.id, phoneE164: user.phoneE164, role: user.role, type: 'refresh' },
      {
        secret: this.configService.get<string>('JWT_REFRESH_SECRET', 'change-me-refresh'),
        expiresIn: this.configService.get<string>('JWT_REFRESH_EXPIRES_IN', '30d') as JwtSignOptions['expiresIn'],
      },
    );

    const refreshTokenHash = await bcrypt.hash(refreshToken, 10);
    const refreshExpiresIn = this.configService.get<string>('JWT_REFRESH_EXPIRES_IN', '30d');
    const expiresAt = this.resolveRefreshExpiry(refreshExpiresIn);

    await this.prisma.refreshToken.create({
      data: {
        userId: user.id,
        tokenHash: refreshTokenHash,
        expiresAt,
      },
    });

    const profile = await this.profilesService.getCurrentUserProfile(user.id);

    return {
      success: true,
      message: 'Authentication successful',
      data: {
        accessToken,
        refreshToken,
        user: profile,
      },
    };
  }

  private async verifyRefreshToken(token: string) {
    try {
      const payload = await this.jwtService.verifyAsync<{ sub: string; type?: string }>(token, {
        secret: this.configService.get<string>('JWT_REFRESH_SECRET', 'change-me-refresh'),
      });

      if (payload.type !== 'refresh') {
        throw new UnauthorizedException('Invalid refresh token');
      }

      return payload;
    } catch {
      throw new UnauthorizedException('Invalid refresh token');
    }
  }

  private async findStoredRefreshToken(userId: string, refreshToken: string) {
    await this.prisma.refreshToken.deleteMany({
      where: {
        userId,
        expiresAt: {
          lt: new Date(),
        },
      },
    });

    const storedTokens = await this.prisma.refreshToken.findMany({
      where: {
        userId,
        expiresAt: {
          gt: new Date(),
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    for (const storedToken of storedTokens) {
      const isValidHash = await bcrypt.compare(refreshToken, storedToken.tokenHash);

      if (isValidHash) {
        return storedToken;
      }
    }

    return null;
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

  private generateOtpCode() {
    return String(Math.floor(100000 + Math.random() * 900000));
  }

  private async sendOtpCode(
    phoneE164: string,
    otpCode: string,
    appSignature?: string,
  ) {
    const accountSid = this.configService.get<string>('TWILIO_ACCOUNT_SID');
    const authToken = this.configService.get<string>('TWILIO_AUTH_TOKEN');
    const fromNumber = this.configService.get<string>('TWILIO_FROM_NUMBER');
    const smsBody = this.buildOtpSmsBody(otpCode, appSignature);

    if (!accountSid || !authToken || !fromNumber) {
      console.log(`[OTP][DEV] ${phoneE164} -> ${smsBody}`);
      return 'console';
    }

    const body = new URLSearchParams({
      To: phoneE164,
      From: fromNumber,
      Body: smsBody,
    });

    const response = await fetch(
      `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`,
      {
        method: 'POST',
        headers: {
          Authorization: `Basic ${Buffer.from(`${accountSid}:${authToken}`).toString('base64')}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body,
      },
    );

    if (!response.ok) {
      throw new BadRequestException('Unable to send OTP via SMS provider');
    }

    return 'sms';
  }

  private buildOtpSmsBody(otpCode: string, appSignature?: string) {
    const normalizedSignature = appSignature?.trim();

    if (normalizedSignature) {
      return `<#> Bahibo verification code ${otpCode}\n${normalizedSignature}`;
    }

    return `Bahibo verification code ${otpCode}. Do not share it.`;
  }
}
