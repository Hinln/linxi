import {
  SubscribeMessage,
  WebSocketGateway,
  OnGatewayInit,
  WebSocketServer,
  OnGatewayConnection,
  OnGatewayDisconnect,
  ConnectedSocket,
  MessageBody,
} from '@nestjs/websockets';
import { Logger, UseGuards } from '@nestjs/common';
import { Socket, Server } from 'socket.io';
import { JwtService } from '@nestjs/jwt';
import { ChatService } from './chat.service';
import { SendMessageDto } from './dto/send-message.dto';
import { RedisService } from '../common/redis/redis.service';

@WebSocketGateway({
  cors: {
    origin: '*',
  },
  namespace: 'chat',
})
export class ChatGateway implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server: Server;
  private readonly logger = new Logger(ChatGateway.name);

  constructor(
    private readonly jwtService: JwtService,
    private readonly chatService: ChatService,
    private readonly redisService: RedisService,
  ) {}

  afterInit(server: Server) {
    this.logger.log('ChatGateway initialized');
  }

  async handleConnection(client: Socket, ...args: any[]) {
    try {
      // 1. Auth Check
      const token = client.handshake.auth.token || client.handshake.headers.authorization;
      if (!token) {
        client.disconnect();
        return;
      }

      // Extract Bearer
      const bearerToken = token.startsWith('Bearer ') ? token.split(' ')[1] : token;
      const payload = this.jwtService.verify(bearerToken, {
        secret: process.env.JWT_SECRET || 'secretKey',
      });

      const userId = payload.sub;
      client.data.userId = userId;

      // 2. Map userId -> socketId in Redis
      await this.redisService.set(`socket:user:${userId}`, client.id, 0); // 0 = no expire (until disconnect)
      
      this.logger.log(`Client connected: ${client.id}, UserId: ${userId}`);
    } catch (e) {
      this.logger.error(`Connection failed: ${e.message}`);
      client.disconnect();
    }
  }

  async handleDisconnect(client: Socket) {
    const userId = client.data.userId;
    if (userId) {
      await this.redisService.del(`socket:user:${userId}`);
      this.logger.log(`Client disconnected: ${client.id}, UserId: ${userId}`);
    }
  }

  @SubscribeMessage('send_message')
  async handleSendMessage(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: SendMessageDto,
  ) {
    if (!client.data || !client.data.userId) {
       client.emit('error', { message: 'Unauthorized' });
       return;
    }
    
    const senderIdVal = client.data.userId;

    try {
        const message = await this.chatService.saveMessage(senderIdVal, payload.receiverId, payload.content, payload.type);

        const receiverSocketId = await this.redisService.get(`socket:user:${payload.receiverId}`);
        
        const response = {
            id: message.id,
            senderId: message.senderId,
            content: message.content,
            type: message.type,
            createdAt: message.createdAt,
            conversationId: message.conversationId,
        };

        if (receiverSocketId) {
            this.server.to(receiverSocketId).emit('receive_message', response);
        }

        client.emit('message_sent', response);

    } catch (error) {
        client.emit('error', { message: error.message });
    }
  }
}
