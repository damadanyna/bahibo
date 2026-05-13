import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

export class CreateNotificationFeedbackDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(1000)
  message!: string;
}