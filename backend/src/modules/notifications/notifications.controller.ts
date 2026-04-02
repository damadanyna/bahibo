import { Controller, Get } from '@nestjs/common';

import { NotificationsService } from './notifications.service';

@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Get()
  async findAll() {
    return {
      success: true,
      message: 'Notifications fetched successfully',
      data: await this.notificationsService.findAll(),
    };
  }
}
