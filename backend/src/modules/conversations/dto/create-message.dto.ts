import { IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateMessageDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(2000)
  content!: string;

  @IsOptional()
  @IsString()
  productId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(240)
  productTitle?: string;

  @IsOptional()
  @IsString()
  @MaxLength(240)
  productSubtitle?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  productPriceLabel?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2048)
  productImageUrl?: string;
}