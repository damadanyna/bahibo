import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { Prisma, WarrantyDurationUnit } from "@prisma/client";

import { CloudinaryService } from "../auth/cloudinary.service";
import { ConversationsRealtimeGateway } from "../conversations/realtime/conversations-realtime.gateway";
import { NotificationsService } from "../notifications/notifications.service";
import { PrismaService } from "../prisma/prisma.service";
import { PushNotificationsService } from "../push-notifications/push-notifications.service";
import { CreateProductCommentDto } from "./dto/create-product-comment.dto";
import { CreateProductDto } from "./dto/create-product.dto";
import { UpdateProductDto } from "./dto/update-product.dto";
import { ProductEntity } from "./entities/product.entity";

type ProductWithRelations = Prisma.ProductGetPayload<{
  include: {
    category: true;
    _count: {
      select: {
        likes: true;
        comments: true;
        shares: true;
      };
    };
    productImages: {
      orderBy: {
        sortOrder: "asc";
      };
    };
    sellerProfile: {
      include: {
        user: true;
      };
    };
  };
}>;

type ProductCommentWithRelations = Prisma.ProductCommentGetPayload<{
  include: {
    user: true;
    mentions: {
      include: {
        mentionedUser: true;
      };
    };
  };
}>;

type SerializedProductComment = {
  id: string;
  content: string;
  createdAt: string;
  updatedAt: string;
  parentCommentId: string | null;
  author: {
    id: string;
    displayName: string;
    avatarUrl: string;
  };
  mentions: Array<{
    id: string;
    userId: string;
    displayName: string;
    avatarUrl: string;
  }>;
  replies: SerializedProductComment[];
};

type ProductLocationContext = {
  normalizedLocationLabel: string;
  locationLatitude: number | null;
  locationLongitude: number | null;
  locationTokens: string[];
};

type RankedProductCandidate = {
  product: ProductWithRelations;
  exactLocationMatch: boolean;
  distanceInKm: number | null;
  shuffleScore: number;
};

