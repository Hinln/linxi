import { Controller, Get, Request, UseGuards } from '@nestjs/common';
import { ChatService } from './chat.service';

@Controller('chat')
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

  @Get('conversations')
  async getConversations(@Request() req: any) {
    return this.chatService.getConversations(req.user.userId);
  }
}
