import { Type } from 'class-transformer';
import {
  IsIn,
  IsLatitude,
  IsLongitude,
  IsOptional,
  IsNumber,
  IsString,
  IsUrl,
  MaxLength,
  MinLength,
  ValidateNested,
} from 'class-validator';

export class UpdateSellerProfileDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  studioName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string;

  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(80)
  city?: string;

  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(80)
  country?: string;
}

export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  displayName?: string;

  @IsOptional()
  @IsUrl({ require_tld: false })
  avatarUrl?: string;

  @IsOptional()
  @IsUrl({ require_tld: false })
  coverImageUrl?: string;

  @IsOptional()
  @IsString()
  @MaxLength(10)
  preferredLanguage?: string;

  @IsOptional()
  @IsString()
  @MaxLength(160)
  locationLabel?: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @IsLatitude()
  locationLatitude?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @IsLongitude()
  locationLongitude?: number;

  /** How the position was obtained; defaults to GPS. */
  @IsOptional()
  @IsIn(['GPS', 'MANUAL'])
  locationSource?: 'GPS' | 'MANUAL';

  @IsOptional()
  @ValidateNested()
  @Type(() => UpdateSellerProfileDto)
  sellerProfile?: UpdateSellerProfileDto;
}