import { Module } from '@nestjs/common';
import { PostsService } from './posts.service';
import { PostsController } from './posts.controller';
import { PrismaModule } from '../prisma/prisma.module';
import { AliyunModule } from '../common/aliyun/aliyun.module';

@Module({
  imports: [PrismaModule, AliyunModule],
  controllers: [PostsController],
  providers: [PostsService],
})
export class PostsModule {}
