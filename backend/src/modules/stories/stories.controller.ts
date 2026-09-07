import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Req,
  UploadedFiles,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileFieldsInterceptor } from '@nestjs/platform-express';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CreateStoryDto } from './dto/create-story.dto';
import { StoriesService } from './stories.service';

/** Videos are kept as recorded (no transcoding), so cap what one story can weigh. */
const STORY_UPLOAD_MAX_BYTES = 60 * 1024 * 1024;

type StoryUploadFiles = {
  media?: Express.Multer.File[];
  /** Field name used by the first (photo-only) client build. */
  image?: Express.Multer.File[];
};

@Controller('stories')
export class StoriesController {
  constructor(private readonly storiesService: StoriesService) {}

  /** Active (< 24 h) stories of the caller's contacts, plus their own. */
  @UseGuards(JwtAuthGuard)
  @Get('feed')
  async getFeed(@Req() req: { user: { userId: string } }) {
    return {
      success: true,
      message: 'Story feed fetched successfully',
      data: await this.storiesService.getFeed(req.user.userId),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Post()
  @UseInterceptors(
    FileFieldsInterceptor(
      [
        { name: 'media', maxCount: 1 },
        { name: 'image', maxCount: 1 },
      ],
      { limits: { fileSize: STORY_UPLOAD_MAX_BYTES } },
    ),
  )
  async create(
    @Req() req: { user: { userId: string } },
    @Body() dto: CreateStoryDto,
    @UploadedFiles() files?: StoryUploadFiles,
  ) {
    const file = files?.media?.[0] ?? files?.image?.[0];
    return {
      success: true,
      message: 'Story published successfully',
      data: await this.storiesService.createStory(req.user.userId, file, dto),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Post(':storyId/view')
  async markViewed(
    @Req() req: { user: { userId: string } },
    @Param('storyId') storyId: string,
  ) {
    return {
      success: true,
      message: 'Story marked as viewed',
      data: await this.storiesService.markViewed(req.user.userId, storyId),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Get(':storyId/viewers')
  async getViewers(
    @Req() req: { user: { userId: string } },
    @Param('storyId') storyId: string,
  ) {
    return {
      success: true,
      message: 'Story viewers fetched successfully',
      data: await this.storiesService.getViewers(req.user.userId, storyId),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Delete(':storyId')
  async remove(
    @Req() req: { user: { userId: string } },
    @Param('storyId') storyId: string,
  ) {
    return {
      success: true,
      message: 'Story deleted successfully',
      data: await this.storiesService.deleteStory(req.user.userId, storyId),
    };
  }
}
