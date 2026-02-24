import { IsNumber, IsLatitude, IsLongitude, Min, Max, IsOptional } from 'class-validator';
import { Transform } from 'class-transformer';

export class NearbyDto {
  @IsLatitude()
  @Transform(({ value }) => parseFloat(value))
  latitude: number;

  @IsLongitude()
  @Transform(({ value }) => parseFloat(value))
  longitude: number;

  @IsOptional()
  @IsNumber()
  @Min(0.1)
  @Max(100)
  @Transform(({ value }) => parseFloat(value))
  distance: number = 5; // km
}