@Injectable()
export class ProductsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly cloudinaryService: CloudinaryService,
    private readonly conversationsRealtimeGateway: ConversationsRealtimeGateway,
    private readonly notificationsService: NotificationsService,
    private readonly pushNotificationsService: PushNotificationsService,
  ) {}

  private normalizeText(value: string | null | undefined) {
    return value?.trim().toLowerCase() ?? "";
  }

  private joinNonEmpty(values: Array<string | null | undefined>) {
    return values
      .filter((value): value is string =>
        Boolean(value && value.trim().length > 0),
      )
      .join(", ");
  }

  private extractLocationTokens(...values: Array<string | null | undefined>) {
    return Array.from(
      new Set(
        values
          .flatMap((value) =>
            (value ?? "")
              .split(",")
              .map((part) => this.normalizeText(part))
              .filter((part) => part.length >= 3),
          )
          .filter((part) => part.length >= 3),
      ),
    );
  }

  private toNullableNumber(value: unknown) {
    if (typeof value !== "number" || Number.isNaN(value)) {
      return null;
    }

    return value;
  }

  private computeDistanceInKm(
    firstLatitude: number,
    firstLongitude: number,
    secondLatitude: number,
    secondLongitude: number,
  ) {
    const toRadians = (degrees: number) => (degrees * Math.PI) / 180;
    const earthRadiusKm = 6371;
    const latitudeDelta = toRadians(secondLatitude - firstLatitude);
    const longitudeDelta = toRadians(secondLongitude - firstLongitude);
    const normalizedFirstLatitude = toRadians(firstLatitude);
    const normalizedSecondLatitude = toRadians(secondLatitude);
    const haversine =
      Math.sin(latitudeDelta / 2) * Math.sin(latitudeDelta / 2) +
      Math.cos(normalizedFirstLatitude) *
        Math.cos(normalizedSecondLatitude) *
        Math.sin(longitudeDelta / 2) *
        Math.sin(longitudeDelta / 2);

    return (
      earthRadiusKm *
      2 *
      Math.atan2(Math.sqrt(haversine), Math.sqrt(1 - haversine))
    );
  }

  private buildLocationContext(params: {
    userLocationLabel?: string;
    userLocationLatitude?: number;
    userLocationLongitude?: number;
  }) {
    const normalizedLocationLabel = this.normalizeText(
      params.userLocationLabel,
    );
    const locationLatitude = this.toNullableNumber(params.userLocationLatitude);
    const locationLongitude = this.toNullableNumber(
      params.userLocationLongitude,
    );

    if (
      normalizedLocationLabel === "" &&
      locationLatitude == null &&
      locationLongitude == null
    ) {
      return null;
    }

    return {
      normalizedLocationLabel,
      locationLatitude,
      locationLongitude,
      locationTokens: this.extractLocationTokens(params.userLocationLabel),
    } as ProductLocationContext;
  }

  private computeStableShuffleScore(productId: string) {
    const daySeed = new Date().toISOString().slice(0, 10);
    const input = `${daySeed}:${productId}`;
    let hash = 0;
    for (let index = 0; index < input.length; index += 1) {
      hash = (hash * 31 + input.charCodeAt(index)) >>> 0;
    }
    return hash;
  }

  private isExactLocationMatch(
    product: ProductWithRelations,
    context: ProductLocationContext,
  ) {
    const normalizedSellerCity = this.normalizeText(product.sellerProfile.city);
    const normalizedSellerLocationLabel = this.normalizeText(
      this.joinNonEmpty([
        product.sellerProfile.city,
        product.sellerProfile.country,
        product.sellerProfile.user.locationLabel,
      ]),
    );

    if (
      normalizedSellerCity !== "" &&
      (context.locationTokens.includes(normalizedSellerCity) ||
        context.normalizedLocationLabel.includes(normalizedSellerCity))
    ) {
      return true;
    }

    if (
      context.normalizedLocationLabel !== "" &&
      normalizedSellerLocationLabel !== "" &&
      (normalizedSellerLocationLabel === context.normalizedLocationLabel ||
        normalizedSellerLocationLabel.includes(
          context.normalizedLocationLabel,
        ) ||
        context.normalizedLocationLabel.includes(normalizedSellerLocationLabel))
    ) {
      return true;
    }

    return false;
  }

  private rankProductsByLocation(
    items: ProductWithRelations[],
    context: ProductLocationContext,
  ) {
    const rankedCandidates = items.map((product) => {
      const locationLatitude = this.toNullableNumber(
        product.sellerProfile.user.locationLatitude,
      );
      const locationLongitude = this.toNullableNumber(
        product.sellerProfile.user.locationLongitude,
      );
      const exactLocationMatch = this.isExactLocationMatch(product, context);
      const distanceInKm =
        context.locationLatitude != null &&
        context.locationLongitude != null &&
        locationLatitude != null &&
        locationLongitude != null
          ? this.computeDistanceInKm(
              context.locationLatitude,
              context.locationLongitude,
              locationLatitude,
              locationLongitude,
            )
          : null;

      return {
        product,
        exactLocationMatch,
        distanceInKm,
        shuffleScore: this.computeStableShuffleScore(product.id),
      } as RankedProductCandidate;
    });

    const hasExactMatches = rankedCandidates.some(
      (candidate) => candidate.exactLocationMatch,
    );

    return rankedCandidates.sort((left, right) => {
      const leftBucket = left.exactLocationMatch
        ? 0
        : !hasExactMatches && left.distanceInKm != null
          ? 1
          : hasExactMatches && left.distanceInKm != null
            ? 2
            : 3;
      const rightBucket = right.exactLocationMatch
        ? 0
        : !hasExactMatches && right.distanceInKm != null
          ? 1
          : hasExactMatches && right.distanceInKm != null
            ? 2
            : 3;

      if (leftBucket !== rightBucket) {
        return leftBucket - rightBucket;
      }

      if (leftBucket === 1 || leftBucket === 2) {
        const leftDistance = left.distanceInKm ?? Number.POSITIVE_INFINITY;
        const rightDistance = right.distanceInKm ?? Number.POSITIVE_INFINITY;
        if (leftDistance !== rightDistance) {
          return leftDistance - rightDistance;
        }
      }

      if (leftBucket === 0) {
        return left.shuffleScore - right.shuffleScore;
      }

      const createdAtComparison =
        right.product.createdAt.getTime() - left.product.createdAt.getTime();
      if (createdAtComparison !== 0) {
        return createdAtComparison;
      }

      return left.shuffleScore - right.shuffleScore;
    });
  }

  /**
   * A product can't keep a stale duration/unit once its warranty is turned
   * off — otherwise re-enabling it later would silently resurrect whatever
   * values were last entered instead of asking again.
   */
  private resolveWarrantyFields(
    hasWarranty: boolean,
    durationValue?: number | null,
    durationUnit?: WarrantyDurationUnit | null,
  ) {
    if (!hasWarranty) {
      return {
        hasWarranty: false,
        warrantyDurationValue: null,
        warrantyDurationUnit: null,
      };
    }

    return {
      hasWarranty: true,
      warrantyDurationValue: durationValue ?? null,
      warrantyDurationUnit: durationUnit ?? null,
    };
  }

  async create(
    currentUser: { userId: string; role: string },
    dto: CreateProductDto,
    files: Express.Multer.File[] = [],
  ) {
    const sellerProfile = await this.prisma.sellerProfile.findUnique({
      where: { userId: currentUser.userId },
      include: {
        user: true,
      },
    });

    if (!sellerProfile) {
      throw new BadRequestException("Seller profile not found for this user.");
    }

    const category = await this.resolveCategory(dto);
    const imageUrls = await this.resolveProductImageUrls(
      sellerProfile.id,
      dto,
      files,
    );

    const product = await this.prisma.product.create({
      data: {
        title: dto.title.trim(),
        description: dto.description.trim(),
        imageUrl: imageUrls[0],
        priceAmount: dto.priceAmount,
        currencyCode: dto.currencyCode?.trim().toUpperCase() ?? "MGA",
        isAvailable: dto.isAvailable ?? true,
        condition: dto.condition ?? null,
        ...this.resolveWarrantyFields(
          dto.hasWarranty ?? false,
          dto.warrantyDurationValue,
          dto.warrantyDurationUnit,
        ),
        categoryId: category.id,
        sellerProfileId: sellerProfile.id,
        productImages: {
          create: imageUrls.map((imageUrl, index) => ({
            imageUrl,
            sortOrder: index,
          })),
        },
      },
      include: {
        category: true,
        _count: {
          select: {
            likes: true,
            comments: true,
            shares: true,
          },
        },
        productImages: {
          orderBy: {
            sortOrder: "asc",
          },
        },
        sellerProfile: {
          include: {
            user: true,
          },
        },
      },
    });

    await this.emitSellerProfileUpdatedByProfileId(sellerProfile.id);
    await this.pushNotificationsService.sendProductPublishedNotification({
      sellerProfileId: sellerProfile.id,
      sellerUserId: sellerProfile.userId,
      sellerDisplayName: sellerProfile.studioName,
      sellerAvatarUrl: sellerProfile.user.avatarUrl ?? undefined,
      productId: product.id,
      productTitle: product.title,
      productImageUrl: product.imageUrl,
    });
    await this.emitNotificationRefreshToSellerFollowers(sellerProfile.id, []);
    return this.toEntity(product);
  }

  async update(
    currentUser: { userId: string; role: string },
    productId: string,
    dto: UpdateProductDto,
    files: Express.Multer.File[] = [],
  ) {
    const sellerProfile = await this.prisma.sellerProfile.findUnique({
      where: { userId: currentUser.userId },
      include: {
        user: true,
      },
    });

    if (!sellerProfile) {
      throw new BadRequestException("Seller profile not found for this user.");
    }

    const existingProduct = await this.prisma.product.findUnique({
      where: { id: productId },
      include: {
        category: true,
        _count: {
          select: {
            likes: true,
            comments: true,
            shares: true,
          },
        },
        productImages: {
          orderBy: {
            sortOrder: "asc",
          },
        },
        sellerProfile: {
          include: {
            user: true,
          },
        },
      },
    });

    if (!existingProduct) {
      throw new NotFoundException("Product not found");
    }

    if (existingProduct.sellerProfile.userId != currentUser.userId) {
      throw new NotFoundException("Product not found");
    }

    const shouldResolveCategory =
      (dto.categoryId?.trim().length ?? 0) > 0 ||
      (dto.categorySlug?.trim().length ?? 0) > 0 ||
      (dto.categoryName?.trim().length ?? 0) > 0;

    const category = shouldResolveCategory
      ? await this.resolveCategory(dto)
      : existingProduct.category;

    const imageUrls = await this.resolveProductImageUrls(
      sellerProfile.id,
      dto,
      files,
      existingProduct.productImages.length > 0
        ? existingProduct.productImages.map((image) => image.imageUrl)
        : [existingProduct.imageUrl],
    );

    const hasPriceChanged =
      dto.priceAmount != null &&
      dto.priceAmount.toString() !== existingProduct.priceAmount.toString();
    const hasAvailabilityChanged =
      dto.isAvailable != null &&
      dto.isAvailable !== existingProduct.isAvailable;
    const existingImageUrls =
      existingProduct.productImages.length > 0
        ? existingProduct.productImages.map((image) => image.imageUrl)
        : [existingProduct.imageUrl];
    const hasImagesChanged =
      existingImageUrls.length !== imageUrls.length ||
      existingImageUrls.some(
        (imageUrl, index) => imageUrl !== imageUrls[index],
      );

    const updatedProduct = await this.prisma.product.update({
      where: { id: productId },
      data: {
        title: dto.title?.trim() ?? existingProduct.title,
        description: dto.description?.trim() ?? existingProduct.description,
        imageUrl: imageUrls[0],
        priceAmount: dto.priceAmount ?? existingProduct.priceAmount,
        currencyCode:
          dto.currencyCode?.trim().toUpperCase() ??
          existingProduct.currencyCode,
        isAvailable: dto.isAvailable ?? existingProduct.isAvailable,
        condition: dto.condition ?? existingProduct.condition,
        ...this.resolveWarrantyFields(
          dto.hasWarranty ?? existingProduct.hasWarranty,
          dto.warrantyDurationValue ?? existingProduct.warrantyDurationValue,
          dto.warrantyDurationUnit ?? existingProduct.warrantyDurationUnit,
        ),
        categoryId: category.id,
        productImages: {
          deleteMany: {},
          create: imageUrls.map((imageUrl, index) => ({
            imageUrl,
            sortOrder: index,
          })),
        },
      },
      include: {
        category: true,
        _count: {
          select: {
            likes: true,
            comments: true,
            shares: true,
          },
        },
        productImages: {
          orderBy: {
            sortOrder: "asc",
          },
        },
        sellerProfile: {
          include: {
            user: true,
          },
        },
      },
    });

    if (hasPriceChanged || hasAvailabilityChanged || hasImagesChanged) {
      this.emitProductUpdatedEvent({
        product: updatedProduct,
        actorUserId: currentUser.userId,
        action: hasAvailabilityChanged ? "availability_changed" : "updated",
      });
    }

    await this.emitSellerProfileUpdatedByProfileId(sellerProfile.id);
    if (hasPriceChanged || hasAvailabilityChanged || hasImagesChanged) {
      await this.pushNotificationsService.sendProductUpdatedNotification({
        sellerProfileId: sellerProfile.id,
        sellerUserId: sellerProfile.userId,
        sellerDisplayName: sellerProfile.studioName,
        sellerAvatarUrl: sellerProfile.user.avatarUrl ?? undefined,
        productId: updatedProduct.id,
        productTitle: updatedProduct.title,
        productImageUrl: updatedProduct.imageUrl,
      });
      await this.emitNotificationRefreshToSellerFollowers(sellerProfile.id, []);
    }
    return this.toEntity(updatedProduct);
  }

  async remove(
    currentUser: { userId: string; role: string },
    productId: string,
  ) {
    const sellerProfile = await this.prisma.sellerProfile.findUnique({
      where: { userId: currentUser.userId },
      include: {
        user: true,
      },
    });

    if (!sellerProfile) {
      throw new BadRequestException("Seller profile not found for this user.");
    }

    const existingProduct = await this.findProductWithRelations(productId);
    if (existingProduct.sellerProfile.userId !== currentUser.userId) {
      throw new NotFoundException("Product not found");
    }

    const linkedOrderItems = await this.prisma.orderItem.count({
      where: { productId },
    });
    if (linkedOrderItems > 0) {
      throw new BadRequestException(
        "Ce produit ne peut pas etre supprime car il est deja lie a une commande.",
      );
    }

    await this.prisma.product.delete({
      where: { id: productId },
    });

    await this.emitSellerProfileUpdatedByProfileId(sellerProfile.id);
    await this.emitNotificationRefreshToSellerFollowers(sellerProfile.id, []);

    return {
      id: existingProduct.id,
      sellerProfileId: sellerProfile.id,
    };
  }

  async likeProduct(currentUserId: string, productId: string) {
    const product = await this.prisma.product.findUnique({
      where: { id: productId },
      include: {
        category: true,
        _count: {
          select: {
            likes: true,
            comments: true,
            shares: true,
          },
        },
        productImages: {
          orderBy: {
            sortOrder: "asc",
          },
        },
        sellerProfile: {
          include: {
            user: true,
          },
        },
      },
    });

    if (!product) {
      throw new NotFoundException("Product not found");
    }

    await this.prisma.productLike.upsert({
      where: {
        userId_productId: {
          userId: currentUserId,
          productId,
        },
      },
      create: {
        userId: currentUserId,
        productId,
      },
      update: {},
    });

    const updatedProduct = await this.findProductWithRelations(productId);
    this.emitProductUpdatedEvent({
      product: updatedProduct,
      actorUserId: currentUserId,
      action: "liked",
    });
    await this.emitSellerProfileUpdatedByProfileId(
      updatedProduct.sellerProfile.id,
    );
    if (product.sellerProfile.userId !== currentUserId) {
      await this.emitNotificationUpdatedEvent(
        product.sellerProfile.userId,
        "product_like",
      );
    }
    return this.toEntity(updatedProduct);
  }

  async unlikeProduct(currentUserId: string, productId: string) {
    const product = await this.findProductWithRelations(productId);

    await this.prisma.productLike.deleteMany({
      where: {
        userId: currentUserId,
        productId,
      },
    });

    const updatedProduct = await this.findProductWithRelations(productId);
    this.emitProductUpdatedEvent({
      product: updatedProduct,
      actorUserId: currentUserId,
      action: "unliked",
    });
    await this.emitSellerProfileUpdatedByProfileId(
      updatedProduct.sellerProfile.id,
    );
    return this.toEntity(updatedProduct);
  }

  async findComments(productId: string) {
    await this.findProductWithRelations(productId);

    const comments = await this.prisma.productComment.findMany({
      where: { productId },
      include: {
        user: true,
        mentions: {
          include: {
            mentionedUser: true,
          },
          orderBy: {
            createdAt: "asc",
          },
        },
      },
      orderBy: {
        createdAt: "asc",
      },
    });

    return this.serializeCommentTree(comments);
  }

  async hasLikedProduct(currentUserId: string, productId: string) {
    await this.findProductWithRelations(productId);

    const existingLike = await this.prisma.productLike.findUnique({
      where: {
        userId_productId: {
          userId: currentUserId,
          productId,
        },
      },
      select: {
        id: true,
      },
    });

    return {
      isLiked: existingLike != null,
    };
  }

  async addComment(
    currentUserId: string,
    productId: string,
    dto: CreateProductCommentDto,
  ) {
    const product = await this.findProductWithRelations(productId);
    const content = dto.content.trim();
    const requestedParentCommentId = dto.parentCommentId?.trim() || undefined;
    let parentCommentId: string | undefined;

    if (!content) {
      throw new BadRequestException("Comment content is required");
    }

    if (requestedParentCommentId) {
      const parentComment = await this.prisma.productComment.findFirst({
        where: {
          id: requestedParentCommentId,
          productId,
        },
        select: {
          id: true,
          parentCommentId: true,
        },
      });

      if (!parentComment) {
        throw new NotFoundException("Parent comment not found");
      }

      parentCommentId =
        parentComment.parentCommentId?.trim() || parentComment.id;
    }

    const mentionUserIds = Array.from(
      new Set(
        (dto.mentionUserIds ?? [])
          .map((userId) => userId.trim())
          .filter((userId) => userId.length > 0),
      ),
    );

    const validMentionUsers = mentionUserIds.length
      ? await this.prisma.user.findMany({
          where: {
            id: {
              in: mentionUserIds,
            },
          },
          select: {
            id: true,
          },
        })
      : [];

    const comment = await this.prisma.productComment.create({
      data: {
        userId: currentUserId,
        productId,
        content,
        parentCommentId,
        mentions: validMentionUsers.length
          ? {
              create: validMentionUsers.map((user) => ({
                mentionedUser: {
                  connect: {
                    id: user.id,
                  },
                },
              })),
            }
          : undefined,
      },
      include: {
        user: true,
        mentions: {
          include: {
            mentionedUser: true,
          },
          orderBy: {
            createdAt: "asc",
          },
        },
      },
    });

    const updatedProduct = await this.findProductWithRelations(productId);
    const serializedComment = this.serializeComment(comment);
    this.emitProductUpdatedEvent({
      product: updatedProduct,
      actorUserId: currentUserId,
      action: "commented",
      comment: serializedComment,
    });
    await this.emitSellerProfileUpdatedByProfileId(product.sellerProfile.id);
    if (product.sellerProfile.userId !== currentUserId) {
      await this.emitNotificationUpdatedEvent(
        product.sellerProfile.userId,
        "product_comment",
      );
      await this.pushNotificationsService.sendSellerProductCommentNotification({
        recipientUserId: product.sellerProfile.userId,
        commenterUserId: currentUserId,
        commenterDisplayName: comment.user.displayName,
        commenterAvatarUrl: comment.user.avatarUrl ?? undefined,
        productId: product.id,
        productTitle: product.title,
        productImageUrl: product.imageUrl,
      });
    }

    await this.pushNotificationsService.sendFollowedProductCommentNotification({
      sellerProfileId: product.sellerProfile.id,
      sellerUserId: product.sellerProfile.userId,
      commenterUserId: currentUserId,
      commenterDisplayName: comment.user.displayName,
      sellerDisplayName: product.sellerProfile.studioName,
      sellerAvatarUrl: product.sellerProfile.user.avatarUrl ?? undefined,
      productId: product.id,
      productTitle: product.title,
      productImageUrl: product.imageUrl,
    });
    await this.emitNotificationRefreshToSellerFollowers(
      product.sellerProfile.id,
      [currentUserId],
    );

    return {
      product: this.toEntity(updatedProduct),
      comment: serializedComment,
    };
  }

  private serializeCommentTree(
    comments: ProductCommentWithRelations[],
  ): SerializedProductComment[] {
    const nodes = new Map<string, SerializedProductComment>();
    const roots: SerializedProductComment[] = [];
    const commentParents = new Map<string, string | null>();

    for (const comment of comments) {
      nodes.set(comment.id, this.serializeComment(comment));
      commentParents.set(comment.id, comment.parentCommentId ?? null);
    }

    for (const comment of comments) {
      const node = nodes.get(comment.id);
      if (!node) {
        continue;
      }

      const rootParentCommentId = this.resolveThreadRootCommentId(
        comment.id,
        commentParents,
      );
      if (rootParentCommentId && nodes.has(rootParentCommentId)) {
        nodes.get(rootParentCommentId)?.replies.push(node);
        continue;
      }

      roots.push(node);
    }

    roots.sort(
      (left, right) => Date.parse(right.createdAt) - Date.parse(left.createdAt),
    );
    for (const finalComment of roots) {
      finalComment.replies.sort(
        (left, right) =>
          Date.parse(left.createdAt) - Date.parse(right.createdAt),
      );
    }
    return roots;
  }

  private resolveThreadRootCommentId(
    commentId: string,
    commentParents: Map<string, string | null>,
  ): string | undefined {
    let currentCommentId = commentId;
    let parentCommentId = commentParents.get(currentCommentId) ?? undefined;

    if (!parentCommentId) {
      return undefined;
    }

    while (parentCommentId) {
      const nextParentCommentId =
        commentParents.get(parentCommentId) ?? undefined;
      if (!nextParentCommentId) {
        return parentCommentId;
      }
      currentCommentId = parentCommentId;
      parentCommentId = commentParents.get(currentCommentId) ?? undefined;
    }

    return undefined;
  }

  private serializeComment(
    comment: ProductCommentWithRelations,
  ): SerializedProductComment {
    return {
      id: comment.id,
      content: comment.content,
      createdAt: comment.createdAt.toISOString(),
      updatedAt: comment.updatedAt.toISOString(),
      parentCommentId: comment.parentCommentId ?? null,
      author: {
        id: comment.user.id,
        displayName: comment.user.displayName,
        avatarUrl: this.resolveUserAvatarUrl(comment.user.avatarUrl),
      },
      mentions: comment.mentions.map((mention) => ({
        id: mention.id,
        userId: mention.mentionedUser.id,
        displayName: mention.mentionedUser.displayName,
        avatarUrl: this.resolveUserAvatarUrl(mention.mentionedUser.avatarUrl),
      })),
      replies: [],
    };
  }

  private resolveUserAvatarUrl(avatarUrl?: string | null) {
    return (
      avatarUrl ??
      "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=600"
    );
  }

  private async emitNotificationRefreshToSellerFollowers(
    sellerProfileId: string,
    excludedUserIds: string[],
  ) {
    const followerLinks = await this.prisma.sellerFollow.findMany({
      where: {
        sellerProfileId,
        followerUserId: {
          notIn: excludedUserIds,
        },
      },
      select: {
        followerUserId: true,
      },
    });

    for (const followerLink of followerLinks) {
      await this.emitNotificationUpdatedEvent(
        followerLink.followerUserId,
        "followed_seller_activity",
      );
    }
  }

  async shareProduct(currentUserId: string, productId: string) {
    const product = await this.findProductWithRelations(productId);

    await this.prisma.productShare.create({
      data: {
        userId: currentUserId,
        productId,
      },
    });

    const updatedProduct = await this.findProductWithRelations(productId);
    this.emitProductUpdatedEvent({
      product: updatedProduct,
      actorUserId: currentUserId,
      action: "shared",
    });
    await this.emitSellerProfileUpdatedByProfileId(product.sellerProfile.id);
    return this.toEntity(updatedProduct);
  }

  private async emitNotificationUpdatedEvent(
    userId: string,
    reason:
      | "product_like"
      | "product_comment"
      | "followed_seller_activity"
      | "seller_follow",
  ) {
    const unreadCount = await this.notificationsService.countUnread(userId);
    this.conversationsRealtimeGateway.emitNotificationEvent(userId, {
      type: "notifications:updated",
      userId,
      reason,
      unreadCount,
    });
  }

  private emitProductUpdatedEvent(args: {
    product: ProductWithRelations;
    actorUserId: string;
    action:
      | "liked"
      | "unliked"
      | "commented"
      | "shared"
      | "updated"
      | "availability_changed";
    comment?: Record<string, unknown>;
  }) {
    this.conversationsRealtimeGateway.emitProductEvent({
      type: "product:updated",
      productId: args.product.id,
      actorUserId: args.actorUserId,
      action: args.action,
      product: this.toEntity(args.product) as unknown as Record<
        string,
        unknown
      >,
      comment: args.comment ?? null,
    });
  }

  async findAll(params: {
    limit: number;
    skip: number;
    categorySlug?: string;
    userLocationLabel?: string;
    userLocationLatitude?: number;
    userLocationLongitude?: number;
  }) {
    const limit = Number.isFinite(params.limit)
      ? Math.min(Math.max(params.limit, 1), 30)
      : 10;
    const skip = Number.isFinite(params.skip) ? Math.max(params.skip, 0) : 0;
    const locationContext = this.buildLocationContext(params);
    const locationCandidateTake = Math.min(
      Math.max(skip + limit * 4, limit * 2, 80),
      240,
    );

    const where = {
      isAvailable: true,
      ...(params.categorySlug
        ? {
            category: {
              slug: params.categorySlug,
            },
          }
        : {}),
    };

    const productQuery = {
      where,
      include: {
        category: true,
        _count: {
          select: {
            likes: true,
            comments: true,
            shares: true,
          },
        },
        productImages: {
          orderBy: {
            sortOrder: "asc" as const,
          },
        },
        sellerProfile: {
          include: {
            user: true,
          },
        },
      },
    };

    const [items, total] = locationContext
      ? await Promise.all([
          this.prisma.product.findMany({
            ...productQuery,
            orderBy: {
              createdAt: "desc",
            },
            take: locationCandidateTake,
          }),
          this.prisma.product.count({ where }),
        ])
      : await Promise.all([
          this.prisma.product.findMany({
            ...productQuery,
            orderBy: {
              createdAt: "desc",
            },
            take: limit,
            skip,
          }),
          this.prisma.product.count({ where }),
        ]);

    const pagedItems = locationContext
      ? this.rankProductsByLocation(items, locationContext)
          .slice(skip, skip + limit)
          .map((candidate) => candidate.product)
      : items;

    return {
      products: pagedItems.map((product) => this.toEntity(product)),
      total,
      limit,
      skip,
    };
  }

  async findOne(id: string) {
    const product = await this.prisma.product.findUnique({
      where: { id },
      include: {
        category: true,
        _count: {
          select: {
            likes: true,
            comments: true,
            shares: true,
          },
        },
        productImages: {
          orderBy: {
            sortOrder: "asc",
          },
        },
        sellerProfile: {
          include: {
            user: true,
          },
        },
      },
    });

    if (!product) {
      throw new NotFoundException("Product not found");
    }

    return this.toEntity(product);
  }

  private async resolveCategory(dto: {
    categoryId?: string;
    categorySlug?: string;
    categoryName?: string;
  }) {
    const categoryId = dto.categoryId?.trim();
    if ((categoryId?.length ?? 0) > 0) {
      const category = await this.prisma.category.findUnique({
        where: { id: categoryId },
      });

      if (!category) {
        throw new NotFoundException("Category not found");
      }

      return category;
    }

    const rawCategoryName = dto.categoryName?.trim();
    const rawCategorySlug = dto.categorySlug?.trim();

    if (!rawCategoryName && !rawCategorySlug) {
      throw new BadRequestException(
        "categoryId, categorySlug or categoryName is required.",
      );
    }

    const normalizedSlug = this.toSlug(
      rawCategorySlug ?? rawCategoryName ?? "",
    );
    const category = await this.prisma.category.findFirst({
      where: {
        OR: [
          rawCategoryName != null && rawCategoryName.length > 0
            ? { name: { equals: rawCategoryName, mode: "insensitive" } }
            : undefined,
          normalizedSlug.length > 0
            ? { slug: { equals: normalizedSlug, mode: "insensitive" } }
            : undefined,
        ].filter(Boolean) as Prisma.CategoryWhereInput[],
      },
    });

    if (category) {
      return category;
    }

    if (rawCategoryName != null && rawCategoryName.length > 0) {
      return this.prisma.category.create({
        data: {
          name: rawCategoryName,
          slug:
            normalizedSlug.length > 0
              ? normalizedSlug
              : this.toSlug(rawCategoryName),
        },
      });
    }

    throw new NotFoundException("Category not found");
  }

  private async resolveProductImageUrls(
    sellerProfileId: string,
    dto: { imageUrl?: string; imageOrderJson?: string },
    files: Express.Multer.File[] = [],
    fallbackImageUrls: string[] = [],
  ) {
    const uploadedImageUrls = await Promise.all(
      files.map(async (file) => {
        const uploadResult = await this.cloudinaryService.uploadProductImage(
          file,
          sellerProfileId,
        );
        return uploadResult.imageUrl;
      }),
    );

    const orderedImageUrls = this.buildOrderedImageUrls(
      dto.imageOrderJson,
      uploadedImageUrls,
      fallbackImageUrls,
    );
    if (orderedImageUrls.length > 0) {
      return orderedImageUrls;
    }

    const imageUrl = dto.imageUrl?.trim();
    if (imageUrl) {
      return [imageUrl];
    }

    if (uploadedImageUrls.length > 0) {
      return uploadedImageUrls;
    }

    if (fallbackImageUrls.length > 0) {
      return fallbackImageUrls;
    }

    throw new BadRequestException("A product image is required.");
  }

  private buildOrderedImageUrls(
    imageOrderJson: string | undefined,
    uploadedImageUrls: string[],
    fallbackImageUrls: string[],
  ) {
    const tokens = this.parseImageOrderTokens(imageOrderJson);
    if (tokens.length === 0) {
      return [];
    }

    const orderedImageUrls = tokens
      .map((token) => {
        const normalizedToken = token.trim();
        if (normalizedToken.length === 0) {
          return null;
        }

        const uploadedTokenMatch = /^__upload__(\d+)$/.exec(normalizedToken);
        if (uploadedTokenMatch) {
          const uploadIndex = Number(uploadedTokenMatch[1]);
          const uploadedImageUrl = uploadedImageUrls[uploadIndex];
          if (!uploadedImageUrl) {
            throw new BadRequestException(
              "Invalid uploaded image order payload.",
            );
          }

          return uploadedImageUrl;
        }

        if (fallbackImageUrls.includes(normalizedToken)) {
          return normalizedToken;
        }

        if (uploadedImageUrls.length === 0) {
          return normalizedToken;
        }

        throw new BadRequestException("Invalid retained image payload.");
      })
      .filter((imageUrl): imageUrl is string => imageUrl != null);

    return orderedImageUrls;
  }

  private parseImageOrderTokens(imageOrderJson?: string) {
    const normalizedPayload = imageOrderJson?.trim();
    if (!normalizedPayload) {
      return [];
    }

    try {
      const parsedPayload = JSON.parse(normalizedPayload);
      if (!Array.isArray(parsedPayload)) {
        throw new Error("Image order payload is not an array");
      }

      return parsedPayload.filter(
        (token): token is string => typeof token === "string",
      );
    } catch {
      throw new BadRequestException("Invalid image order payload.");
    }
  }

  private toSlug(value: string) {
    return value
      .toLowerCase()
      .trim()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "");
  }

  private async findProductWithRelations(productId: string) {
    const product = await this.prisma.product.findUnique({
      where: { id: productId },
      include: {
        category: true,
        _count: {
          select: {
            likes: true,
            comments: true,
            shares: true,
          },
        },
        productImages: {
          orderBy: {
            sortOrder: "asc",
          },
        },
        sellerProfile: {
          include: {
            user: true,
          },
        },
      },
    });

    if (!product) {
      throw new NotFoundException("Product not found");
    }

    return product;
  }

  private async emitSellerProfileUpdatedByProfileId(sellerProfileId: string) {
    const sellerProfile = await this.prisma.sellerProfile.findUnique({
      where: { id: sellerProfileId },
      include: {
        user: true,
        _count: {
          select: {
            products: true,
          },
        },
        products: {
          include: {
            category: true,
            _count: {
              select: {
                likes: true,
                comments: true,
                shares: true,
              },
            },
            productImages: {
              orderBy: {
                sortOrder: "asc",
              },
            },
          },
          orderBy: {
            createdAt: "desc",
          },
        },
      },
    });

    if (!sellerProfile) {
      return;
    }

    const [followerCount, visitorCount, totalLikesCount] = await Promise.all([
      this.prisma.sellerFollow.count({
        where: { sellerProfileId },
      }),
      this.prisma.sellerProfileView.count({
        where: { sellerProfileId },
      }),
      this.prisma.productLike.count({
        where: {
          product: {
            sellerProfileId,
          },
        },
      }),
    ]);

    this.conversationsRealtimeGateway.emitProfileEvent(sellerProfile.userId, {
      type: "profile:updated",
      userId: sellerProfile.userId,
      profile: {
        id: sellerProfile.user.id,
        role: sellerProfile.user.role,
        shopRequestStatus: sellerProfile.user.shopRequestStatus,
        shopRequestSubmittedAt:
          sellerProfile.user.shopRequestSubmittedAt?.toISOString() ?? null,
        shopRequestReviewedAt:
          sellerProfile.user.shopRequestReviewedAt?.toISOString() ?? null,
        sellerProfile: {
          id: sellerProfile.id,
          studioName: sellerProfile.studioName,
          description: sellerProfile.description,
          city: sellerProfile.city,
          country: sellerProfile.country,
          followerCount,
          visitorCount,
          productCount: sellerProfile._count.products,
          totalLikesCount,
          products: sellerProfile.products.map((product) => ({
            id: product.id,
            title: product.title,
            description: product.description,
            imageUrl: product.imageUrl,
            priceAmount: product.priceAmount.toNumber(),
            currencyCode: product.currencyCode,
            category: product.category.name,
            categoryId: product.categoryId,
            condition: product.condition ?? undefined,
            hasWarranty: product.hasWarranty,
            warrantyDurationValue: product.warrantyDurationValue ?? undefined,
            warrantyDurationUnit: product.warrantyDurationUnit ?? undefined,
            likesCount: product._count.likes,
            commentsCount: product._count.comments,
            sharesCount: product._count.shares,
            createdAt: product.createdAt.toISOString(),
            images:
              product.productImages.length > 0
                ? product.productImages.map((image) => image.imageUrl)
                : [product.imageUrl],
          })),
        },
      },
    });
  }

  private toEntity(product: ProductWithRelations): ProductEntity {
    const imageUrls =
      product.productImages.length > 0
        ? product.productImages.map((image) => image.imageUrl)
        : [product.imageUrl];

    return {
      id: product.id,
      title: product.title,
      description: product.description,
      price: product.priceAmount.toNumber(),
      currency: product.currencyCode,
      category: product.category.name,
      categoryId: product.categoryId,
      seller: {
        id: product.sellerProfile.id,
        userId: product.sellerProfile.userId,
        name: product.sellerProfile.studioName,
        avatarUrl:
          product.sellerProfile.user.avatarUrl ??
          "https://i.pravatar.cc/240?img=12",
        isSellerCertified: product.sellerProfile.user.isSellerCertified,
      },
      images: imageUrls,
      thumbnail: imageUrls[0],
      isAvailable: product.isAvailable,
      condition: product.condition ?? undefined,
      hasWarranty: product.hasWarranty,
      warrantyDurationValue: product.warrantyDurationValue ?? undefined,
      warrantyDurationUnit: product.warrantyDurationUnit ?? undefined,
      likesCount: product._count.likes,
      commentsCount: product._count.comments,
      sharesCount: product._count.shares,
      createdAt: product.createdAt.toISOString(),
      city: product.sellerProfile.city ?? undefined,
      locationLabel: this.joinNonEmpty([
        product.sellerProfile.city,
        product.sellerProfile.country,
        product.sellerProfile.user.locationLabel,
      ]),
      locationLatitude: this.toNullableNumber(
        product.sellerProfile.user.locationLatitude,
      ),
      locationLongitude: this.toNullableNumber(
        product.sellerProfile.user.locationLongitude,
      ),
    };
  }
}
