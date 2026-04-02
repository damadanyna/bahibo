import {
  IsOptional,
  IsPhoneNumber,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

export class RequestOtpDto {
  @IsString()
  @MinLength(2)
  @MaxLength(80)
  countryName: string;

  @IsString()
  @MinLength(2)
  @MaxLength(8)
  countryDialCode: string;

  @IsPhoneNumber()
  phoneE164: string;

  @IsOptional()
  @IsString()
  @MinLength(11)
  @MaxLength(11)
  appSignature?: string;
}