CREATE TABLE "UserFeedback" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "message" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "UserFeedback_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "UserFeedback_userId_createdAt_idx"
ON "UserFeedback"("userId", "createdAt");

CREATE INDEX "UserFeedback_createdAt_idx"
ON "UserFeedback"("createdAt");

ALTER TABLE "UserFeedback"
ADD CONSTRAINT "UserFeedback_userId_fkey"
FOREIGN KEY ("userId") REFERENCES "User"("id")
ON DELETE CASCADE
ON UPDATE CASCADE;