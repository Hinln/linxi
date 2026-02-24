import { Controller, Get, Patch, Param, Body, UseGuards, Request, Query } from '@nestjs/common';
import { AdminService } from './admin.service';
import { ReportPaginationDto } from './dto/report-pagination.dto';
import { ProcessReportDto } from './dto/process-report.dto';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { Role } from '@prisma/client';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@Controller('admin')
@UseGuards(RolesGuard) // JwtAuthGuard is global, so we just add RolesGuard
@Roles(Role.ADMIN)
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get('reports')
  async getReports(@Query() paginationDto: ReportPaginationDto) {
    return this.adminService.getReports(paginationDto);
  }

  @Patch('reports/:id/process')
  async processReport(
    @Request() req: any,
    @Param('id') id: string,
    @Body() processReportDto: ProcessReportDto,
  ) {
    return this.adminService.processReport(req.user.userId, parseInt(id, 10), processReportDto);
  }
}
