import { IsString, IsNotEmpty, IsOptional, IsArray, IsNumber, IsLatitude, IsLongitude } from 'class-validator';

export class CreatePostDto {
  @IsString()
  @IsNotEmpty()
  content: string;

  @IsArray()
  @IsOptional()
  media: string[]; // List of OSS URLs

  @IsLatitude()
  @IsOptional()
  latitude: number;

  @IsLongitude()
  @IsOptional()
  longitude: number;

  @IsString()
  @IsOptional()
  address?: string;
}
