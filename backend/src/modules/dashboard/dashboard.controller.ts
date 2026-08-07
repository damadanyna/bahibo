import { Controller, ForbiddenException, Get, Query, Req, UseGuards } from '@nestjs/common';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { DashboardService } from './dashboard.service';
import { LogsQueryDto } from './dto/logs-query.dto';

@Controller('dashboard')
export class DashboardController {
  constructor(private readonly dashboardService: DashboardService) {}

  private ensureAdminAccess(role?: string) {
    if (role !== 'ADMIN') {
      throw new ForbiddenException('Admin access required');
    }
  }

  @UseGuards(JwtAuthGuard)
  @Get('admin/stats')
  async getStats(@Req() req: { user: { role: string } }) {
    this.ensureAdminAccess(req.user.role);

    return {
      success: true,
      message: 'Dashboard stats fetched successfully',
      data: await this.dashboardService.getStats(),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Get('admin/logs')
  async getLogs(@Req() req: { user: { role: string } }, @Query() query: LogsQueryDto) {
    this.ensureAdminAccess(req.user.role);

    return {
      success: true,
      message: 'Logs fetched successfully',
      data: await this.dashboardService.listLogs(query),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Get('admin/logs/by-user')
  async getLogsByUser(@Req() req: { user: { role: string } }) {
    this.ensureAdminAccess(req.user.role);

    return {
      success: true,
      message: 'Logs by user fetched successfully',
      data: await this.dashboardService.listLogsByUser(),
    };
  }
}
