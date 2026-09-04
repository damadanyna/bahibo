-- User.location* only keeps the latest position. To improve seller
-- suggestions in the areas an account actually lives in, every meaningful
-- location change (new label or > 150 m away) is now appended here.
CREATE TYPE "UserLocationSource" AS ENUM ('GPS', 'MANUAL');

CREATE TABLE "UserLocationHistory" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "locationLabel" TEXT,
    "latitude" DOUBLE PRECISION NOT NULL,
    "longitude" DOUBLE PRECISION NOT NULL,
    "previousLatitude" DOUBLE PRECISION,
    "previousLongitude" DOUBLE PRECISION,
    "distanceFromPreviousKm" DOUBLE PRECISION,
    "source" "UserLocationSource" NOT NULL DEFAULT 'GPS',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "UserLocationHistory_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "UserLocationHistory_userId_createdAt_idx" ON "UserLocationHistory"("userId", "createdAt");

CREATE INDEX "UserLocationHistory_latitude_longitude_idx" ON "UserLocationHistory"("latitude", "longitude");

ALTER TABLE "UserLocationHistory" ADD CONSTRAINT "UserLocationHistory_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
