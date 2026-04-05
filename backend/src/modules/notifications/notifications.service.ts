import { Injectable } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { NotificationEntity } from './entities/notification.entity';

@Injectable()
export class NotificationsService {
  constructor(private readonly prisma: PrismaService) {}

  async findAll(userId: string): Promise<NotificationEntity[]> {
    const sellerProfile = await this.prisma.sellerProfile.findUnique({
      where: { userId },
      include: {
        user: true,
      },
    });

    const latestProducts = await this.prisma.product.findMany({
      where: {
        sellerProfile: {
          followers: {
            some: {
              followerUserId: userId,
            },
          },
          userId: {
            not: userId,
          },
        },
      },
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

    const productNotifications: NotificationEntity[] = latestProducts.map((product, index) => ({
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

    if (!sellerProfile) {
      return productNotifications;
    }

    const [recentProductLikes, recentProfileViews] = await Promise.all([
      this.prisma.productLike.findMany({
        where: {
          product: {
            sellerProfileId: sellerProfile.id,
          },
          NOT: {
            userId,
          },
        },
        include: {
          user: true,
          product: {
            include: {
              sellerProfile: {
                include: {
                  user: true,
                },
              },
            },
          },
        },
        orderBy: {
          createdAt: 'desc',
        },
        take: 30,
      }),
      this.prisma.sellerProfileView.findMany({
        where: {
          sellerProfileId: sellerProfile.id,
          NOT: [{ viewerUserId: null }, { viewerUserId: userId }],
        },
        include: {
          viewer: true,
          sellerProfile: {
            include: {
              user: true,
            },
          },
        },
        orderBy: {
          createdAt: 'desc',
        },
        take: 20,
      }),
    ]);

    const productLikeNotifications = this.buildProductLikeNotifications(
      recentProductLikes,
      userId,
    );
    const profileViewNotifications = this.buildProfileViewNotifications(
      sellerProfile,
      recentProfileViews,
      userId,
    );

    return [...productLikeNotifications, ...profileViewNotifications, ...productNotifications]
      .sort((left, right) => right.createdAt.localeCompare(left.createdAt));
  }

  private buildProductLikeNotifications(
    recentProductLikes: Array<{
      id: string;
      createdAt: Date;
      user: {
        id: string;
        displayName: string;
        avatarUrl: string | null;
      };
      product: {
        id: string;
        title: string;
        imageUrl: string;
        sellerProfile: {
          id: string;
          studioName: string;
          user: {
            avatarUrl: string | null;
          };
        };
      };
    }>,
    currentUserId: string,
  ): NotificationEntity[] {
    const groupedByProduct = new Map<string, typeof recentProductLikes>();

    for (const productLike of recentProductLikes) {
      const group = groupedByProduct.get(productLike.product.id) ?? [];
      group.push(productLike);
      groupedByProduct.set(productLike.product.id, group);
    }

    const notifications: NotificationEntity[] = [];

    for (const entry of Array.from(groupedByProduct.entries())) {
      const likes = entry[1];
      const productLike = likes[0];
      const actors = likes
        .filter((like) => like.user.id !== currentUserId)
        .map((like) => ({
          id: like.user.id,
          name: like.user.displayName,
          avatarUrl: like.user.avatarUrl ?? 'https://i.pravatar.cc/240?img=12',
          timeLabel: this.buildRelativeTimeLabel(like.createdAt),
        }));

      if (actors.length === 0) {
        continue;
      }

      notifications.push({
        id: `notif-like-${productLike.product.id}`,
        type: 'product_like',
        title: 'Nouveaux likes sur votre produit',
        body: likes.length == 1
            ? `${productLike.user.displayName} a aime ${productLike.product.title}.`
            : `${likes.length} utilisateurs ont aime ${productLike.product.title}.`,
        isRead: false,
        createdAt: productLike.createdAt.toISOString(),
        likeCount: likes.length,
        sellerProfile: {
          id: productLike.product.sellerProfile.id,
          studioName: productLike.product.sellerProfile.studioName,
        },
        seller: {
          id: productLike.product.sellerProfile.id,
          name: productLike.product.sellerProfile.studioName,
          avatarUrl:
              productLike.product.sellerProfile.user.avatarUrl ??
              'https://i.pravatar.cc/240?img=12',
        },
        product: {
          id: productLike.product.id,
          title: productLike.product.title,
          imageUrl: productLike.product.imageUrl,
        },
        actors,
      });
    }

    return notifications;
  }

  private buildProfileViewNotifications(
    sellerProfile: {
      id: string;
      studioName: string;
      user: {
        avatarUrl: string | null;
      };
    },
    recentProfileViews: Array<{
      id: string;
      createdAt: Date;
      viewer: {
        id: string;
        displayName: string;
        avatarUrl: string | null;
      } | null;
    }>,
    currentUserId: string,
  ): NotificationEntity[] {
    if (recentProfileViews.length === 0) {
      return [];
    }

    const actors = recentProfileViews
      .filter((view) => view.viewer != null && view.viewer!.id !== currentUserId)
      .map((view) => ({
        id: view.viewer!.id,
        name: view.viewer!.displayName,
        avatarUrl: view.viewer!.avatarUrl ?? 'https://i.pravatar.cc/240?img=12',
        timeLabel: this.buildRelativeTimeLabel(view.createdAt),
      }));

    if (actors.length === 0) {
      return [];
    }

    return [
      {
        id: `notif-profile-view-${sellerProfile.id}`,
        type: 'profile_view',
        title: 'Nouvelles vues sur votre profil',
        body: actors.length === 1
          ? `${actors[0].name} a regarde votre profil.`
            : `${actors.length} utilisateurs ont regarde votre profil.`,
        isRead: false,
        createdAt: recentProfileViews[0].createdAt.toISOString(),
        sellerProfile: {
          id: sellerProfile.id,
          studioName: sellerProfile.studioName,
        },
        seller: {
          id: sellerProfile.id,
          name: sellerProfile.studioName,
          avatarUrl:
              sellerProfile.user.avatarUrl ?? 'https://i.pravatar.cc/240?img=12',
        },
        product: null,
        actors,
      },
    ];
  }

  private buildRelativeTimeLabel(date: Date) {
    const diffMs = Date.now() - date.getTime();
    const diffMinutes = Math.max(1, Math.floor(diffMs / (1000 * 60)));

    if (diffMinutes < 60) {
      return `il y a ${diffMinutes} min`;
    }

    const diffHours = Math.floor(diffMinutes / 60);
    if (diffHours < 24) {
      return `il y a ${diffHours} h`;
    }

    const diffDays = Math.floor(diffHours / 24);
    return `il y a ${diffDays} j`;
  }
}
