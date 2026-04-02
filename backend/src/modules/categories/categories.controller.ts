import { Controller, Get } from '@nestjs/common';

import { CategoriesService } from './categories.service';

@Controller('categories')
export class CategoriesController {
  constructor(private readonly categoriesService: CategoriesService) {}

  @Get()
  async findAll() {
    return {
      success: true,
      message: 'Categories fetched successfully',
      data: await this.categoriesService.findAll(),
    };
  }
}
