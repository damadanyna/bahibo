import { Controller, Get, Post, Req, UseGuards } from '@nestjs/common';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { OrdersService } from './orders.service';

@UseGuards(JwtAuthGuard)
@Controller('orders')
export class OrdersController {
  constructor(private readonly ordersService: OrdersService) {}

  @Get()
  async findAll(@Req() req: { user: { userId: string } }) {
    return {
      success: true,
      message: 'Orders fetched successfully',
      data: await this.ordersService.listOrdersForBuyer(req.user.userId),
    };
  }

  @Post()
  async create(@Req() req: { user: { userId: string } }) {
    return {
      success: true,
      message: 'Order created successfully',
      data: await this.ordersService.createOrderFromCart(req.user.userId),
    };
  }
}
