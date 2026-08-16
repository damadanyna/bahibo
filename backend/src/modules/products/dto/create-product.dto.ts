import { ProductCondition, WarrantyDurationUnit } from '@prisma/client';
import { Transform, Type } from 'class-transformer';
import {
  IsBoolean,
  IsEnum,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUrl,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

function transformOptionalBoolean({ value }: { value: unknown }) {
  if (typeof value === 'boolean') {
    return value;
  }
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    if (normalized == 'true') {
      return true;
    }
    if (normalized == 'false') {
      return false;
    }
  }
  return value;
}

export class CreateProductDto {
  @IsString()
  @MinLength(2)
  @MaxLength(160)
  title: string;

  @IsString()
  @MinLength(10)
  @MaxLength(2000)
  description: string;

  @Type(() => Number)
  @IsNumber()
  @Min(1)
  priceAmount: number;

  @IsOptional()
  @IsString()
  @MaxLength(12)
  currencyCode?: string;

  @IsOptional()
  @IsString()
  categoryId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  categorySlug?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  categoryName?: string;

  @IsOptional()
  @Transform(transformOptionalBoolean)
  @IsBoolean()
  isAvailable?: boolean;

  @IsOptional()
  @IsEnum(ProductCondition)
  condition?: ProductCondition;

  @IsOptional()
  @Transform(transformOptionalBoolean)
  @IsBoolean()
  hasWarranty?: boolean;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  warrantyDurationValue?: number;

  @IsOptional()
  @IsEnum(WarrantyDurationUnit)
  warrantyDurationUnit?: WarrantyDurationUnit;

  @IsOptional()
  @IsUrl({ require_tld: false })
  imageUrl?: string;

  @IsOptional()
  @IsString()
  imageOrderJson?: string;
}