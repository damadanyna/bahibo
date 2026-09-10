-- Voice calls between the two participants of a conversation. The row is
-- the signalling record (ringing / accepted / ended); audio itself goes
-- through a LiveKit room named after the call.
CREATE TYPE "VoiceCallStatus" AS ENUM ('RINGING', 'ACCEPTED', 'DECLINED', 'MISSED', 'CANCELLED', 'ENDED');

CREATE TABLE "VoiceCall" (
    "id" TEXT NOT NULL,
    "conversationId" TEXT NOT NULL,
    "callerUserId" TEXT NOT NULL,
    "calleeUserId" TEXT NOT NULL,
    "status" "VoiceCallStatus" NOT NULL DEFAULT 'RINGING',
    "roomName" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "answeredAt" TIMESTAMP(3),
    "endedAt" TIMESTAMP(3),
    "endedByUserId" TEXT,

    CONSTRAINT "VoiceCall_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "VoiceCall_callerUserId_status_createdAt_idx" ON "VoiceCall"("callerUserId", "status", "createdAt");
CREATE INDEX "VoiceCall_calleeUserId_status_createdAt_idx" ON "VoiceCall"("calleeUserId", "status", "createdAt");
CREATE INDEX "VoiceCall_conversationId_createdAt_idx" ON "VoiceCall"("conversationId", "createdAt");

ALTER TABLE "VoiceCall" ADD CONSTRAINT "VoiceCall_conversationId_fkey" FOREIGN KEY ("conversationId") REFERENCES "ChatConversation"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "VoiceCall" ADD CONSTRAINT "VoiceCall_callerUserId_fkey" FOREIGN KEY ("callerUserId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "VoiceCall" ADD CONSTRAINT "VoiceCall_calleeUserId_fkey" FOREIGN KEY ("calleeUserId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
