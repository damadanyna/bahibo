import { Controller, Get, Param, Post, Req, UseGuards } from '@nestjs/common';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { NotificationsService } from './notifications.service';

@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @UseGuards(JwtAuthGuard)
  @Get()
  async findAll(@Req() req: { user: { userId: string } }) {
    return {
      success: true,
      message: 'Notifications fetched successfully',
      data: await this.notificationsService.findAll(req.user.userId),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Post(':notificationId/read')
  async markAsRead(
    @Req() req: { user: { userId: string } },
    @Param('notificationId') notificationId: string,
  ) {
    return {
      success: true,
      message: 'Notification marked as read',
      data: await this.notificationsService.markAsRead(
        req.user.userId,
        notificationId,
      ),
    };
  }
}
