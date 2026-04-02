import {
  IsEnum,
  IsOptional,
  IsPhoneNumber,
  IsString,
  IsUrl,
  MaxLength,
  MinLength,
} from 'class-validator';

import { UserRole } from '@prisma/client';

export class RegisterDto {
  @IsPhoneNumber()
  phoneE164: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  countryName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(8)
  countryDialCode?: string;

  @IsString()
  @MinLength(2)
  displayName: string;

  @IsOptional()
  @IsUrl({ require_tld: false })
  avatarUrl?: string;

  @IsOptional()
  @IsEnum(UserRole)
  role?: UserRole;
}
