import { Body, Controller, Get, Param, Patch, Req, UseGuards } from "@nestjs/common";

import { JwtAuthGuard } from "../auth/guards/jwt-auth.guard";
import { UpsertFeatureFlagDto } from "./dto/upsert-feature-flag.dto";
import { FeatureFlagsService } from "./feature-flags.service";

@Controller("feature-flags")
export class FeatureFlagsController {
  constructor(private readonly featureFlagsService: FeatureFlagsService) {}

  /**
   * Public on purpose: the app reads flags at startup, before/without a
   * session, to decide what to render. Flags never carry secrets, only
   * on/off state.
   */
  @Get()
  async findAll() {
    return {
      success: true,
      message: "Feature flags fetched successfully",
      data: await this.featureFlagsService.findAll(),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Patch(":key")
  async upsert(
    @Req() req: { user: { role: string } },
    @Param("key") key: string,
    @Body() dto: UpsertFeatureFlagDto,
  ) {
    return {
      success: true,
      message: "Feature flag updated",
      data: await this.featureFlagsService.upsert(key, dto, req.user.role),
    };
  }
}
