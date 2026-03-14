-- Fix scrap_submissions table schema - add all missing columns
-- Add submitted_at column if it doesn't exist
ALTER TABLE scrap_submissions 
ADD COLUMN IF NOT EXISTS submitted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Add phone_number column if it doesn't exist
ALTER TABLE scrap_submissions 
ADD COLUMN IF NOT EXISTS phone_number TEXT;

-- Add location columns if they don't exist
ALTER TABLE scrap_submissions 
ADD COLUMN IF NOT EXISTS latitude DECIMAL(10, 8),
ADD COLUMN IF NOT EXISTS longitude DECIMAL(11, 8),
ADD COLUMN IF NOT EXISTS address TEXT;

-- Verify all columns exist
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'scrap_submissions'
ORDER BY ordinal_position;
