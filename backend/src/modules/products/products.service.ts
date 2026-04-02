import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { ProductEntity } from './entities/product.entity';

type ProductWithRelations = Prisma.ProductGetPayload<{
  include: {
    category: true;
    sellerProfile: {
      include: {
        user: true;
      };
    };
  };
}>;

@Injectable()
export class ProductsService {
  constructor(private readonly prisma: PrismaService) {}

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

  private toEntity(product: ProductWithRelations): ProductEntity {
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
      images: [product.imageUrl],
      thumbnail: product.imageUrl,
      isAvailable: product.isAvailable,
      createdAt: product.createdAt.toISOString(),
    };
  }
}
