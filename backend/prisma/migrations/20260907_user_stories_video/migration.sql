-- Stories open to every account (not only shops) and playable as video:
-- SellerStory / SellerStoryView become UserStory / UserStoryView keyed by
-- the author's user id, with a media type, a poster frame and a duration.
CREATE TYPE "StoryMediaType" AS ENUM ('IMAGE', 'VIDEO');

ALTER TABLE "SellerStory" RENAME TO "UserStory";
ALTER TABLE "SellerStoryView" RENAME TO "UserStoryView";

ALTER TABLE "UserStory" RENAME CONSTRAINT "SellerStory_pkey" TO "UserStory_pkey";
ALTER TABLE "UserStoryView" RENAME CONSTRAINT "SellerStoryView_pkey" TO "UserStoryView_pkey";
ALTER TABLE "UserStoryView" RENAME CONSTRAINT "SellerStoryView_storyId_fkey" TO "UserStoryView_storyId_fkey";
ALTER TABLE "UserStoryView" RENAME CONSTRAINT "SellerStoryView_viewerUserId_fkey" TO "UserStoryView_viewerUserId_fkey";
ALTER INDEX "SellerStoryView_storyId_viewerUserId_key" RENAME TO "UserStoryView_storyId_viewerUserId_key";
ALTER INDEX "SellerStoryView_viewerUserId_viewedAt_idx" RENAME TO "UserStoryView_viewerUserId_viewedAt_idx";
ALTER INDEX "SellerStory_expiresAt_idx" RENAME TO "UserStory_expiresAt_idx";

-- The author moves from the shop profile to the user account.
ALTER TABLE "UserStory" ADD COLUMN "userId" TEXT;
UPDATE "UserStory" AS story
SET "userId" = profile."userId"
FROM "SellerProfile" AS profile
WHERE profile."id" = story."sellerProfileId";
DELETE FROM "UserStory" WHERE "userId" IS NULL;
ALTER TABLE "UserStory" ALTER COLUMN "userId" SET NOT NULL;

ALTER TABLE "UserStory" DROP CONSTRAINT "SellerStory_sellerProfileId_fkey";
DROP INDEX "SellerStory_sellerProfileId_expiresAt_idx";
ALTER TABLE "UserStory" DROP COLUMN "sellerProfileId";

ALTER TABLE "UserStory" RENAME COLUMN "imageUrl" TO "mediaUrl";
ALTER TABLE "UserStory" RENAME COLUMN "imagePublicId" TO "mediaPublicId";
ALTER TABLE "UserStory" ADD COLUMN "mediaType" "StoryMediaType" NOT NULL DEFAULT 'IMAGE';
ALTER TABLE "UserStory" ADD COLUMN "thumbnailUrl" TEXT;
ALTER TABLE "UserStory" ADD COLUMN "durationSeconds" INTEGER;
UPDATE "UserStory" SET "thumbnailUrl" = "mediaUrl" WHERE "thumbnailUrl" IS NULL;

CREATE INDEX "UserStory_userId_expiresAt_idx" ON "UserStory"("userId", "expiresAt");

ALTER TABLE "UserStory" ADD CONSTRAINT "UserStory_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
