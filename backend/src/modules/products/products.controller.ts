import {
  Body,
  Controller,
  Get,
  Patch,
  Param,
  Post,
  Query,
  Req,
  UploadedFiles,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileFieldsInterceptor } from '@nestjs/platform-express';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { ProductsService } from './products.service';

@Controller('products')
export class ProductsController {
  constructor(private readonly productsService: ProductsService) {}

  private normalizeUploadedImages(uploadedFiles?: {
    image?: Express.Multer.File[];
    images?: Express.Multer.File[];
  }) {
    return [
      ...(uploadedFiles?.image ?? []),
      ...(uploadedFiles?.images ?? []),
    ];
  }

  @UseGuards(JwtAuthGuard)
  @Post()
  @UseInterceptors(
    FileFieldsInterceptor([
      { name: 'image', maxCount: 1 },
      { name: 'images', maxCount: 10 },
    ]),
  )
  async create(
    @Req() req: { user: { userId: string; role: string } },
    @Body() dto: CreateProductDto,
    @UploadedFiles()
    uploadedFiles?: {
      image?: Express.Multer.File[];
      images?: Express.Multer.File[];
    },
  ) {
    return {
      success: true,
      message: 'Product created successfully',
      data: await this.productsService.create(
        req.user,
        dto,
        this.normalizeUploadedImages(uploadedFiles),
      ),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Patch(':id')
  @UseInterceptors(
    FileFieldsInterceptor([
      { name: 'image', maxCount: 1 },
      { name: 'images', maxCount: 10 },
    ]),
  )
  async update(
    @Req() req: { user: { userId: string; role: string } },
    @Param('id') id: string,
    @Body() dto: UpdateProductDto,
    @UploadedFiles()
    uploadedFiles?: {
      image?: Express.Multer.File[];
      images?: Express.Multer.File[];
    },
  ) {
    return {
      success: true,
      message: 'Product updated successfully',
      data: await this.productsService.update(
        req.user,
        id,
        dto,
        this.normalizeUploadedImages(uploadedFiles),
      ),
    };
  }

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
