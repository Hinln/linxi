import { Injectable, CanActivate, ExecutionContext, ForbiddenException, Logger } from '@nestjs/common';
import { RedisService } from '../common/redis/redis.service';
import { PrismaService } from '../prisma/prisma.service';
import { UserStatus } from '@prisma/client';

@Injectable()
export class BanGuard implements CanActivate {
  private readonly logger = new Logger(BanGuard.name);

  constructor(
    private readonly redisService: RedisService,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const { user } = context.switchToHttp().getRequest();
    // User might not be present if request is anonymous (e.g. public endpoints)
    if (!user || !user.userId) {
      return true;
    }

    const userId = user.userId;
    const statusKey = `user:status:${userId}`;
    let status = await this.redisService.get(statusKey);

    if (!status) {
      const dbUser = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { status: true },
      });
      if (dbUser) {
        status = dbUser.status;
        await this.redisService.set(statusKey, status, 3600); // Cache for 1 hour
      }
    }

    if (status === UserStatus.BANNED) {
      throw new ForbiddenException('Account is banned');
    }

    return true;
  }
}
