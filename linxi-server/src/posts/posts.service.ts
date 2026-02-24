import { Injectable, Logger, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { OssService } from '../common/aliyun/oss.service';
import { CreatePostDto } from './dto/create-post.dto';
import { PaginationDto } from './dto/pagination.dto';
import { NearbyDto } from './dto/nearby.dto';
import { ReportPostDto } from './dto/report-post.dto';
import { VerificationStatus, ContentType } from '@prisma/client';

@Injectable()
export class PostsService {
  private readonly logger = new Logger(PostsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly ossService: OssService,
  ) {}

  /**
   * Generate Presigned URL for Upload
   */
  async getPresignedUrl(fileName: string, fileType: string) {
    const objectName = `posts/${Date.now()}_${fileName}`;
    // Simple validation for file extension vs MIME type could be added here
    const url = await this.ossService.generatePresignedUrl(objectName, fileType);
    return { url, objectName };
  }

  /**
   * Create Post
   */
  async create(userId: number, createPostDto: CreatePostDto) {
    const { content, media, latitude, longitude, address } = createPostDto;

    const post = await this.prisma.post.create({
      data: {
        publisherId: userId,
        content,
        media: media ? JSON.stringify(media) : undefined,
        latitude,
        longitude,
        address,
      },
    });

    return post;
  }

  /**
   * Get Home Feed (Pagination)
   */
  async getHomeFeed(paginationDto: PaginationDto, currentUserId?: number) {
    const { limit, cursor } = paginationDto;

    const posts = await this.prisma.post.findMany({
      take: Number(limit), // Ensure limit is number
      skip: cursor ? 1 : 0,
      cursor: cursor ? { id: Number(cursor) } : undefined, // Cursor must point to unique field (ID)
      orderBy: { createdAt: 'desc' },
      where: { isDeleted: false },
      include: {
        publisher: true, // Include full publisher relation
        _count: {
          select: {
            comments: true,
            likes: true,
          },
        },
        likes: currentUserId ? {
          where: { userId: currentUserId },
          select: { id: true },
        } : false,
      },
    });

    return posts.map((post) => ({
      id: post.id,
      content: post.content,
      media: post.media,
      location: { lat: post.latitude, lng: post.longitude },
      address: post.address,
      createdAt: post.createdAt,
      viewCount: post.viewCount,
      likeCount: post._count.likes,
      commentCount: post._count.comments,
      isLiked: post.likes && post.likes.length > 0,
      publisher: {
        nickname: post.publisher.nickname,
        avatarUrl: post.publisher.avatarUrl,
        isVerified: post.publisher.verifyStatus === VerificationStatus.VERIFIED,
      },
      allowComment: !!currentUserId,
    }));
  }

  /**
   * Get Nearby Posts
   */
  async getNearby(nearbyDto: NearbyDto, currentUserId?: number) {
    const { latitude, longitude, distance } = nearbyDto;
    
    // Note: This raw query needs to be updated to include like/comment counts if needed for nearby too.
    // For simplicity, keeping it basic or we'd need a more complex join.
    // Let's keep the existing implementation but add basic fields mapping if they exist.

    const posts: any[] = await this.prisma.$queryRaw`
      SELECT 
        p.id, 
        p.content, 
        p.media, 
        p."createdAt", 
        p.latitude, 
        p.longitude,
        p.address,
        u.nickname, 
        u."avatarUrl", 
        u."verifyStatus",
        (
          6371 * acos(
            cos(radians(${latitude})) * cos(radians(p.latitude)) * 
            cos(radians(p.longitude) - radians(${longitude})) + 
            sin(radians(${latitude})) * sin(radians(p.latitude))
          )
        ) AS distance
      FROM "Post" p
      JOIN "User" u ON p."publisherId" = u.id
      WHERE p."isDeleted" = false
        AND p.latitude IS NOT NULL
        AND p.longitude IS NOT NULL
        AND (
          6371 * acos(
            cos(radians(${latitude})) * cos(radians(p.latitude)) * 
            cos(radians(p.longitude) - radians(${longitude})) + 
            sin(radians(${latitude})) * sin(radians(p.latitude))
          )
        ) < ${distance}
      ORDER BY distance ASC
      LIMIT 50;
    `;

    return posts.map((post) => ({
      id: post.id,
      content: post.content,
      media: post.media,
      location: { lat: post.latitude, lng: post.longitude },
      address: post.address,
      distance: post.distance,
      createdAt: post.createdAt,
      publisher: {
        nickname: post.nickname,
        avatarUrl: post.avatarUrl,
        isVerified: post.verifyStatus === 'VERIFIED',
      },
      allowComment: !!currentUserId,
    }));
  }

  /**
   * Report Post
   */
  async report(userId: number, reportPostDto: ReportPostDto) {
    const { targetId, reason } = reportPostDto;
    
    await this.prisma.report.create({
      data: {
        reporterId: userId,
        contentType: ContentType.POST,
        contentId: targetId,
        reason,
      },
    });

    await this.prisma.post.update({
      where: { id: targetId },
      data: {
        reportCount: { increment: 1 },
      },
    });

    return { message: 'Report submitted' };
  }

  /**
   * Like Post
   */
  async like(userId: number, postId: number) {
    try {
      await this.prisma.like.create({
        data: {
          userId,
          postId,
        },
      });
      return { success: true };
    } catch (error) {
      // P2002: Unique constraint failed
      if (error.code === 'P2002') {
        return { success: true, message: 'Already liked' };
      }
      throw error;
    }
  }

  /**
   * Unlike Post
   */
  async unlike(userId: number, postId: number) {
    try {
      await this.prisma.like.delete({
        where: {
          userId_postId: {
            userId,
            postId,
          },
        },
      });
      return { success: true };
    } catch (error) {
      // P2025: Record to delete does not exist
      if (error.code === 'P2025') {
        return { success: true, message: 'Not liked yet' };
      }
      throw error;
    }
  }
}
