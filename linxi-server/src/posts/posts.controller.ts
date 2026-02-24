import { Controller, Get, Post, Body, Query, Param, Request, UseGuards, Delete } from '@nestjs/common';
import { PostsService } from './posts.service';
import { CreatePostDto } from './dto/create-post.dto';
import { PaginationDto } from './dto/pagination.dto';
import { NearbyDto } from './dto/nearby.dto';
import { GetPresignedUrlDto } from './dto/get-presigned-url.dto';
import { ReportPostDto } from './dto/report-post.dto';
import { Public } from '../auth/public.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@Controller('posts')
export class PostsController {
  constructor(private readonly postsService: PostsService) {}

  @Get('presigned-url')
  async getPresignedUrl(@Query() query: GetPresignedUrlDto) {
    return this.postsService.getPresignedUrl(query.fileName, query.fileType);
  }

  @UseGuards(JwtAuthGuard)
  @Post()
  async create(@Request() req: any, @Body() createPostDto: CreatePostDto) {
    return this.postsService.create(req.user.userId, createPostDto);
  }

  @Public()
  @Get('home')
  async getHomeFeed(@Query() paginationDto: PaginationDto, @Request() req: any) {
    // req.user might be undefined if public and no token
    const userId = req.user?.userId;
    return this.postsService.getHomeFeed(paginationDto, userId);
  }

  @Public()
  @Get('nearby')
  async getNearby(@Query() nearbyDto: NearbyDto, @Request() req: any) {
    const userId = req.user?.userId;
    return this.postsService.getNearby(nearbyDto, userId);
  }

  @Post(':id/report')
  async report(@Request() req: any, @Param('id') id: string, @Body() body: { reason: string }) {
    const reportDto = new ReportPostDto();
    reportDto.targetId = parseInt(id, 10);
    reportDto.reason = body.reason;
    reportDto.targetType = 'POST' as any; // Using enum value actually

    return this.postsService.report(req.user.userId, reportDto);
  }

  @UseGuards(JwtAuthGuard)
  @Post(':id/like')
  async like(@Request() req: any, @Param('id') id: string) {
    return this.postsService.like(req.user.userId, +id);
  }

  @UseGuards(JwtAuthGuard)
  @Delete(':id/like')
  async unlike(@Request() req: any, @Param('id') id: string) {
    return this.postsService.unlike(req.user.userId, +id);
  }
}
