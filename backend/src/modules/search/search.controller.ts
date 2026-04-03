import { Controller, Get, Query } from '@nestjs/common';

import { SearchService } from './search.service';

@Controller('search')
export class SearchController {
  constructor(private readonly searchService: SearchService) {}

  @Get()
  async search(
    @Query('q') query?: string,
    @Query('limit') limit?: string,
  ) {
    return {
      success: true,
      message: 'Search results fetched successfully',
      data: await this.searchService.search({
        query: query ?? '',
        limit: Number(limit ?? '24'),
      }),
    };
  }
}