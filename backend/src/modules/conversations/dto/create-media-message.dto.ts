import {
  IsIn,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';

export class CreateMediaMessageDto {
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  content?: string;

  @IsString()
  @IsIn(['IMAGE', 'DOCUMENT'])
  kind!: 'IMAGE' | 'DOCUMENT';

  @IsString()
  @IsIn(['image', 'document'])
  mediaType!: 'image' | 'document';

  @IsString()
  @IsNotEmpty()
  @MaxLength(2048)
  publicUrl!: string;

  @IsOptional()
  @IsString()
  @MaxLength(2048)
  previewUrl?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2048)
  thumbnailUrl?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  fileName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(191)
  mimeType?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  fileSizeBytes?: number;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  storageProvider?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  storageKey?: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  mediaGroupId?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  width?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  height?: number;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  encryptionScheme?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1024)
  encryptionKeyB64?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1024)
  encryptionIvB64?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1024)
  fileSha256B64?: string;

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
}