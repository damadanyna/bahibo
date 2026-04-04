import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { CloudinaryService } from '../auth/cloudinary.service';
import { ConversationsRealtimeGateway } from '../conversations/realtime/conversations-realtime.gateway';
import { PrismaService } from '../prisma/prisma.service';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { ProductEntity } from './entities/product.entity';

type ProductWithRelations = Prisma.ProductGetPayload<{
  include: {
    category: true;
    _count: {
      select: {
        likes: true;
      };
    };
    productImages: {
      orderBy: {
        sortOrder: 'asc';
      };
    };
    sellerProfile: {
      include: {
        user: true;
      };
    };
  };
}>;

@Injectable()
export class ProductsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly cloudinaryService: CloudinaryService,
    private readonly conversationsRealtimeGateway: ConversationsRealtimeGateway,
  ) {}

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
      throw new BadRequestException('Seller profile not found for this user.');
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
        currencyCode: (dto.currencyCode?.trim().toUpperCase() ?? 'MGA'),
        isAvailable: dto.isAvailable ?? true,
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
          },
        },
        productImages: {
          orderBy: {
            sortOrder: 'asc',
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
      throw new BadRequestException('Seller profile not found for this user.');
    }

    const existingProduct = await this.prisma.product.findUnique({
      where: { id: productId },
      include: {
        category: true,
        _count: {
          select: {
            likes: true,
          },
        },
        productImages: {
          orderBy: {
            sortOrder: 'asc',
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
      throw new NotFoundException('Product not found');
    }

    if (existingProduct.sellerProfile.userId != currentUser.userId) {
      throw new NotFoundException('Product not found');
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
          },
        },
        productImages: {
          orderBy: {
            sortOrder: 'asc',
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
    return this.toEntity(updatedProduct);
  }

  async likeProduct(currentUserId: string, productId: string) {
    const product = await this.prisma.product.findUnique({
      where: { id: productId },
      include: {
        category: true,
        _count: {
          select: {
            likes: true,
          },
        },
        productImages: {
          orderBy: {
            sortOrder: 'asc',
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
      throw new NotFoundException('Product not found');
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
    await this.emitSellerProfileUpdatedByProfileId(updatedProduct.sellerProfile.id);
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
    await this.emitSellerProfileUpdatedByProfileId(updatedProduct.sellerProfile.id);
    return this.toEntity(updatedProduct);
  }

  async findAll(params: {
    limit: number;
    skip: number;
    categorySlug?: string;
  }) {
    const limit = Number.isFinite(params.limit)
      ? Math.min(Math.max(params.limit, 1), 30)
      : 10;
    const skip = Number.isFinite(params.skip) ? Math.max(params.skip, 0) : 0;

    const where = params.categorySlug
      ? {
          category: {
            slug: params.categorySlug,
          },
        }
      : {};

    const [items, total] = await Promise.all([
      this.prisma.product.findMany({
        where,
        include: {
          category: true,
          _count: {
            select: {
              likes: true,
            },
          },
          productImages: {
            orderBy: {
              sortOrder: 'asc',
            },
          },
          sellerProfile: {
            include: {
              user: true,
            },
          },
        },
        orderBy: {
          createdAt: 'desc',
        },
        take: limit,
        skip,
      }),
      this.prisma.product.count({ where }),
    ]);

    return {
      products: items.map((product) => this.toEntity(product)),
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
          },
        },
        productImages: {
          orderBy: {
            sortOrder: 'asc',
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
      throw new NotFoundException('Product not found');
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
        throw new NotFoundException('Category not found');
      }

      return category;
    }

    const rawCategoryName = dto.categoryName?.trim();
    const rawCategorySlug = dto.categorySlug?.trim();

    if (!rawCategoryName && !rawCategorySlug) {
      throw new BadRequestException(
        'categoryId, categorySlug or categoryName is required.',
      );
    }

    const normalizedSlug = this.toSlug(rawCategorySlug ?? rawCategoryName ?? '');
    const category = await this.prisma.category.findFirst({
      where: {
        OR: [
          rawCategoryName != null && rawCategoryName.length > 0
            ? { name: { equals: rawCategoryName, mode: 'insensitive' } }
            : undefined,
          normalizedSlug.length > 0
            ? { slug: { equals: normalizedSlug, mode: 'insensitive' } }
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
          slug: normalizedSlug.length > 0 ? normalizedSlug : this.toSlug(rawCategoryName),
        },
      });
    }

    throw new NotFoundException('Category not found');
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

    throw new BadRequestException('A product image is required.');
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
            throw new BadRequestException('Invalid uploaded image order payload.');
          }

          return uploadedImageUrl;
        }

        if (fallbackImageUrls.includes(normalizedToken)) {
          return normalizedToken;
        }

        if (uploadedImageUrls.length === 0) {
          return normalizedToken;
        }

        throw new BadRequestException('Invalid retained image payload.');
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
        throw new Error('Image order payload is not an array');
      }

      return parsedPayload.filter((token): token is string => typeof token === 'string');
    } catch {
      throw new BadRequestException('Invalid image order payload.');
    }
  }

  private toSlug(value: string) {
    return value
      .toLowerCase()
      .trim()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '');
  }

  private async findProductWithRelations(productId: string) {
    const product = await this.prisma.product.findUnique({
      where: { id: productId },
      include: {
        category: true,
        _count: {
          select: {
            likes: true,
          },
        },
        productImages: {
          orderBy: {
            sortOrder: 'asc',
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
      throw new NotFoundException('Product not found');
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
              },
            },
            productImages: {
              orderBy: {
                sortOrder: 'asc',
              },
            },
          },
          orderBy: {
            createdAt: 'desc',
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
      type: 'profile:updated',
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
            likesCount: product._count.likes,
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
    const imageUrls = product.productImages.length > 0
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
        name: product.sellerProfile.studioName,
        avatarUrl:
          product.sellerProfile.user.avatarUrl ??
          'https://i.pravatar.cc/240?img=12',
      },
      images: imageUrls,
      thumbnail: imageUrls[0],
      isAvailable: product.isAvailable,
      likesCount: product._count.likes,
      createdAt: product.createdAt.toISOString(),
    };
  }
}
