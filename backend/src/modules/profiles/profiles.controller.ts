import {
  Body,
  Controller,
  Delete,
  ForbiddenException,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ListUsersDto } from './dto/list-users.dto';
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
  @Post('me/live/start')
  async startCurrentUserLive(
    @Req() req: { user: { userId: string } },
    @Body() body: { title?: string; category?: string },
  ) {
    return {
      success: true,
      message: 'Live started successfully',
      data: await this.profilesService.startCurrentUserLive(req.user.userId, {
        title: body.title ?? '',
        category: body.category ?? '',
      }),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Post('me/live/stop')
  async stopCurrentUserLive(@Req() req: { user: { userId: string } }) {
    return {
      success: true,
      message: 'Live stopped successfully',
      data: await this.profilesService.stopCurrentUserLive(req.user.userId),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Get('sellers/:sellerProfileId/live/join')
  async getSellerLiveJoinInfo(
    @Req() req: { user: { userId: string } },
    @Param('sellerProfileId') sellerProfileId: string,
  ) {
    return {
      success: true,
      message: 'Seller live join info fetched successfully',
      data: await this.profilesService.getSellerLiveJoinInfo(
        req.user.userId,
        sellerProfileId,
      ),
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
  @Post('me/seller-verification-request')
  async submitSellerVerificationRequest(
    @Req() req: { user: { userId: string } },
  ) {
    return {
      success: true,
      message: 'Seller verification request submitted successfully',
      data: await this.profilesService.submitSellerVerificationRequest(
        req.user.userId,
      ),
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
  @Post('admin/shop-requests/:userId/pending')
  async resetShopRequestToPending(
    @Req() req: { user: { userId: string; role: string } },
    @Param('userId') userId: string,
  ) {
    this.ensureAdminAccess(req.user.role);

    return {
      success: true,
      message: 'Shop request moved back to pending successfully',
      data: await this.profilesService.resetShopRequestToPending(userId),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Get('admin/seller-verification-requests/pending')
  async listPendingSellerVerificationRequests(
    @Req() req: { user: { userId: string; role: string } },
  ) {
    this.ensureAdminAccess(req.user.role);

    return {
      success: true,
      message: 'Pending seller verification requests fetched successfully',
      data: await this.profilesService.listPendingSellerVerificationRequests(),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Post('admin/seller-verification-requests/:userId/approve')
  async approveSellerVerificationRequest(
    @Req() req: { user: { userId: string; role: string } },
    @Param('userId') userId: string,
  ) {
    this.ensureAdminAccess(req.user.role);

    return {
      success: true,
      message: 'Seller verification request approved successfully',
      data: await this.profilesService.approveSellerVerificationRequest(userId),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Post('admin/seller-verification-requests/:userId/pending')
  async resetSellerVerificationRequestToPending(
    @Req() req: { user: { userId: string; role: string } },
    @Param('userId') userId: string,
  ) {
    this.ensureAdminAccess(req.user.role);

    return {
      success: true,
      message: 'Seller verification request moved back to pending successfully',
      data: await this.profilesService.resetSellerVerificationRequestToPending(
        userId,
      ),
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

  @UseGuards(JwtAuthGuard)
  @Get('sellers/:sellerProfileId/viewer')
  async getSellerProfileForViewer(
    @Req() req: { user: { userId: string } },
    @Param('sellerProfileId') sellerProfileId: string,
  ) {
    return {
      success: true,
      message: 'Seller profile for viewer fetched successfully',
      data: await this.profilesService.getPublicSellerProfileForViewer(
        sellerProfileId,
        req.user.userId,
      ),
    };
  }

  @Get('users/:userId')
  async getUserProfile(@Param('userId') userId: string) {
    return {
      success: true,
      message: 'User profile fetched successfully',
      data: await this.profilesService.getPublicUserProfile(userId),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Post('users/:userId/report')
  async reportUser(
    @Req() req: { user: { userId: string } },
    @Param('userId') userId: string,
    @Body()
    body: {
      conversationId?: string;
      reason?: string;
      details?: string;
      blockUser?: boolean;
    },
  ) {
    return {
      success: true,
      message: 'User reported successfully',
      data: await this.profilesService.reportUser(req.user.userId, userId, {
        conversationId: body.conversationId,
        reason: body.reason,
        details: body.details,
        blockUser: body.blockUser,
      }),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Post('users/:userId/block')
  async blockUser(
    @Req() req: { user: { userId: string } },
    @Param('userId') userId: string,
    @Body() body: { conversationId?: string },
  ) {
    return {
      success: true,
      message: 'User blocked successfully',
      data: await this.profilesService.blockUser(req.user.userId, userId, {
        conversationId: body.conversationId,
      }),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Delete('users/:userId/block')
  async unblockUser(
    @Req() req: { user: { userId: string } },
    @Param('userId') userId: string,
  ) {
    return {
      success: true,
      message: 'User unblocked successfully',
      data: await this.profilesService.unblockUser(req.user.userId, userId),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Get('me/blocked-users')
  async getMyBlockedUsers(
    @Req() req: { user: { userId: string } },
  ) {
    return {
      success: true,
      message: 'Current user blocked users fetched successfully',
      data: await this.profilesService.listBlockedUsers(req.user.userId),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Get('me/reports')
  async getMyReports(
    @Req() req: { user: { userId: string } },
  ) {
    return {
      success: true,
      message: 'Current user reports fetched successfully',
      data: await this.profilesService.listReportsByReporter(req.user.userId),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Get('admin/reports')
  async getAllReports(
    @Req() req: { user: { userId: string; role: string } },
  ) {
    this.ensureAdminAccess(req.user.role);

    return {
      success: true,
      message: 'All reports fetched successfully',
      data: await this.profilesService.listAllReports(),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Get('admin/users')
  async getAllUsers(
    @Req() req: { user: { userId: string; role: string } },
    @Query() query: ListUsersDto,
  ) {
    this.ensureAdminAccess(req.user.role);

    return {
      success: true,
      message: 'Users fetched successfully',
      data: await this.profilesService.listAllUsers(query),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Get('presence')
  async getUsersPresence(
    @Query('userIds') rawUserIds: string | undefined,
  ) {
    return {
      success: true,
      message: 'Users presence fetched successfully',
      data: await this.profilesService.getUsersPresence(rawUserIds),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Get('me/following')
  async getCurrentUserFollowing(
    @Req() req: { user: { userId: string } },
  ) {
    return {
      success: true,
      message: 'Current user following fetched successfully',
      data: await this.profilesService.getCurrentUserFollowing(req.user.userId),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Post('sellers/:sellerProfileId/follow')
  async followSeller(
    @Req() req: { user: { userId: string } },
    @Param('sellerProfileId') sellerProfileId: string,
  ) {
    return {
      success: true,
      message: 'Seller followed successfully',
      data: await this.profilesService.followSeller(req.user.userId, sellerProfileId),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Post('sellers/:sellerProfileId/unfollow')
  async unfollowSeller(
    @Req() req: { user: { userId: string } },
    @Param('sellerProfileId') sellerProfileId: string,
  ) {
    return {
      success: true,
      message: 'Seller unfollowed successfully',
      data: await this.profilesService.unfollowSeller(req.user.userId, sellerProfileId),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Post('sellers/:sellerProfileId/view')
  async recordSellerView(
    @Req() req: { user: { userId: string } },
    @Param('sellerProfileId') sellerProfileId: string,
  ) {
    return {
      success: true,
      message: 'Seller profile view recorded successfully',
      data: await this.profilesService.recordSellerProfileView(
        req.user.userId,
        sellerProfileId,
      ),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Get('sellers/:sellerProfileId/followers')
  async getSellerFollowers(
    @Req() req: { user: { userId: string } },
    @Param('sellerProfileId') sellerProfileId: string,
  ) {
    return {
      success: true,
      message: 'Seller followers fetched successfully',
      data: await this.profilesService.getSellerFollowers(
        req.user.userId,
        sellerProfileId,
      ),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Get('sellers/:sellerProfileId/views')
  async getSellerProfileViews(
    @Req() req: { user: { userId: string } },
    @Param('sellerProfileId') sellerProfileId: string,
  ) {
    return {
      success: true,
      message: 'Seller profile views fetched successfully',
      data: await this.profilesService.getSellerProfileViews(
        req.user.userId,
        sellerProfileId,
      ),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Get('sellers/:sellerProfileId/likes')
  async getSellerLikeUsers(
    @Req() req: { user: { userId: string } },
    @Param('sellerProfileId') sellerProfileId: string,
  ) {
    return {
      success: true,
      message: 'Seller like users fetched successfully',
      data: await this.profilesService.getSellerLikeUsers(
        req.user.userId,
        sellerProfileId,
      ),
    };
  }
}