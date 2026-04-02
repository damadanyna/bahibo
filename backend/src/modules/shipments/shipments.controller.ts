import { Controller, Get, Req, UseGuards } from '@nestjs/common';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ShipmentsService } from './shipments.service';

@UseGuards(JwtAuthGuard)
@Controller('shipments')
export class ShipmentsController {
  constructor(private readonly shipmentsService: ShipmentsService) {}

  @Get()
  async findAll(@Req() req: { user: { userId: string } }) {
    return {
      success: true,
      message: 'Shipments fetched successfully',
      data: await this.shipmentsService.listShipmentsForBuyer(req.user.userId),
    };
  }
}
