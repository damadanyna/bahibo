import {
  BadRequestException,
  ForbiddenException,
  Injectable,
} from "@nestjs/common";

import { PrismaService } from "../prisma/prisma.service";
import { UpsertFeatureFlagDto } from "./dto/upsert-feature-flag.dto";

const KEY_PATTERN = /^[a-z0-9_]+$/;

@Injectable()
export class FeatureFlagsService {
  constructor(private readonly prisma: PrismaService) {}

  async findAll() {
    return this.prisma.featureFlag.findMany({
      orderBy: { key: "asc" },
    });
  }

  async upsert(
    key: string,
    dto: UpsertFeatureFlagDto,
    currentUserRole: string,
  ) {
    if (currentUserRole !== "ADMIN") {
      throw new ForbiddenException("Admin access required");
    }
    if (!KEY_PATTERN.test(key)) {
      throw new BadRequestException(
        "Flag key must contain only lowercase letters, digits and underscores",
      );
    }

    return this.prisma.featureFlag.upsert({
      where: { key },
      create: {
        key,
        enabled: dto.enabled,
        description: dto.description,
      },
      update: {
        enabled: dto.enabled,
        ...(dto.description !== undefined
          ? { description: dto.description }
          : {}),
      },
    });
  }
}
