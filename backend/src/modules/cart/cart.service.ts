import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AddCartItemDto } from './dto/add-cart-item.dto';

@Injectable()
export class CartService {
  constructor(private readonly prisma: PrismaService) {}

  async getCart(userId: string) {
    const cart = await this.prisma.cart.findUnique({
      where: { userId },
      include: {
        items: {
          include: {
            product: true,
          },
        },
      },
    });

    if (!cart) {
      throw new NotFoundException('Cart not found');
    }

    return cart;
  }

  async addItem(userId: string, dto: AddCartItemDto) {
    const cart = await this.prisma.cart.findUnique({
      where: { userId },
    });

    if (!cart) {
      throw new NotFoundException('Cart not found');
    }

    const product = await this.prisma.product.findUnique({
      where: { id: dto.productId },
    });

    if (!product || !product.isAvailable) {
      throw new BadRequestException('Product is not available');
    }

    return this.prisma.cartItem.upsert({
      where: {
        cartId_productId: {
          cartId: cart.id,
          productId: dto.productId,
        },
      },
      create: {
        cartId: cart.id,
        productId: dto.productId,
        quantity: dto.quantity,
      },
      update: {
        quantity: dto.quantity,
      },
      include: {
        product: true,
      },
    });
  }

  async removeItem(userId: string, itemId: string) {
    const cart = await this.prisma.cart.findUnique({ where: { userId } });

    if (!cart) {
      throw new NotFoundException('Cart not found');
    }

    const item = await this.prisma.cartItem.findFirst({
      where: {
        id: itemId,
        cartId: cart.id,
      },
    });

    if (!item) {
      throw new NotFoundException('Cart item not found');
    }

    await this.prisma.cartItem.delete({ where: { id: itemId } });

    return {
      deleted: true,
    };
  }

  async calculateCartTotals(userId: string) {
    const cart = await this.getCart(userId);
    const subtotal = cart.items.reduce((sum, item) => {
      return sum + Number(item.product.priceAmount) * item.quantity;
    }, 0);

    return {
      subtotal,
      currencyCode: cart.items[0]?.product.currencyCode ?? 'MGA',
      itemsCount: cart.items.length,
    };
  }
}
