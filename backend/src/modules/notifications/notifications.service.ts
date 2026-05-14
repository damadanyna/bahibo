import { Injectable } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { CreateNotificationFeedbackDto } from './dto/create-notification-feedback.dto';
import { NotificationEntity } from './entities/notification.entity';

@Injectable()
export class NotificationsService {
  constructor(private readonly prisma: PrismaService) {}

  async countUnread(userId: string): Promise<number> {
    const notifications = await this.findAll(userId);
    return notifications.filter((notification) => notification.isRead !== true).length;
  }

  async findAll(userId: string): Promise<NotificationEntity[]> {
    const currentUser = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        displayName: true,
        avatarUrl: true,
        role: true,
        shopRequestStatus: true,
        shopRequestReviewedAt: true,
        sellerProfile: {
          select: {
            id: true,
            studioName: true,
          },
        },
      },
    });

    if (currentUser?.role === 'ADMIN') {
      return this.findAdminNotifications(userId);
    }

    const sellerProfile = await this.prisma.sellerProfile.findUnique({
      where: { userId },
      include: {
        user: true,
      },
    });

    const sellerFollows = await this.prisma.sellerFollow.findMany({
      where: {
        followerUserId: userId,
      },
      select: {
        sellerProfileId: true,
        createdAt: true,
      },
    });

    const latestProducts = sellerFollows.length === 0
      ? []
      : await this.prisma.product.findMany({
          where: {
            sellerProfile: {
              userId: {
                not: userId,
              },
            },
            OR: sellerFollows.map((sellerFollow) => ({
              sellerProfileId: sellerFollow.sellerProfileId,
              createdAt: {
                gte: sellerFollow.createdAt,
              },
            })),
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

    const recentUpdatedProducts = sellerFollows.length === 0
      ? []
      : await this.prisma.product.findMany({
          where: {
            sellerProfile: {
              userId: {
                not: userId,
              },
            },
            updatedAt: {
              gt: this.prisma.product.fields.createdAt,
            },
            OR: sellerFollows.map((sellerFollow) => ({
              sellerProfileId: sellerFollow.sellerProfileId,
              updatedAt: {
                gte: sellerFollow.createdAt,
              },
            })),
          },
          include: {
            sellerProfile: {
              include: {
                user: true,
              },
            },
          },
          orderBy: {
            updatedAt: 'desc',
          },
          take: 8,
        });

    const followedSellerIds = sellerFollows.map((sellerFollow) => sellerFollow.sellerProfileId);
    const recentFollowerComments = followedSellerIds.length === 0
      ? []
      : await this.prisma.productComment.findMany({
          where: {
            product: {
              sellerProfile: {
                userId: {
                  not: userId,
                },
              },
            },
            userId: {
              not: userId,
            },
            OR: sellerFollows.map((sellerFollow) => ({
              product: {
                sellerProfileId: sellerFollow.sellerProfileId,
              },
              createdAt: {
                gte: sellerFollow.createdAt,
              },
            })),
          },
          include: {
            user: {
              include: {
                sellerFollows: {
                  where: {
                    sellerProfileId: {
                      in: followedSellerIds,
                    },
                  },
                },
              },
            },
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
        });

    const productNotifications: NotificationEntity[] = latestProducts.map((product, index) => ({
      id: `notif-${product.id}`,
      type: 'product_added',
      title: 'Nouveau produit',
      body: `${product.sellerProfile.studioName} a publie un nouveau produit : ${product.title}.`,
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

    const productUpdateNotifications = recentUpdatedProducts.map((product) => ({
      id: `notif-product-update-${product.id}`,
      type: 'product_updated',
      title: 'Produit mis a jour',
      body: `${product.sellerProfile.studioName} a mis a jour ${product.title} : prix, images ou disponibilite.`,
      isRead: false,
      createdAt: product.updatedAt.toISOString(),
      sellerProfile: {
        id: product.sellerProfile.id,
        studioName: product.sellerProfile.studioName,
      },
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
    } satisfies NotificationEntity));

    const followerCommentNotifications = this.buildFollowedSellerCommentNotifications(
      recentFollowerComments,
      userId,
    );

    const shopRequestApprovalNotifications = this.buildShopRequestApprovalNotifications(
      currentUser,
    );

    if (!sellerProfile) {
      return this.applyReadStates(userId, [
        ...shopRequestApprovalNotifications,
        ...followerCommentNotifications,
        ...productUpdateNotifications,
        ...productNotifications,
      ].sort((left, right) => right.createdAt.localeCompare(left.createdAt)));
    }

    const [recentSellerFollows, recentProductLikes, recentProductComments, recentProfileViews] = await Promise.all([
      this.prisma.sellerFollow.findMany({
        where: {
          sellerProfileId: sellerProfile.id,
          followerUserId: {
            not: userId,
          },
        },
        include: {
          follower: true,
        },
        orderBy: {
          createdAt: 'desc',
        },
        take: 20,
      }),
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
      this.prisma.productComment.findMany({
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

    const sellerFollowNotifications: NotificationEntity[] = recentSellerFollows.map((follow) => ({
      id: `notif-seller-follow-${follow.id}`,
      type: 'seller_follow',
      title: 'Nouvel abonne',
      body: `${follow.follower.displayName} vient de s'abonner a votre boutique.`,
      isRead: false,
      createdAt: follow.createdAt.toISOString(),
      sellerProfile: {
        id: sellerProfile.id,
        studioName: sellerProfile.studioName,
      },
      seller: {
        id: follow.follower.id,
        name: follow.follower.displayName,
        avatarUrl: follow.follower.avatarUrl ?? 'https://i.pravatar.cc/240?img=12',
      },
      product: null,
      actors: [
        {
          id: follow.follower.id,
          name: follow.follower.displayName,
          avatarUrl: follow.follower.avatarUrl ?? 'https://i.pravatar.cc/240?img=12',
          timeLabel: this.buildRelativeTimeLabel(follow.createdAt),
        },
      ],
    }));

    const productLikeNotifications = this.buildProductLikeNotifications(
      recentProductLikes,
      userId,
    );
    const productCommentNotifications = this.buildProductCommentNotifications(
      recentProductComments,
      userId,
    );
    const profileViewNotifications = this.buildProfileViewNotifications(
      sellerProfile,
      recentProfileViews,
      userId,
    );

    return this.applyReadStates(userId, [
      ...shopRequestApprovalNotifications,
      ...sellerFollowNotifications,
      ...productCommentNotifications,
      ...productLikeNotifications,
      ...profileViewNotifications,
      ...followerCommentNotifications,
      ...productUpdateNotifications,
      ...productNotifications,
    ]
      .sort((left, right) => right.createdAt.localeCompare(left.createdAt)));
  }

  async createFeedback(userId: string, dto: CreateNotificationFeedbackDto) {
    const trimmedMessage = dto.message.trim();

    return this.prisma.userFeedback.create({
      data: {
        userId,
        message: trimmedMessage,
      },
      select: {
        id: true,
        message: true,
        createdAt: true,
      },
    });
  }

  async markAsRead(userId: string, notificationId: string) {
    return this.prisma.notificationReadState.upsert({
      where: {
        userId_notificationId: {
          userId,
          notificationId,
        },
      },
      update: {
        readAt: new Date(),
      },
      create: {
        userId,
        notificationId,
      },
      select: {
        notificationId: true,
        readAt: true,
      },
    });
  }

  private async findAdminNotifications(
    userId: string,
  ): Promise<NotificationEntity[]> {
    const feedbackEntries = await this.prisma.userFeedback.findMany({
      include: {
        user: true,
      },
      orderBy: {
        createdAt: 'desc',
      },
      take: 50,
    });

    const feedbackNotifications: NotificationEntity[] = feedbackEntries.map(
      (feedback) => ({
        id: `notif-user-feedback-${feedback.id}`,
        type: 'user_feedback',
        title: 'Nouveau commentaire utilisateur',
        body: feedback.message,
        isRead: false,
        createdAt: feedback.createdAt.toISOString(),
        seller: {
          id: feedback.user.id,
          name: feedback.user.displayName,
          avatarUrl: feedback.user.avatarUrl ?? 'https://i.pravatar.cc/240?img=12',
        },
        product: null,
        actors: [
          {
            id: feedback.user.id,
            name: feedback.user.displayName,
            avatarUrl: feedback.user.avatarUrl ?? 'https://i.pravatar.cc/240?img=12',
            timeLabel: this.buildRelativeTimeLabel(feedback.createdAt),
          },
        ],
      }),
    );

    return this.applyReadStates(userId, feedbackNotifications);
  }

  private buildShopRequestApprovalNotifications(
    currentUser:
      | {
          id: string;
          displayName: string;
          avatarUrl: string | null;
          role: string;
          shopRequestStatus: string;
          shopRequestReviewedAt: Date | null;
          sellerProfile: {
            id: string;
            studioName: string;
          } | null;
        }
      | null,
  ): NotificationEntity[] {
    if (
      !currentUser ||
      currentUser.shopRequestStatus !== 'APPROVED' ||
      currentUser.shopRequestReviewedAt == null
    ) {
      return [];
    }

    const sellerStudioName = currentUser.sellerProfile?.studioName?.trim() ?? '';
    const sellerName = sellerStudioName.length > 0
      ? sellerStudioName
      : currentUser.displayName;

    return [
      {
        id: `notif-shop-request-approved-${currentUser.id}-${currentUser.shopRequestReviewedAt.getTime()}`,
        type: 'shop_request_approved',
        title: 'Demande boutique approuvee',
        body: `Votre compte ${sellerName} est maintenant actif comme boutique. Vous pouvez publier vos produits.`,
        isRead: false,
        createdAt: currentUser.shopRequestReviewedAt.toISOString(),
        sellerProfile: currentUser.sellerProfile
          ? {
              id: currentUser.sellerProfile.id,
              studioName: currentUser.sellerProfile.studioName,
            }
          : null,
        seller: {
          id: currentUser.id,
          name: sellerName,
          avatarUrl: currentUser.avatarUrl ?? 'https://i.pravatar.cc/240?img=12',
        },
        product: null,
      },
    ];
  }

  private async applyReadStates(
    userId: string,
    notifications: NotificationEntity[],
  ): Promise<NotificationEntity[]> {
    if (notifications.length === 0) {
      return notifications;
    }

    const readStates = await this.prisma.notificationReadState.findMany({
      where: {
        userId,
        notificationId: {
          in: notifications.map((notification) => notification.id),
        },
      },
      select: {
        notificationId: true,
      },
    });

    const readNotificationIds = new Set(
      readStates.map((readState) => readState.notificationId),
    );

    return notifications.map((notification) => ({
      ...notification,
      isRead: notification.isRead || readNotificationIds.has(notification.id),
    }));
  }

  private buildFollowedSellerCommentNotifications(
    recentFollowerComments: Array<{
      id: string;
      content: string;
      createdAt: Date;
      user: {
        id: string;
        displayName: string;
        avatarUrl: string | null;
        sellerFollows: Array<{
          sellerProfileId: string;
        }>;
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
    const groupedByProduct = new Map<string, typeof recentFollowerComments>();

    for (const comment of recentFollowerComments) {
      const commenterFollowsSeller = comment.user.sellerFollows.some(
        (sellerFollow) => sellerFollow.sellerProfileId === comment.product.sellerProfile.id,
      );
      if (!commenterFollowsSeller || comment.user.id === currentUserId) {
        continue;
      }

      const group = groupedByProduct.get(comment.product.id) ?? [];
      group.push(comment);
      groupedByProduct.set(comment.product.id, group);
    }

    const notifications: NotificationEntity[] = [];

    for (const entry of Array.from(groupedByProduct.entries())) {
      const comments = entry[1];
      const latestComment = comments[0];
      const actors = comments.map((comment) => ({
        id: comment.user.id,
        name: comment.user.displayName,
        avatarUrl: comment.user.avatarUrl ?? 'https://i.pravatar.cc/240?img=12',
        timeLabel: this.buildRelativeTimeLabel(comment.createdAt),
      }));

      notifications.push({
        id: `notif-followed-comment-${latestComment.product.id}`,
        type: 'followed_product_comment',
        title: 'Commentaire d\'un abonne',
        body: comments.length === 1
          ? `${latestComment.user.displayName} a commente le produit ${latestComment.product.title}.`
          : `${comments.length} abonnes ont commente le produit ${latestComment.product.title}.`,
        isRead: false,
        createdAt: latestComment.createdAt.toISOString(),
        commentCount: comments.length,
        sellerProfile: {
          id: latestComment.product.sellerProfile.id,
          studioName: latestComment.product.sellerProfile.studioName,
        },
        seller: {
          id: latestComment.product.sellerProfile.id,
          name: latestComment.product.sellerProfile.studioName,
          avatarUrl:
            latestComment.product.sellerProfile.user.avatarUrl ??
            'https://i.pravatar.cc/240?img=12',
        },
        product: {
          id: latestComment.product.id,
          title: latestComment.product.title,
          imageUrl: latestComment.product.imageUrl,
        },
        actors,
      });
    }

    return notifications;
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
          ? `${productLike.user.displayName} a aimé le produit ${productLike.product.title}.`
          : `${likes.length} utilisateurs ont aimé le produit ${productLike.product.title}.`,
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

  private buildProductCommentNotifications(
    recentProductComments: Array<{
      id: string;
      content: string;
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
    const groupedByProduct = new Map<string, typeof recentProductComments>();

    for (const productComment of recentProductComments) {
      const group = groupedByProduct.get(productComment.product.id) ?? [];
      group.push(productComment);
      groupedByProduct.set(productComment.product.id, group);
    }

    const notifications: NotificationEntity[] = [];

    for (const entry of Array.from(groupedByProduct.entries())) {
      const comments = entry[1];
      const latestComment = comments[0];
      const actors = comments
        .filter((comment) => comment.user.id !== currentUserId)
        .map((comment) => ({
          id: comment.user.id,
          name: comment.user.displayName,
          avatarUrl: comment.user.avatarUrl ?? 'https://i.pravatar.cc/240?img=12',
          timeLabel: this.buildRelativeTimeLabel(comment.createdAt),
        }));

      if (actors.length === 0) {
        continue;
      }

      notifications.push({
        id: `notif-comment-${latestComment.product.id}`,
        type: 'product_comment',
        title: 'Nouveaux commentaires sur votre produit',
        body: comments.length == 1
          ? `${latestComment.user.displayName} a commente le produit ${latestComment.product.title}.`
          : `${comments.length} utilisateurs ont commente le produit ${latestComment.product.title}.`,
        isRead: false,
        createdAt: latestComment.createdAt.toISOString(),
        commentCount: comments.length,
        sellerProfile: {
          id: latestComment.product.sellerProfile.id,
          studioName: latestComment.product.sellerProfile.studioName,
        },
        seller: {
          id: latestComment.product.sellerProfile.id,
          name: latestComment.product.sellerProfile.studioName,
          avatarUrl:
              latestComment.product.sellerProfile.user.avatarUrl ??
              'https://i.pravatar.cc/240?img=12',
        },
        product: {
          id: latestComment.product.id,
          title: latestComment.product.title,
          imageUrl: latestComment.product.imageUrl,
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

    const latestViewsByUser = new Map<string, {
      id: string;
      name: string;
      avatarUrl: string;
      viewedAt: Date;
    }>();

    for (const view of recentProfileViews) {
      if (view.viewer == null || view.viewer.id === currentUserId) {
        continue;
      }

      const existingView = latestViewsByUser.get(view.viewer.id);
      if (existingView != null && existingView.viewedAt >= view.createdAt) {
        continue;
      }

      latestViewsByUser.set(view.viewer.id, {
        id: view.viewer.id,
        name: view.viewer.displayName,
        avatarUrl: view.viewer.avatarUrl ?? 'https://i.pravatar.cc/240?img=12',
        viewedAt: view.createdAt,
      });
    }

    const actors = Array.from(latestViewsByUser.values())
      .sort((left, right) => right.viewedAt.getTime() - left.viewedAt.getTime())
      .map((view) => ({
        id: view.id,
        name: view.name,
        avatarUrl: view.avatarUrl,
        timeLabel: this.buildRelativeTimeLabel(view.viewedAt),
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
          ? `${actors[0].name} a consulte votre profil.`
            : `${actors.length} utilisateurs ont consulte votre profil.`,
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
