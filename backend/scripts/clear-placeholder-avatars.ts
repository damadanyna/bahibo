import "reflect-metadata";

import { NestFactory } from "@nestjs/core";

import { AppModule } from "../src/app.module";
import { PrismaService } from "../src/modules/prisma/prisma.service";

/**
 * Users without a photo used to be stored / presented with a stock portrait
 * from i.pravatar.cc. The apps now render a person icon for a missing avatar,
 * so this clears any placeholder portrait still persisted in the database.
 *
 * Dry run by default; pass --apply to write.
 */
async function run() {
  const apply = process.argv.slice(2).includes("--apply");
  const app = await NestFactory.createApplicationContext(AppModule, {
    logger: ["log", "warn", "error"],
  });

  try {
    const prisma = app.get(PrismaService);
    const where = { avatarUrl: { contains: "i.pravatar.cc/" } };

    const affected = await prisma.user.findMany({
      where,
      select: { id: true, displayName: true, avatarUrl: true },
    });
    console.log(
      JSON.stringify({ count: affected.length, users: affected }, null, 2),
    );

    if (!apply) {
      console.log(
        `\nDry run only - no changes made. Re-run with --apply to clear ${affected.length} placeholder avatar(s).`,
      );
      return;
    }

    const result = await prisma.user.updateMany({
      where,
      data: { avatarUrl: null },
    });
    console.log(`Cleared ${result.count} placeholder avatar(s).`);
  } finally {
    await app.close();
  }
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
