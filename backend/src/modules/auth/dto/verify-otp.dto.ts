import { IsPhoneNumber, IsString, Length } from 'class-validator';

export class VerifyOtpDto {
  @IsPhoneNumber()
  phoneE164: string;

  @IsString()
  @Length(6, 6)
  otpCode: string;
}