import { Injectable, Logger, ConflictException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { WalletService } from '../wallet/wallet.service';
import { SendMessageDto } from './dto/send-message.dto';
import { TransactionType, MessageType } from '@prisma/client';

@Injectable()
export class ChatService {
  private readonly logger = new Logger(ChatService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly walletService: WalletService,
  ) {}

  /**
   * Save Message and Update Conversation
   */
  async saveMessage(senderId: number, receiverId: number, content: string, type: MessageType) {
    // Ensure conversation exists or create one
    // Convention: user1Id < user2Id to ensure uniqueness
    const user1Id = senderId < receiverId ? senderId : receiverId;
    const user2Id = senderId < receiverId ? receiverId : senderId;

    let conversation = await this.prisma.conversation.findUnique({
      where: {
        user1Id_user2Id: {
          user1Id,
          user2Id,
        },
      },
    });

    if (!conversation) {
      conversation = await this.prisma.conversation.create({
        data: {
          user1Id,
          user2Id,
        },
      });
    }

    // Check message count for fee
    // We check how many messages *this sender* has sent in this conversation
    const messageCount = await this.prisma.message.count({
      where: {
        conversationId: conversation.id,
        senderId,
      },
    });

    // Assume "not friends" for now (since we don't have friend system implemented).
    // If we had friends, we would check: const isFriend = ...
    const isFriend = false; 

    if (!isFriend && messageCount >= 3) {
      // Deduct 1 Coin
      try {
        await this.walletService.consumeCoins(senderId, 1, TransactionType.CONSUME, `Chat fee to user:${receiverId}`);
      } catch (error) {
        throw new ConflictException('Insufficient balance to send message');
      }
    }

    // 2. Create Message
    const message = await this.prisma.message.create({
      data: {
        conversationId: conversation.id,
        senderId,
        receiverId,
        content,
        type,
      },
    });

    // 3. Update Conversation (last message, unread count)
    const updateData: any = {
      lastMessageId: message.id,
      lastMessageContent: type === MessageType.IMAGE ? '[Image]' : content,
      lastMessageTime: message.createdAt,
    };

    // If sender is user1, increment unreadCount2
    if (senderId === conversation.user1Id) {
      updateData.unreadCount2 = { increment: 1 };
    } else {
      updateData.unreadCount1 = { increment: 1 };
    }

    await this.prisma.conversation.update({
      where: { id: conversation.id },
      data: updateData,
    });

    return message;
  }

  /**
   * Get Conversations List
   */
  async getConversations(userId: number) {
    // Fetch conversations where user is user1 or user2
    const conversations = await this.prisma.conversation.findMany({
      where: {
        OR: [{ user1Id: userId }, { user2Id: userId }],
      },
      orderBy: { lastMessageTime: 'desc' },
      include: {
        user1: { select: { id: true, nickname: true, avatarUrl: true } },
        user2: { select: { id: true, nickname: true, avatarUrl: true } },
      },
    });

    return conversations.map((c) => {
      const isUser1 = c.user1Id === userId;
      const otherUser = isUser1 ? c.user2 : c.user1;
      const unreadCount = isUser1 ? c.unreadCount1 : c.unreadCount2;

      return {
        id: c.id,
        otherUser,
        lastMessageContent: c.lastMessageContent,
        lastMessageTime: c.lastMessageTime,
        unreadCount,
      };
    });
  }
}
