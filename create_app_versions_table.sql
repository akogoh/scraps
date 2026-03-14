-- App version management for OTA (over-the-air) updates
-- When you release a new APK, add a row here and upload APK to Supabase Storage
CREATE TABLE IF NOT EXISTS public.app_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  version_name TEXT NOT NULL,           -- e.g. "1.0.1"
  build_number INTEGER NOT NULL,        -- e.g. 2 (from 1.0.0+1, the +1 part)
  download_url TEXT NOT NULL,           -- Full URL to APK (e.g. Supabase storage public URL)
  force_update BOOLEAN DEFAULT false,   -- If true, user must update to continue
  release_notes TEXT,                   -- What's new in this version
  created_at TIMESTAMPTZ DEFAULT now(),
  is_active BOOLEAN DEFAULT true
);

CREATE INDEX IF NOT EXISTS idx_app_versions_build ON public.app_versions(build_number DESC);

ALTER TABLE public.app_versions ENABLE ROW LEVEL SECURITY;

-- Allow public read (app users need to check for updates)
CREATE POLICY "Anyone can read active app versions"
  ON public.app_versions FOR SELECT
  USING (is_active = true);

-- Example: When you release v1.0.1 (build 2), run:
-- 1. Upload app-release.apk to Supabase Storage (e.g. bucket "app-releases")
-- 2. Get the public URL
-- 3. INSERT INTO app_versions (version_name, build_number, download_url, release_notes)
--    VALUES ('1.0.1', 2, 'https://xxx.supabase.co/storage/v1/object/public/app-releases/scraps-1.0.1.apk', 'Bug fixes and improvements');
