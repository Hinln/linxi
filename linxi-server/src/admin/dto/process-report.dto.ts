import { IsBoolean, IsNotEmpty, IsString, IsOptional } from 'class-validator';

export class ProcessReportDto {
  @IsBoolean()
  @IsNotEmpty()
  accepted: boolean;

  @IsString()
  @IsOptional()
  details: string; // Optional admin notes
}
