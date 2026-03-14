-- Recreate admin_dashboard view to include collection_date, price, image_url, video_url
-- Run this in the Supabase SQL editor
-- This version handles both created_at and submitted_at columns

BEGIN;

DROP VIEW IF EXISTS admin_dashboard;

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


