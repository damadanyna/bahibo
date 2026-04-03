import { IsIn, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class RegisterDeviceTokenDto {
  @IsString()
  @MinLength(16)
  @MaxLength(4096)
  token: string;

  @IsOptional()
  @IsString()
  @IsIn(['android', 'ios', 'web'])
  platform?: string;
}