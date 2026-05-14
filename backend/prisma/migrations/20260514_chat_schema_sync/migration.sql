DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE typname = 'ChatMessageKind'
  ) THEN
    CREATE TYPE "ChatMessageKind" AS ENUM ('TEXT', 'IMAGE', 'DOCUMENT', 'PRODUCT');
  END IF;
END
$$;

ALTER TABLE "ChatMessage"
ADD COLUMN IF NOT EXISTS "kind" "ChatMessageKind" NOT NULL DEFAULT 'TEXT';

CREATE TABLE IF NOT EXISTS "ChatMessageMedia" (
  "id" TEXT NOT NULL,
  "messageId" TEXT NOT NULL,
  "mediaGroupId" TEXT,
  "mediaType" TEXT NOT NULL,
  "mimeType" TEXT,
  "fileName" TEXT,
  "fileSizeBytes" INTEGER,
  "storageProvider" TEXT NOT NULL,
  "storageKey" TEXT,
  "publicUrl" TEXT NOT NULL,
  "previewUrl" TEXT,
  "thumbnailUrl" TEXT,
  "width" INTEGER,
  "height" INTEGER,
  "encryptionScheme" TEXT,
  "encryptionKeyB64" TEXT,
  "encryptionIvB64" TEXT,
  "fileSha256B64" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "ChatMessageMedia_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "ChatMessageMedia_messageId_key"
ON "ChatMessageMedia"("messageId");

CREATE INDEX IF NOT EXISTS "ChatMessageMedia_mediaGroupId_idx"
ON "ChatMessageMedia"("mediaGroupId");

CREATE INDEX IF NOT EXISTS "ChatMessageMedia_mediaType_createdAt_idx"
ON "ChatMessageMedia"("mediaType", "createdAt");

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'ChatMessageMedia_messageId_fkey'
  ) THEN
    ALTER TABLE "ChatMessageMedia"
    ADD CONSTRAINT "ChatMessageMedia_messageId_fkey"
    FOREIGN KEY ("messageId") REFERENCES "ChatMessage"("id")
    ON DELETE CASCADE
    ON UPDATE CASCADE;
  END IF;
END
$$;