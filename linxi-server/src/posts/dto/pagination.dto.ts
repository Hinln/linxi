import { IsNumber, IsOptional, Min, IsString } from 'class-validator';
import { Transform } from 'class-transformer';

export class PaginationDto {
  @IsOptional()
  @IsNumber()
  @Min(1)
  @Transform(({ value }) => parseInt(value, 10))
  limit: number = 20;

  @IsOptional()
  @IsString()
  cursor: string; // Use createdAt as cursor (ISO string)
}
