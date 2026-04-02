import { IsPhoneNumber, IsString, MinLength } from 'class-validator';

export class LoginDto {
  @IsPhoneNumber()
  phoneE164: string;

  @IsString()
  @MinLength(6)
  password: string;
}
