import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RedisService } from '../common/redis/redis.service';
import { ReportPaginationDto } from './dto/report-pagination.dto';
import { ProcessReportDto } from './dto/process-report.dto';
import { ReportStatus, ContentType, UserStatus } from '@prisma/client';

@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redisService: RedisService,
  ) {}

  /**
   * Get Reports
   */
  async getReports(paginationDto: ReportPaginationDto) {
    const { limit, offset } = paginationDto;
    const reports = await this.prisma.report.findMany({
      take: limit,
      skip: offset,
      orderBy: { createdAt: 'desc' },
      include: {
        reporter: {
          select: { id: true, nickname: true, phone: true },
        },
      },
    });

    const enrichedReports = await Promise.all(reports.map(async (report) => {
      let contentDetails = null;
      if (report.contentType === ContentType.POST) {
        contentDetails = await this.prisma.post.findUnique({ where: { id: report.contentId } });
      } else if (report.contentType === ContentType.USER) {
        contentDetails = await this.prisma.user.findUnique({
          where: { id: report.contentId },
          select: { id: true, nickname: true, avatarUrl: true, status: true },
        });
      }
      return { ...report, contentDetails };
    }));

    return enrichedReports;
  }

  /**
   * Process Report
   */
  async processReport(adminId: number, reportId: number, processReportDto: ProcessReportDto) {
    const { accepted, details } = processReportDto;

    const report = await this.prisma.report.findUnique({ where: { id: reportId } });
    if (!report) throw new NotFoundException('Report not found');

    if (report.status !== ReportStatus.PENDING) {
      throw new BadRequestException('Report already processed');
    }

    // Transaction to ensure atomicity
    await this.prisma.$transaction(async (tx) => {
      // 1. Update Report
      await tx.report.update({
        where: { id: reportId },
        data: {
          status: accepted ? ReportStatus.ACCEPTED : ReportStatus.REJECTED,
        },
      });

      // 2. Audit Log
      await tx.auditLog.create({
        data: {
          adminId,
          action: accepted ? 'REPORT_ACCEPTED' : 'REPORT_REJECTED',
          target: `Report:${reportId}`,
          details: details || `ContentType: ${report.contentType}, ContentId: ${report.contentId}`,
        },
      });

      // 3. Actions if accepted
      if (accepted) {
        if (report.contentType === ContentType.POST) {
          // Soft delete post
          await tx.post.update({
            where: { id: report.contentId },
            data: { isDeleted: true },
          });
        } else if (report.contentType === ContentType.USER) {
          // Ban user
          await tx.user.update({
            where: { id: report.contentId },
            data: { status: UserStatus.BANNED },
          });
          
          // Invalidate Cache IMMEDIATELY
          const statusKey = `user:status:${report.contentId}`;
          await this.redisService.set(statusKey, UserStatus.BANNED, 3600);
        }
      }
    });

    return { message: 'Report processed successfully' };
  }
}
