import {
  Body,
  Controller,
  Get,
  Post,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';

import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDeviceTokenDto } from './dto/register-device-token.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { RegisterDto } from './dto/register.dto';
import { RequestOtpDto } from './dto/request-otp.dto';
import { UploadProfileImageDto } from './dto/upload-profile-image.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { JwtAuthGuard } from './guards/jwt-auth.guard';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('otp/request')
  requestOtp(@Body() dto: RequestOtpDto) {
    return this.authService.requestOtp(dto);
  }

  @Post('otp/verify')
  verifyOtp(@Body() dto: VerifyOtpDto) {
    return this.authService.verifyOtp(dto);
  }

  @Post('profile-image')
  @UseInterceptors(FileInterceptor('image'))
  uploadProfileImage(
    @UploadedFile() file: Express.Multer.File,
    @Body() dto: UploadProfileImageDto,
  ) {
    return this.authService.uploadProfileImage(file, dto);
  }

  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @Post('refresh')
  refresh(@Body() dto: RefreshTokenDto) {
    return this.authService.refresh(dto);
  }

  @Post('logout')
  logout(@Body() dto: RefreshTokenDto) {
    return this.authService.logout(dto);
  }

  @UseGuards(JwtAuthGuard)
  @Post('device-token')
  async registerDeviceToken(
    @Req() req: { user: { userId: string } },
    @Body() dto: RegisterDeviceTokenDto,
  ) {
    return {
      success: true,
      message: 'Device token registered successfully',
      data: await this.authService.registerDeviceToken(req.user.userId, dto),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  async me(
    @Req() req: { user: { userId: string; phoneE164: string; role: string } },
  ) {
    return {
      success: true,
      message: 'Authenticated user fetched successfully',
      data: await this.authService.getAuthenticatedUser(req.user.userId),
    };
  }
}
