import { IsString, IsNotEmpty } from 'class-validator';

export class QueryRealPersonDto {
  @IsString()
  @IsNotEmpty()
  certifyId: string;
}
