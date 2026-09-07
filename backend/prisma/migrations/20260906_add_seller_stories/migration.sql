-- Stories: a shop shares a photo with its followers for 24 h (Instagram /
-- WhatsApp model). Views drive the "seen" ring on the client and the
-- owner's view counter. Rows are purged by StoriesService one day after
-- expiry so the table stays small.
CREATE TABLE "SellerStory" (
    "id" TEXT NOT NULL,
    "sellerProfileId" TEXT NOT NULL,
    "imageUrl" TEXT NOT NULL,
    "imagePublicId" TEXT,
    "caption" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SellerStory_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "SellerStoryView" (
    "id" TEXT NOT NULL,
    "storyId" TEXT NOT NULL,
    "viewerUserId" TEXT NOT NULL,
    "viewedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SellerStoryView_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "SellerStory_sellerProfileId_expiresAt_idx" ON "SellerStory"("sellerProfileId", "expiresAt");

CREATE INDEX "SellerStory_expiresAt_idx" ON "SellerStory"("expiresAt");

CREATE UNIQUE INDEX "SellerStoryView_storyId_viewerUserId_key" ON "SellerStoryView"("storyId", "viewerUserId");

CREATE INDEX "SellerStoryView_viewerUserId_viewedAt_idx" ON "SellerStoryView"("viewerUserId", "viewedAt");

ALTER TABLE "SellerStory" ADD CONSTRAINT "SellerStory_sellerProfileId_fkey" FOREIGN KEY ("sellerProfileId") REFERENCES "SellerProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "SellerStoryView" ADD CONSTRAINT "SellerStoryView_storyId_fkey" FOREIGN KEY ("storyId") REFERENCES "SellerStory"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "SellerStoryView" ADD CONSTRAINT "SellerStoryView_viewerUserId_fkey" FOREIGN KEY ("viewerUserId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
