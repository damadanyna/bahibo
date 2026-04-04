import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  Param,
  Patch,
  Post,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { ProfilesService } from './profiles.service';

@Controller('profiles')
export class ProfilesController {
  constructor(private readonly profilesService: ProfilesService) {}

  private ensureAdminAccess(role: string) {
    if (role !== 'ADMIN') {
      throw new ForbiddenException('Admin access required');
    }
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  async getMe(@Req() req: { user: { userId: string } }) {
    return {
      success: true,
      message: 'Profile fetched successfully',
      data: await this.profilesService.getCurrentUserProfile(req.user.userId),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Patch('me')
  async updateMe(
    @Req() req: { user: { userId: string } },
    @Body() dto: UpdateProfileDto,
  ) {
    return {
      success: true,
      message: 'Profile updated successfully',
      data: await this.profilesService.updateCurrentUserProfile(req.user.userId, dto),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Post('me/shop-request')
  async submitShopRequest(@Req() req: { user: { userId: string } }) {
    return {
      success: true,
      message: 'Shop request submitted successfully',
      data: await this.profilesService.submitShopRequest(req.user.userId),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Get('admin/shop-requests/pending')
  async listPendingShopRequests(
    @Req() req: { user: { userId: string; role: string } },
  ) {
    this.ensureAdminAccess(req.user.role);

    return {
      success: true,
      message: 'Pending shop requests fetched successfully',
      data: await this.profilesService.listPendingShopRequests(),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Post('admin/shop-requests/:userId/approve')
  async approveShopRequest(
    @Req() req: { user: { userId: string; role: string } },
    @Param('userId') userId: string,
  ) {
    this.ensureAdminAccess(req.user.role);

    return {
      success: true,
      message: 'Shop request approved successfully',
      data: await this.profilesService.approveShopRequest(userId),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Post('me/avatar-image')
  @UseInterceptors(FileInterceptor('image'))
  async uploadAvatarImage(
    @Req() req: { user: { userId: string } },
    @UploadedFile() file: Express.Multer.File,
  ) {
    return {
      success: true,
      message: 'Avatar image uploaded successfully',
      data: await this.profilesService.updateCurrentUserAvatarImage(
        req.user.userId,
        file,
      ),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Post('me/cover-image')
  @UseInterceptors(FileInterceptor('image'))
  async uploadCoverImage(
    @Req() req: { user: { userId: string } },
    @UploadedFile() file: Express.Multer.File,
  ) {
    return {
      success: true,
      message: 'Cover image uploaded successfully',
      data: await this.profilesService.updateCurrentUserCoverImage(
        req.user.userId,
        file,
      ),
    };
  }

  @Get('sellers/:sellerProfileId')
  async getSellerProfile(@Param('sellerProfileId') sellerProfileId: string) {
    return {
      success: true,
      message: 'Seller profile fetched successfully',
      data: await this.profilesService.getPublicSellerProfile(sellerProfileId),
    };
  }
}