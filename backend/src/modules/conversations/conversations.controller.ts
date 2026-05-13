import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Query,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CreateMediaMessageDto } from './dto/create-media-message.dto';
import { CreateMessageDto } from './dto/create-message.dto';
import { ConversationsService } from './conversations.service';

@UseGuards(JwtAuthGuard)
@Controller('conversations')
export class ConversationsController {
  constructor(private readonly conversationsService: ConversationsService) {}

  @Get()
  async findAll(@Req() req: { user: { userId: string } }) {
    return {
      success: true,
      message: 'Conversations fetched successfully',
      data: await this.conversationsService.listConversations(req.user.userId),
    };
  }

  @Get('product/:productId')
  async findOrCreateForProduct(
    @Req() req: { user: { userId: string } },
    @Param('productId') productId: string,
    @Query('limit') limit?: string,
    @Query('beforeMessageId') beforeMessageId?: string,
  ) {
    return {
      success: true,
      message: 'Conversation fetched successfully',
      data: await this.conversationsService.getOrCreateConversationForProduct(
        req.user.userId,
        productId,
        {
          limit: Number(limit ?? '8'),
          beforeMessageId,
        },
      ),
    };
  }

  @Get('user/:targetUserId')
  async findOrCreateForUser(
    @Req() req: { user: { userId: string } },
    @Param('targetUserId') targetUserId: string,
    @Query('limit') limit?: string,
    @Query('beforeMessageId') beforeMessageId?: string,
  ) {
    return {
      success: true,
      message: 'Conversation fetched successfully',
      data: await this.conversationsService.getOrCreateConversationForUser(
        req.user.userId,
        targetUserId,
        {
          limit: Number(limit ?? '8'),
          beforeMessageId,
        },
      ),
    };
  }

  @Get(':conversationId')
  async findOne(
    @Req() req: { user: { userId: string } },
    @Param('conversationId') conversationId: string,
    @Query('limit') limit?: string,
    @Query('beforeMessageId') beforeMessageId?: string,
  ) {
    return {
      success: true,
      message: 'Conversation fetched successfully',
      data: await this.conversationsService.getConversation(
        req.user.userId,
        conversationId,
        {
          limit: Number(limit ?? '8'),
          beforeMessageId,
        },
      ),
    };
  }

  @Delete(':conversationId/messages/:messageId')
  async deleteMessage(
    @Req() req: { user: { userId: string } },
    @Param('conversationId') conversationId: string,
    @Param('messageId') messageId: string,
  ) {
    return {
      success: true,
      message: 'Message deleted successfully',
      data: await this.conversationsService.deleteMessage(
        req.user.userId,
        conversationId,
        messageId,
      ),
    };
  }

  @Post('product/:productId/messages')
  async sendProductMessage(
    @Req() req: { user: { userId: string } },
    @Param('productId') productId: string,
    @Body() dto: CreateMessageDto,
  ) {
    return {
      success: true,
      message: 'Message sent successfully',
      data: await this.conversationsService.sendMessageForProduct(
        req.user.userId,
        productId,
        dto,
      ),
    };
  }

  @Post('product/:productId/media-messages')
  async sendProductMediaMessage(
    @Req() req: { user: { userId: string } },
    @Param('productId') productId: string,
    @Body() dto: CreateMediaMessageDto,
  ) {
    return {
      success: true,
      message: 'Media message sent successfully',
      data: await this.conversationsService.sendMediaMessageForProduct(
        req.user.userId,
        productId,
        dto,
      ),
    };
  }

  @Post('user/:targetUserId/messages')
  async sendUserMessage(
    @Req() req: { user: { userId: string } },
    @Param('targetUserId') targetUserId: string,
    @Body() dto: CreateMessageDto,
  ) {
    return {
      success: true,
      message: 'Message sent successfully',
      data: await this.conversationsService.sendMessageForUser(
        req.user.userId,
        targetUserId,
        dto,
      ),
    };
  }

  @Post('user/:targetUserId/media-messages')
  async sendUserMediaMessage(
    @Req() req: { user: { userId: string } },
    @Param('targetUserId') targetUserId: string,
    @Body() dto: CreateMediaMessageDto,
  ) {
    return {
      success: true,
      message: 'Media message sent successfully',
      data: await this.conversationsService.sendMediaMessageForUser(
        req.user.userId,
        targetUserId,
        dto,
      ),
    };
  }

  @Post(':conversationId/messages')
  async sendMessage(
    @Req() req: { user: { userId: string } },
    @Param('conversationId') conversationId: string,
    @Body() dto: CreateMessageDto,
  ) {
    return {
      success: true,
      message: 'Message sent successfully',
      data: await this.conversationsService.sendMessage(
        req.user.userId,
        conversationId,
        dto,
      ),
    };
  }

  @Post(':conversationId/media-messages')
  async sendMediaMessage(
    @Req() req: { user: { userId: string } },
    @Param('conversationId') conversationId: string,
    @Body() dto: CreateMediaMessageDto,
  ) {
    return {
      success: true,
      message: 'Media message sent successfully',
      data: await this.conversationsService.sendMediaMessage(
        req.user.userId,
        conversationId,
        dto,
      ),
    };
  }

  @Post('attachments/photo')
  @UseInterceptors(FileInterceptor('file'))
  async uploadPhotoAttachment(
    @Req() req: { user: { userId: string } },
    @UploadedFile() file: Express.Multer.File,
  ) {
    return {
      success: true,
      message: 'Photo attachment uploaded successfully',
      data: await this.conversationsService.uploadAttachment(
        req.user.userId,
        file,
        'photo',
      ),
    };
  }

  @Post('attachments/photo/direct-signature')
  async createDirectPhotoUploadSignature(
    @Req() req: { user: { userId: string } },
  ) {
    return {
      success: true,
      message: 'Direct photo upload signature created successfully',
      data: this.conversationsService.createDirectPhotoUploadSignature(
        req.user.userId,
      ),
    };
  }

  @Post('attachments/document/direct-signature')
  async createDirectDocumentUploadSignature(
    @Req() req: { user: { userId: string } },
  ) {
    return {
      success: true,
      message: 'Direct document upload signature created successfully',
      data: this.conversationsService.createDirectDocumentUploadSignature(
        req.user.userId,
      ),
    };
  }

  @Post('attachments/document')
  @UseInterceptors(FileInterceptor('file'))
  async uploadDocumentAttachment(
    @Req() req: { user: { userId: string } },
    @UploadedFile() file: Express.Multer.File,
  ) {
    return {
      success: true,
      message: 'Document attachment uploaded successfully',
      data: await this.conversationsService.uploadAttachment(
        req.user.userId,
        file,
        'document',
      ),
    };
  }
}