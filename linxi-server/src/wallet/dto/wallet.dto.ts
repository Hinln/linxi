import { IsNumber, IsOptional, Min, IsEnum, IsString, IsNotEmpty } from 'class-validator';
import { TransactionType } from '@prisma/client';

export class RechargeDto {
  @IsNumber()
  @Min(1)
  amount: number;

  @IsString()
  @IsOptional()
  remark?: string;
}

export class CallbackDto {
  @IsString()
  @IsNotEmpty()
  outTradeNo: string;

  @IsString()
  @IsNotEmpty()
  sign: string;

  // Simulate payment gateway parameters
  @IsString()
  @IsOptional()
  status: string;
}
