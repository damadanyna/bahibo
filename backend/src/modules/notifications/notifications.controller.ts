import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Req,
  Res,
  UseGuards,
} from "@nestjs/common";
import type { Response } from "express";

import { JwtAuthGuard } from "../auth/guards/jwt-auth.guard";
import { CreateNotificationFeedbackDto } from "./dto/create-notification-feedback.dto";
import { NotificationsService } from "./notifications.service";

@Controller("notifications")
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @UseGuards(JwtAuthGuard)
  @Get()
  async findAll(@Req() req: { user: { userId: string } }) {
    return {
      success: true,
      message: "Notifications fetched successfully",
      data: await this.notificationsService.findAll(req.user.userId),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Get("qa-exports")
  async findQaExports(@Req() req: { user: { userId: string; role: string } }) {
    return {
      success: true,
      message: "QA exports fetched successfully",
      data: await this.notificationsService.findQaExports(
        req.user.userId,
        req.user.role,
      ),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Get("qa-exports.csv")
  async downloadQaExportsCsv(
    @Req() req: { user: { userId: string; role: string } },
    @Res({ passthrough: true }) res: Response,
  ) {
    const csv = await this.notificationsService.buildQaExportsCsv(
      req.user.userId,
      req.user.role,
    );
    const timestamp = new Date().toISOString().replace(/[:.]/g, "-");

    res.setHeader("Content-Type", "text/csv; charset=utf-8");
    res.setHeader(
      "Content-Disposition",
      `attachment; filename="qa-exports-${timestamp}.csv"`,
    );

    return csv;
  }

  @UseGuards(JwtAuthGuard)
  @Post(":notificationId/read")
  async markAsRead(
    @Req() req: { user: { userId: string } },
    @Param("notificationId") notificationId: string,
  ) {
    return {
      success: true,
      message: "Notification marked as read",
      data: await this.notificationsService.markAsRead(
        req.user.userId,
        notificationId,
      ),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Post("feedback")
  async createFeedback(
    @Req() req: { user: { userId: string } },
    @Body() dto: CreateNotificationFeedbackDto,
  ) {
    return {
      success: true,
      message: "Feedback sent successfully",
      data: await this.notificationsService.createFeedback(
        req.user.userId,
        dto,
      ),
    };
  }
}
