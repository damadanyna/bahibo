ALTER TABLE "ChatMessage"
  ADD COLUMN "clientMessageId" TEXT,
  ADD COLUMN "acceptedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ADD COLUMN "deliveredAt" TIMESTAMP(3);

CREATE INDEX "ChatMessage_conversationId_deliveredAt_idx"
  ON "ChatMessage"("conversationId", "deliveredAt");

CREATE INDEX "ChatMessage_conversationId_readAt_idx"
  ON "ChatMessage"("conversationId", "readAt");

CREATE UNIQUE INDEX "ChatMessage_senderUserId_clientMessageId_key"
  ON "ChatMessage"("senderUserId", "clientMessageId");