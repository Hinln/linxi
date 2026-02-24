import { IsNumber, IsOptional, Min, IsString } from 'class-validator';
import { Transform } from 'class-transformer';

export class ReportPaginationDto {
  @IsOptional()
  @IsNumber()
  @Min(1)
  @Transform(({ value }) => parseInt(value, 10))
  limit: number = 20;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Transform(({ value }) => parseInt(value, 10))
  offset: number = 0;
}
