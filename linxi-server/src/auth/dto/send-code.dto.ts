import { IsString, IsNotEmpty, Matches } from 'class-validator';

export class SendCodeDto {
  @IsString()
  @IsNotEmpty()
  @Matches(/^1[3-9]\d{9}$/, { message: 'Phone number is invalid' })
  phoneNumber: string;
}
