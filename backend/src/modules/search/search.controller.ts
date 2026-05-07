import { Body, Controller, Get, Post, Query, Req, UseGuards } from '@nestjs/common';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { SearchService } from './search.service';

@Controller('search')
export class SearchController {
  constructor(private readonly searchService: SearchService) {}

  @UseGuards(JwtAuthGuard)
  @Get('history/no-results')
  async findNoResultHistory(@Req() req: { user: { userId: string } }) {
    return {
      success: true,
      message: 'No-result search history fetched successfully',
      data: await this.searchService.findNoResultHistory(req.user.userId),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Post('history')
  async recordSearchHistory(
    @Req() req: { user: { userId: string } },
    @Body() body?: { query?: string; resultCount?: number },
  ) {
    return {
      success: true,
      message: 'Search history recorded successfully',
      data: await this.searchService.recordSearchHistory({
        userId: req.user.userId,
        query: body?.query ?? '',
        resultCount: Number(body?.resultCount ?? 0),
      }),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Get('autocomplete')
  async autocomplete(
    @Req() req: { user: { userId: string } },
    @Query('q') query?: string,
    @Query('limit') limit?: string,
  ) {
    return {
      success: true,
      message: 'Search autocomplete fetched successfully',
      data: await this.searchService.autocomplete({
        userId: req.user.userId,
        query: query ?? '',
        limit: Number(limit ?? '6'),
      }),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Get()
  async search(
    @Req() req: { user: { userId: string } },
    @Query('q') query?: string,
    @Query('limit') limit?: string,
  ) {
    return {
      success: true,
      message: 'Search results fetched successfully',
      data: await this.searchService.search({
        userId: req.user.userId,
        query: query ?? '',
        limit: Number(limit ?? '24'),
      }),
    };
  }
}