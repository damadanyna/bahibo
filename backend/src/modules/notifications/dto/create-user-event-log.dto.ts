import { IsArray, IsInt, IsOptional, IsString, Min } from "class-validator";

export class CreateUserEventLogDto {
  @IsInt()
  @Min(0)
  eventCount!: number;

  @IsArray()
  events!: Record<string, unknown>[];

  @IsOptional()
  @IsString()
  syncedAt?: string;
}
