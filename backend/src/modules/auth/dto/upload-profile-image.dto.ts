import { IsPhoneNumber } from 'class-validator';

export class UploadProfileImageDto {
  @IsPhoneNumber()
  phoneE164: string;
}