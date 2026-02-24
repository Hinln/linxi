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
    const { content, media, latitude, longitude } = createPostDto;

    const post = await this.prisma.post.create({
      data: {
        publisherId: userId,
        content,
        media: media ? JSON.stringify(media) : undefined,
        latitude,
        longitude,
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
      take: limit,
      skip: cursor ? 1 : 0,
      cursor: cursor ? { createdAt: new Date(cursor) } : undefined, // Assuming createdAt is unique enough or use ID
      orderBy: { createdAt: 'desc' },
      where: { isDeleted: false },
      include: {
        publisher: {
          select: {
            nickname: true,
            avatarUrl: true,
            verifyStatus: true,
          },
        },
      },
    });

    // Transform response for anonymous view
    return posts.map((post) => ({
      id: post.id,
      content: post.content,
      media: post.media,
      location: { lat: post.latitude, lng: post.longitude },
      createdAt: post.createdAt,
      publisher: {
        nickname: post.publisher.nickname,
        avatarUrl: post.publisher.avatarUrl,
        isVerified: post.publisher.verifyStatus === VerificationStatus.VERIFIED,
      },
      // Hide comments marker or logic if user not logged in could be handled in frontend
      // But requirement says "If not logged in, hide comment function marker"
      // We can add a flag
      allowComment: !!currentUserId,
    }));
  }

  /**
   * Get Nearby Posts
   * Using Haversine formula for distance calculation via Prisma Raw Query
   */
  async getNearby(nearbyDto: NearbyDto, currentUserId?: number) {
    const { latitude, longitude, distance } = nearbyDto;
    
    // Note: Prisma Raw query requires correct typing and syntax for PostgreSQL.
    // Ensure table names and column names are quoted if they are case-sensitive or reserved.
    // In Prisma, models are usually PascalCase ("User", "Post"), fields camelCase ("publisherId").
    // But PostgreSQL stores them lowercase unless quoted. Prisma quotes them in migrations.
    // So we use double quotes for identifiers.

    const posts: any[] = await this.prisma.$queryRaw`
      SELECT 
        p.id, 
        p.content, 
        p.media, 
        p."createdAt", 
        p.latitude, 
        p.longitude,
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
    
    // 1. Create Report
    await this.prisma.report.create({
      data: {
        reporterId: userId,
        contentType: ContentType.POST,
        contentId: targetId,
        reason,
      },
    });

    // 2. Increment Report Count
    await this.prisma.post.update({
      where: { id: targetId },
      data: {
        reportCount: { increment: 1 },
      },
    });

    return { message: 'Report submitted' };
  }
}
