-- Update existing field_officers table and setup for Field Officer Portal
-- Run this in the Supabase SQL Editor (safe to run multiple times)

BEGIN;

-- 1. Add missing columns to field_officers table if they don't exist
DO $$
BEGIN
    -- Add password column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'field_officers' AND column_name = 'password'
    ) THEN
        ALTER TABLE field_officers ADD COLUMN password TEXT NULL;
    END IF;

    -- Add phone_number column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'field_officers' AND column_name = 'phone_number'
    ) THEN
        ALTER TABLE field_officers ADD COLUMN phone_number TEXT;
    END IF;

    -- Add email column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'field_officers' AND column_name = 'email'
    ) THEN
        ALTER TABLE field_officers ADD COLUMN email TEXT;
    END IF;

    -- Add is_active column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'field_officers' AND column_name = 'is_active'
    ) THEN
        ALTER TABLE field_officers ADD COLUMN is_active BOOLEAN DEFAULT TRUE;
    END IF;

    -- Add created_at column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'field_officers' AND column_name = 'created_at'
    ) THEN
        ALTER TABLE field_officers ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    END IF;

    -- Add last_login column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'field_officers' AND column_name = 'last_login'
    ) THEN
        ALTER TABLE field_officers ADD COLUMN last_login TIMESTAMP WITH TIME ZONE;
    END IF;

    -- Add UNIQUE constraint on name if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'field_officers_name_key'
    ) THEN
        ALTER TABLE field_officers ADD CONSTRAINT field_officers_name_key UNIQUE (name);
    END IF;
END $$;

-- 2. Create indexes for field_officers (if they don't exist)
CREATE INDEX IF NOT EXISTS idx_field_officers_name ON field_officers(name);
CREATE INDEX IF NOT EXISTS idx_field_officers_is_active ON field_officers(is_active);

-- 3. Add foreign key constraint for assigned_officer_id (if it doesn't exist)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'fk_assigned_officer'
    ) THEN
        ALTER TABLE scrap_submissions 
        ADD CONSTRAINT fk_assigned_officer 
        FOREIGN KEY (assigned_officer_id) 
        REFERENCES field_officers(id) 
        ON DELETE SET NULL;
    END IF;
END $$;

-- 4. Create index for assigned_officer_id (if it doesn't exist)
CREATE INDEX IF NOT EXISTS idx_scrap_submissions_assigned_officer_id 
ON scrap_submissions(assigned_officer_id);

-- 5. Update status check constraint to include 'reviewed' (if needed)
DO $$
BEGIN
    -- Check if constraint exists
    IF EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'scrap_submissions_status_check'
    ) THEN
        -- Drop existing constraint
        ALTER TABLE scrap_submissions 
        DROP CONSTRAINT scrap_submissions_status_check;
    END IF;
    
    -- Add updated constraint with all statuses including 'reviewed'
    ALTER TABLE scrap_submissions 
    ADD CONSTRAINT scrap_submissions_status_check 
    CHECK (
      status::text = ANY (
        ARRAY[
          'pending'::character varying,
          'reviewed'::character varying,
          'approved'::character varying,
          'rejected'::character varying,
          'completed'::character varying
        ]::text[]
      )
    );
END $$;

-- 6. Insert a sample field officer for testing (only if doesn't exist)
INSERT INTO field_officers (name, phone_number, email, is_active)
VALUES (
    'John Doe',
    '+1234567890',
    'john.doe@greenhaul.com',
    TRUE
) ON CONFLICT (name) DO NOTHING;

-- Create a view for field officer assigned jobs
CREATE OR REPLACE VIEW field_officer_jobs AS
SELECT
  s.id,
  s.item_name,
  s.comments,
  s.status,
  COALESCE(s.submitted_at, s.created_at) as submitted_at,
  s.latitude,
  s.longitude,
  s.address,
  s.image_url,
  s.video_url,
  s.admin_notes,
  s.reviewed_by,
  s.reviewed_at,
  COALESCE(s.price, 0) as price,
  s.collection_date,
  s.assigned_officer_id,
  s.assigned_at,
  s.assigned_by,
  u.name as user_name,
  COALESCE(s.phone_number, u.phone_number) as phone_number,
  (
    SELECT COUNT(*)
    FROM messages m
    WHERE m.submission_id = s.id
  ) as message_count
FROM scrap_submissions s
INNER JOIN users u ON u.id::text = s.user_id::text
WHERE s.assigned_officer_id IS NOT NULL;

-- Grant permissions
GRANT SELECT ON field_officer_jobs TO authenticated;
GRANT SELECT ON field_officer_jobs TO anon;

-- Grant access to field_officers table
GRANT SELECT ON field_officers TO authenticated;
GRANT SELECT ON field_officers TO anon;

COMMIT;

-- Verify tables created
SELECT 'Field officers table created successfully' as status;
