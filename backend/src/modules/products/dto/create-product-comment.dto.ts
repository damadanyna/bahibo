import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

export class CreateProductCommentDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(1000)
  content: string;
}