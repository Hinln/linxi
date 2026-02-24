import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateCommentDto } from './dto/create-comment.dto';

@Injectable()
export class CommentsService {
  constructor(private prisma: PrismaService) {}

  async create(userId: number, createCommentDto: CreateCommentDto) {
    return this.prisma.comment.create({
      data: {
        content: createCommentDto.content,
        postId: createCommentDto.postId,
        publisherId: userId,
      },
      include: {
        publisher: {
          select: {
            id: true,
            nickname: true,
            avatarUrl: true,
            verifyStatus: true,
          },
        },
      },
    });
  }

  async findAll(postId: number) {
    return this.prisma.comment.findMany({
      where: { postId },
      orderBy: { createdAt: 'desc' },
      include: {
        publisher: {
          select: {
            id: true,
            nickname: true,
            avatarUrl: true,
            verifyStatus: true,
          },
        },
      },
    });
  }
}
