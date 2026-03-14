-- Adds price column (in Ghana Cedis) to scrap_submissions
-- Run this in Supabase SQL editor

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'scrap_submissions' AND column_name = 'price'
  ) THEN
    ALTER TABLE scrap_submissions
      ADD COLUMN price numeric(12,2) NOT NULL DEFAULT 0;
  END IF;
END $$;


