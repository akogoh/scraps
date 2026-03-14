-- Add photo_url to field_officers table and payment_phone_number to scrap_submissions
-- Run this in the Supabase SQL Editor

BEGIN;

-- 1. Add photo_url column to field_officers table if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'field_officers' AND column_name = 'photo_url'
    ) THEN
        ALTER TABLE field_officers ADD COLUMN photo_url TEXT;
    END IF;
END $$;

-- 2. Add payment_phone_number column to scrap_submissions table if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'scrap_submissions' AND column_name = 'payment_phone_number'
    ) THEN
        ALTER TABLE scrap_submissions ADD COLUMN payment_phone_number TEXT;
    END IF;
END $$;

-- 3. Create index for payment_phone_number
CREATE INDEX IF NOT EXISTS idx_scrap_submissions_payment_phone 
ON scrap_submissions(payment_phone_number);

COMMIT;

-- Verify columns were added
SELECT 
    column_name, 
    data_type 
FROM information_schema.columns 
WHERE table_name = 'field_officers' 
  AND column_name = 'photo_url'
UNION ALL
SELECT 
    column_name, 
    data_type 
FROM information_schema.columns 
WHERE table_name = 'scrap_submissions' 
  AND column_name = 'payment_phone_number';
