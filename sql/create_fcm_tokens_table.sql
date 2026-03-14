-- FCM device tokens for push notifications (WhatsApp-style).
-- Run in Supabase SQL Editor once.

CREATE TABLE IF NOT EXISTS public.fcm_tokens (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  token TEXT NOT NULL,
  user_id UUID NULL REFERENCES users(id) ON DELETE CASCADE,
  field_officer_id UUID NULL REFERENCES field_officers(id) ON DELETE CASCADE,
  platform TEXT NOT NULL DEFAULT 'android',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT fcm_tokens_pkey PRIMARY KEY (id),
  CONSTRAINT fcm_tokens_token_key UNIQUE (token),
  CONSTRAINT fcm_tokens_owner_check CHECK (
    (user_id IS NOT NULL AND field_officer_id IS NULL) OR
    (user_id IS NULL AND field_officer_id IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_fcm_tokens_user ON fcm_tokens (user_id);
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_officer ON fcm_tokens (field_officer_id);
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_token ON fcm_tokens (token);

-- RLS: allow anon to insert/update (app sends token with anon key)
ALTER TABLE fcm_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow insert for anon"
  ON fcm_tokens FOR INSERT TO anon WITH CHECK (true);

CREATE POLICY "Allow update for anon"
  ON fcm_tokens FOR UPDATE TO anon USING (true) WITH CHECK (true);

CREATE POLICY "Allow select for anon"
  ON fcm_tokens FOR SELECT TO anon USING (true);

COMMENT ON TABLE fcm_tokens IS 'FCM device tokens for push; used by Edge Function send-push to notify users and field officers.';
