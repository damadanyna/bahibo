import { IsEnum, IsOptional, IsPhoneNumber, IsString, MinLength } from 'class-validator';

import { UserRole } from '@prisma/client';

export class RegisterDto {
  @IsPhoneNumber()
  phoneE164: string;

  @IsString()
  @MinLength(2)
  displayName: string;

  @IsString()
  @MinLength(6)
  password: string;

  @IsOptional()
  @IsEnum(UserRole)
  role?: UserRole;
}
