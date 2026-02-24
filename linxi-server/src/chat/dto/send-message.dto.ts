import { IsNumber, IsNotEmpty, IsString, IsEnum } from 'class-validator';
import { MessageType } from '@prisma/client';

export class SendMessageDto {
  @IsNumber()
  @IsNotEmpty()
  receiverId: number;

  @IsString()
  @IsNotEmpty()
  content: string;

  @IsEnum(MessageType)
  @IsNotEmpty()
  type: MessageType;
}
