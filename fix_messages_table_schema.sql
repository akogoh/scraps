-- Check current messages table structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'messages'
ORDER BY ordinal_position;

-- Add missing columns if they don't exist
ALTER TABLE messages 
ADD COLUMN IF NOT EXISTS sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Update existing records to have sent_at if they don't have it
UPDATE messages 
SET sent_at = NOW() 
WHERE sent_at IS NULL;

-- Verify the final structure
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'messages'
ORDER BY ordinal_position;
