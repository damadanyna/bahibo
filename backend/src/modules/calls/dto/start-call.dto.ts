import { IsNotEmpty, IsString } from 'class-validator';

export class StartCallDto {
  /** The call is placed to the other participant of this conversation. */
  @IsString()
  @IsNotEmpty()
  conversationId!: string;
}
