import { Controller, Get, Param, Query } from '@nestjs/common';

import { ProductsService } from './products.service';

@Controller('products')
export class ProductsController {
  constructor(private readonly productsService: ProductsService) {}

  @Get()
  async findAll(
    @Query('limit') limit?: string,
    @Query('skip') skip?: string,
    @Query('categorySlug') categorySlug?: string,
  ) {
    return {
      success: true,
      message: 'Products fetched successfully',
      data: await this.productsService.findAll({
        limit: Number(limit ?? '10'),
        skip: Number(skip ?? '0'),
        categorySlug,
      }),
    };
  }

  @Get(':id')
  async findOne(@Param('id') id: string) {
    return {
      success: true,
      message: 'Product fetched successfully',
      data: await this.productsService.findOne(id),
    };
  }
}
