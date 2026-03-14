-- Create admin_dashboard view for Field Officer Portal
-- This view provides a comprehensive view of all scrap submissions with user information
-- Run this in the Supabase SQL Editor

BEGIN;

-- Drop the view if it exists
DROP VIEW IF EXISTS admin_dashboard;

-- Create the admin_dashboard view
-- This view handles both created_at and submitted_at columns
CREATE VIEW admin_dashboard AS
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
  u.name as user_name,
  COALESCE(s.phone_number, u.phone_number) as phone_number,
  (
    SELECT COUNT(*)
    FROM messages m
    WHERE m.submission_id = s.id
  ) as message_count
FROM scrap_submissions s
INNER JOIN users u ON u.id::text = s.user_id::text;

-- Grant permissions to allow access
GRANT SELECT ON admin_dashboard TO authenticated;
GRANT SELECT ON admin_dashboard TO anon;

COMMIT;

-- Verify the view was created
SELECT 
  table_name,
  view_definition
FROM information_schema.views
WHERE table_schema = 'public'
  AND table_name = 'admin_dashboard';

