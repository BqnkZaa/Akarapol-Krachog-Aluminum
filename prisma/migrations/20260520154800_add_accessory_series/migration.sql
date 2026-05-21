-- AlterTable: add "series" column to accessories
-- Default is "ทั่วไป" (General) so existing rows keep a valid value.
ALTER TABLE "accessories" ADD COLUMN "series" TEXT NOT NULL DEFAULT 'ทั่วไป';
