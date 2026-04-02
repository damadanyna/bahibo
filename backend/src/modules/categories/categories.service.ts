import { Injectable } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { CategoryEntity } from './entities/category.entity';

@Injectable()
export class CategoriesService {
  constructor(private readonly prisma: PrismaService) {}

  async findAll(): Promise<CategoryEntity[]> {
    return this.prisma.category.findMany({
      orderBy: {
        name: 'asc',
      },
      select: {
        id: true,
        name: true,
        slug: true,
        icon: true,
      },
    }) as Promise<CategoryEntity[]>;
  }
}
