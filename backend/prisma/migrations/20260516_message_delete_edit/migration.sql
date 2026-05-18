-- Delete-for-me: message stays in DB but is hidden from the sender
ALTER TABLE "ChatMessage" ADD COLUMN "deletedForSenderAt" TIMESTAMP(3);

-- Edit: tracks the last edit time so the UI can show "modifié"
ALTER TABLE "ChatMessage" ADD COLUMN "editedAt" TIMESTAMP(3);
