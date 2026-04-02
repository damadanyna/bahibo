import { Injectable } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { NotificationEntity } from './entities/notification.entity';

@Injectable()
export class NotificationsService {
  constructor(private readonly prisma: PrismaService) {}

  async findAll(): Promise<NotificationEntity[]> {
    const latestProducts = await this.prisma.product.findMany({
      include: {
        sellerProfile: {
          include: {
            user: true,
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
      take: 8,
    });

    return latestProducts.map((product, index) => ({
      id: `notif-${product.id}`,
      type: 'product_added',
      title: 'Nouveau produit publie',
      body: `${product.sellerProfile.studioName} a ajoute ${product.title}.`,
      isRead: index > 1,
      createdAt: product.createdAt.toISOString(),
      seller: {
        id: product.sellerProfile.id,
        name: product.sellerProfile.studioName,
        avatarUrl:
          product.sellerProfile.user.avatarUrl ??
          'https://i.pravatar.cc/240?img=12',
      },
      product: {
        id: product.id,
        title: product.title,
        imageUrl: product.imageUrl,
      },
    }));
  }
}
