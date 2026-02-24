import { IsString, IsNotEmpty, IsEnum } from 'class-validator';

export class GetPresignedUrlDto {
  @IsString()
  @IsNotEmpty()
  fileName: string;

  @IsString()
  @IsNotEmpty()
  @IsEnum(['image/jpeg', 'image/png', 'image/gif', 'video/mp4'], {
    message: 'File type must be image/jpeg, image/png, image/gif or video/mp4',
  })
  fileType: string;
}
