-- Add location columns to field_officers table
-- Run this in the Supabase SQL Editor

BEGIN;

-- Add location columns if they don't exist
DO $$
BEGIN
    -- Add latitude column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'field_officers' AND column_name = 'latitude'
    ) THEN
        ALTER TABLE field_officers ADD COLUMN latitude DOUBLE PRECISION;
    END IF;

    -- Add longitude column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'field_officers' AND column_name = 'longitude'
    ) THEN
        ALTER TABLE field_officers ADD COLUMN longitude DOUBLE PRECISION;
    END IF;

    -- Add last_location_update column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'field_officers' AND column_name = 'last_location_update'
    ) THEN
        ALTER TABLE field_officers ADD COLUMN last_location_update TIMESTAMP WITH TIME ZONE;
    END IF;
END $$;

COMMIT;

-- Verify columns were added
SELECT 
    column_name, 
    data_type 
FROM information_schema.columns 
WHERE table_name = 'field_officers' 
  AND column_name IN ('latitude', 'longitude', 'last_location_update');
