-- Announcements / Broadcasts table
-- Web app creates announcements; mobile app fetches and displays them
CREATE TABLE IF NOT EXISTS public.announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  type TEXT DEFAULT 'announcement' CHECK (type IN ('announcement', 'deal', 'info', 'urgent')),
  image_url TEXT,
  link_url TEXT,
  priority INTEGER DEFAULT 0,  -- higher = more prominent (e.g. 10 for popup)
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ,
  created_by TEXT
);

CREATE INDEX IF NOT EXISTS idx_announcements_active ON public.announcements(is_active);
CREATE INDEX IF NOT EXISTS idx_announcements_created_at ON public.announcements(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_announcements_expires_at ON public.announcements(expires_at);

-- Allow public read (anon) for app users; web admin uses service role
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read active announcements"
  ON public.announcements FOR SELECT
  USING (is_active = true AND (expires_at IS NULL OR expires_at > now()));

-- Service role (web app) bypasses RLS - use it for creating/editing announcements from the web dashboard.
-- Example insert (run from Supabase SQL Editor):
--
-- INSERT INTO announcements (title, body, type, priority, is_active) VALUES
--   ('Special Deal', 'Get 20% extra on your next scrap collection! Valid this week.', 'deal', 10, true);
