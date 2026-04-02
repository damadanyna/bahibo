import { Body, Controller, Delete, Get, Param, Post, Req, UseGuards } from '@nestjs/common';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AddCartItemDto } from './dto/add-cart-item.dto';
import { CartService } from './cart.service';

@UseGuards(JwtAuthGuard)
@Controller('cart')
export class CartController {
  constructor(private readonly cartService: CartService) {}

  @Get()
  async getCart(@Req() req: { user: { userId: string } }) {
    return {
      success: true,
      message: 'Cart fetched successfully',
      data: await this.cartService.getCart(req.user.userId),
    };
  }

  @Get('totals')
  async getTotals(@Req() req: { user: { userId: string } }) {
    return {
      success: true,
      message: 'Cart totals fetched successfully',
      data: await this.cartService.calculateCartTotals(req.user.userId),
    };
  }

  @Post('items')
  async addItem(
    @Req() req: { user: { userId: string } },
    @Body() dto: AddCartItemDto,
  ) {
    return {
      success: true,
      message: 'Item added to cart successfully',
      data: await this.cartService.addItem(req.user.userId, dto),
    };
  }

  @Delete('items/:itemId')
  async removeItem(
    @Req() req: { user: { userId: string } },
    @Param('itemId') itemId: string,
  ) {
    return {
      success: true,
      message: 'Item removed from cart successfully',
      data: await this.cartService.removeItem(req.user.userId, itemId),
    };
  }
}
