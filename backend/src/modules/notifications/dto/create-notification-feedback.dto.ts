import { IsNotEmpty, IsString, MaxLength } from "class-validator";

export class CreateNotificationFeedbackDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(50000)
  message!: string;
}
