-- Product condition ("État") and warranty ("Garantie") were previously
-- hardcoded UI text on the product detail pages, never backed by real
-- data. This adds the columns needed to store what a seller actually
-- selects in the product form.
CREATE TYPE "ProductCondition" AS ENUM ('OCCASION', 'RECONDITIONNE', 'NEUF');
CREATE TYPE "WarrantyDurationUnit" AS ENUM ('DAYS', 'MONTHS', 'YEARS');

ALTER TABLE "Product"
  ADD COLUMN "condition" "ProductCondition",
  ADD COLUMN "hasWarranty" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN "warrantyDurationValue" INTEGER,
  ADD COLUMN "warrantyDurationUnit" "WarrantyDurationUnit";
