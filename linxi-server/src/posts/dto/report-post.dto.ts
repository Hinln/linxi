import { IsString, IsNotEmpty, IsEnum, IsNumber } from 'class-validator';
import { ContentType } from '@prisma/client';

export class ReportPostDto {
  @IsEnum(ContentType)
  targetType: ContentType = ContentType.POST;

  @IsNumber()
  @IsNotEmpty()
  targetId: number;

  @IsString()
  @IsNotEmpty()
  reason: string;
}
