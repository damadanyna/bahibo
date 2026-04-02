import { Body, Controller, Get, Param, Patch, Req, UseGuards } from '@nestjs/common';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { ProfilesService } from './profiles.service';

@Controller('profiles')
export class ProfilesController {
  constructor(private readonly profilesService: ProfilesService) {}

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

  @Get('sellers/:sellerProfileId')
  async getSellerProfile(@Param('sellerProfileId') sellerProfileId: string) {
    return {
      success: true,
      message: 'Seller profile fetched successfully',
      data: await this.profilesService.getPublicSellerProfile(sellerProfileId),
    };
  }
}