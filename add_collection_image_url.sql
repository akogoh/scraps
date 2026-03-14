-- Add admin_collection_image_url column to scrap_submissions
-- Stores the photo URL when a field officer marks a job as collected
-- Does NOT modify any views - status and other columns are unchanged
ALTER TABLE scrap_submissions
ADD COLUMN IF NOT EXISTS admin_collection_image_url TEXT;
