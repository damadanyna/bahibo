import { IsNotEmpty, IsOptional, IsString, MaxLength } from "class-validator";

export class CreateMessageDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(2000)
  content!: string;

  @IsOptional()
  @IsString()
  @MaxLength(191)
  clientMessageId?: string;

  @IsOptional()
  @IsString()
  replyToMessageId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(191)
  replyToSenderUserId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(240)
  replyToSenderName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  replyToContent?: string;

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
