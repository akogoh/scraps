-- Fix scrap_submissions table schema
-- Run this in your Supabase SQL Editor

-- First, let's see the current structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'scrap_submissions'
ORDER BY ordinal_position;

-- Add phone_number column if it doesn't exist
ALTER TABLE scrap_submissions 
ADD COLUMN IF NOT EXISTS phone_number TEXT;

-- Update existing records to have phone_number (you'll need to set this manually)
-- For now, let's just add the column

-- Verify the column was added
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'scrap_submissions'
ORDER BY ordinal_position;
