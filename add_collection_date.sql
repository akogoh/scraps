-- Add collection_date column to scrap_submissions table
ALTER TABLE scrap_submissions 
ADD COLUMN IF NOT EXISTS collection_date TIMESTAMP WITH TIME ZONE;

-- Add index for better performance when filtering by collection date
CREATE INDEX IF NOT EXISTS idx_scrap_submissions_collection_date 
ON scrap_submissions(collection_date);
