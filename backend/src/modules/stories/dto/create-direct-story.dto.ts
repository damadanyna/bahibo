import { Transform } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  Min,
} from 'class-validator';

const upperCase = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim().toUpperCase() : value;

const toNumber = ({ value }: { value: unknown }) =>
  typeof value === 'string' && value.trim() !== '' ? Number(value) : value;

/** `POST /stories/direct-signature`: which kind of media the phone will upload. */
export class CreateStoryUploadSignatureDto {
  @Transform(upperCase)
  @IsIn(['IMAGE', 'VIDEO'])
  mediaType!: 'IMAGE' | 'VIDEO';
}

/**
 * `POST /stories/direct`: the phone uploaded the media straight to
 * Cloudinary and hands back what the upload response returned. The
 * backend validates the id and signature before trusting any of it.
 */
export class CreateDirectStoryDto {
  @Transform(upperCase)
  @IsIn(['IMAGE', 'VIDEO'])
  mediaType!: 'IMAGE' | 'VIDEO';

  /** `public_id` of the upload response (folder included). */
  @IsString()
  @MaxLength(255)
  publicId!: string;

  /** `version` of the upload response. */
  @Transform(toNumber)
  @IsInt()
  @Min(1)
  version!: number;

  /** `signature` of the upload response. */
  @IsString()
  @MaxLength(128)
  signature!: string;

  /** `format` of the upload response (container of the file as uploaded). */
  @IsOptional()
  @Transform(({ value }) =>
    typeof value === 'string' ? value.trim().toLowerCase() : value,
  )
  @Matches(/^[a-z0-9]{1,8}$/)
  format?: string;

  /** Client-measured video length, fallback when Cloudinary reports none. */
  @IsOptional()
  @Transform(toNumber)
  @IsInt()
  @Min(0)
  durationSeconds?: number;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  caption?: string;
}
