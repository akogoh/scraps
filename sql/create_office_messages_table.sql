-- Office / team chat: messages between admins and field officers.
-- Run this in Supabase SQL Editor.

CREATE TABLE IF NOT EXISTS office_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id TEXT NOT NULL,
    sender_type TEXT NOT NULL CHECK (sender_type IN ('admin', 'field_officer')),
    recipient_id TEXT NOT NULL,
    recipient_type TEXT NOT NULL CHECK (recipient_type IN ('admin', 'field_officer')),
    content TEXT NOT NULL DEFAULT '',
    image_url TEXT,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_office_messages_sender ON office_messages(sender_id, sender_type);
CREATE INDEX IF NOT EXISTS idx_office_messages_recipient ON office_messages(recipient_id, recipient_type);
CREATE INDEX IF NOT EXISTS idx_office_messages_created ON office_messages(created_at);

-- Allow all for now (anon key); tighten with RLS if needed.
ALTER TABLE office_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all for office_messages" ON office_messages;
CREATE POLICY "Allow all for office_messages" ON office_messages
    FOR ALL USING (true) WITH CHECK (true);
