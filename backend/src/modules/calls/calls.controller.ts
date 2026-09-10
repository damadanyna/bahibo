import { Body, Controller, Get, Param, Post, Req, UseGuards } from '@nestjs/common';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CallsService } from './calls.service';
import { StartCallDto } from './dto/start-call.dto';

type AuthenticatedRequest = { user: { userId: string } };

@Controller('calls')
@UseGuards(JwtAuthGuard)
export class CallsController {
  constructor(private readonly callsService: CallsService) {}

  /** Rings the other participant of the conversation. */
  @Post()
  async startCall(@Req() req: AuthenticatedRequest, @Body() dto: StartCallDto) {
    return {
      success: true,
      message: 'Call started successfully',
      data: await this.callsService.startCall(req.user.userId, dto.conversationId),
    };
  }

  @Get(':callId')
  async getCall(@Req() req: AuthenticatedRequest, @Param('callId') callId: string) {
    return {
      success: true,
      message: 'Call fetched successfully',
      data: await this.callsService.getCall(req.user.userId, callId),
    };
  }

  /** Callee's phone confirms it rings (socket, push or native UI). */
  @Post(':callId/ringing')
  async markRinging(@Req() req: AuthenticatedRequest, @Param('callId') callId: string) {
    return {
      success: true,
      message: 'Call ringing acknowledged',
      data: await this.callsService.markRinging(req.user.userId, callId),
    };
  }

  @Post(':callId/accept')
  async acceptCall(@Req() req: AuthenticatedRequest, @Param('callId') callId: string) {
    return {
      success: true,
      message: 'Call accepted successfully',
      data: await this.callsService.acceptCall(req.user.userId, callId),
    };
  }

  @Post(':callId/decline')
  async declineCall(@Req() req: AuthenticatedRequest, @Param('callId') callId: string) {
    return {
      success: true,
      message: 'Call declined successfully',
      data: await this.callsService.declineCall(req.user.userId, callId),
    };
  }

  @Post(':callId/end')
  async endCall(@Req() req: AuthenticatedRequest, @Param('callId') callId: string) {
    return {
      success: true,
      message: 'Call ended successfully',
      data: await this.callsService.endCall(req.user.userId, callId),
    };
  }
}
