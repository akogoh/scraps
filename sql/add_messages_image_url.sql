-- Optional: add image_url to messages so admin/officer can send images in chat.
-- Run in Supabase SQL Editor if you want image support in submission messages.

ALTER TABLE messages
  ADD COLUMN IF NOT EXISTS image_url TEXT;
