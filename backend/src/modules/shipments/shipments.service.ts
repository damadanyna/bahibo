import { Injectable } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ShipmentsService {
  constructor(private readonly prisma: PrismaService) {}

  async listShipmentsForBuyer(userId: string) {
    return this.prisma.shipment.findMany({
      where: {
        order: {
          buyerUserId: userId,
        },
      },
      include: {
        order: true,
      },
      orderBy: {
        createdAt: 'desc',
      },
    });
  }
}
