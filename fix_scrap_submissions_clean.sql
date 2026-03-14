ALTER TABLE scrap_submissions 
ADD COLUMN IF NOT EXISTS submitted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

ALTER TABLE scrap_submissions 
ADD COLUMN IF NOT EXISTS phone_number TEXT;

ALTER TABLE scrap_submissions 
ADD COLUMN IF NOT EXISTS latitude DECIMAL(10, 8);

ALTER TABLE scrap_submissions 
ADD COLUMN IF NOT EXISTS longitude DECIMAL(11, 8);

ALTER TABLE scrap_submissions 
ADD COLUMN IF NOT EXISTS address TEXT;
