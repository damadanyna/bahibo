import { Body, Controller, Get, Param, Post, Req, UseGuards } from '@nestjs/common';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
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
  ) {
    return {
      success: true,
      message: 'Conversation fetched successfully',
      data: await this.conversationsService.getOrCreateConversationForProduct(
        req.user.userId,
        productId,
      ),
    };
  }

  @Get('user/:targetUserId')
  async findOrCreateForUser(
    @Req() req: { user: { userId: string } },
    @Param('targetUserId') targetUserId: string,
  ) {
    return {
      success: true,
      message: 'Conversation fetched successfully',
      data: await this.conversationsService.getOrCreateConversationForUser(
        req.user.userId,
        targetUserId,
      ),
    };
  }

  @Get(':conversationId')
  async findOne(
    @Req() req: { user: { userId: string } },
    @Param('conversationId') conversationId: string,
  ) {
    return {
      success: true,
      message: 'Conversation fetched successfully',
      data: await this.conversationsService.getConversation(
        req.user.userId,
        conversationId,
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
}