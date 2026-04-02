import { Injectable, NotFoundException } from '@nestjs/common';
import { OrderStatus, Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class OrdersService {
  constructor(private readonly prisma: PrismaService) {}

  async listOrdersForBuyer(userId: string) {
    return this.prisma.order.findMany({
      where: { buyerUserId: userId },
      include: {
        items: {
          include: {
            product: true,
          },
        },
        shipment: true,
      },
      orderBy: {
        createdAt: 'desc',
      },
    });
  }

  async createOrderFromCart(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        cart: {
          include: {
            items: {
              include: {
                product: true,
              },
            },
          },
        },
      },
    });

    if (!user?.cart || user.cart.items.length === 0) {
      throw new NotFoundException('Cart is empty');
    }

    const firstItem = user.cart.items[0];
    const subtotal = user.cart.items.reduce((sum, item) => {
      return sum + Number(item.product.priceAmount) * item.quantity;
    }, 0);
    const delivery = 15000;
    const total = subtotal + delivery;

    const order = await this.prisma.order.create({
      data: {
        orderNumber: `BHB-${Date.now()}`,
        status: OrderStatus.PENDING,
        buyerUserId: userId,
        sellerProfileId: firstItem.product.sellerProfileId,
        subtotalAmount: new Prisma.Decimal(subtotal.toFixed(2)),
        deliveryAmount: new Prisma.Decimal(delivery.toFixed(2)),
        totalAmount: new Prisma.Decimal(total.toFixed(2)),
        items: {
          create: user.cart.items.map((item) => ({
            productId: item.productId,
            quantity: item.quantity,
            unitPriceAmount: item.product.priceAmount,
            totalPriceAmount: new Prisma.Decimal(
              (Number(item.product.priceAmount) * item.quantity).toFixed(2),
            ),
          })),
        },
        shipment: {
          create: {
            shipmentStatus: 'PENDING',
          },
        },
      },
      include: {
        items: true,
        shipment: true,
      },
    });

    await this.prisma.cartItem.deleteMany({
      where: { cartId: user.cart.id },
    });

    return order;
  }
}
