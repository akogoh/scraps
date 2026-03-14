-- Add app version 1.0.2 (build 3) for in-app update. Run in Supabase SQL Editor once.
-- APK is at: app-releases/app-release.apk (you already uploaded).

-- Optional: mark previous versions as not active so only this one is offered
UPDATE app_versions SET is_active = false WHERE is_active = true;

-- Insert new version row
INSERT INTO app_versions (
  version_name,
  build_number,
  download_url,
  force_update,
  release_notes,
  is_active
) VALUES (
  '1.0.2',
  3,
  'https://czfjhpnmkuvbcupombgp.supabase.co/storage/v1/object/public/app-releases/app-release.apk',
  false,
  'Location updates after logout; chat fix; push notifications.',
  true
);
