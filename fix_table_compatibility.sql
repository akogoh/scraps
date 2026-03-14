-- Fix table compatibility issues
-- Run this in your Supabase SQL Editor

-- First, let's check the current structure of the users table
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'users'
ORDER BY ordinal_position;

-- Option 1: If you want to keep TEXT id in users table, modify scrap_submissions
-- Drop the scrap_submissions table if it exists
DROP TABLE IF EXISTS scrap_submissions CASCADE;

-- Create scrap_submissions table with TEXT user_id to match users.id
CREATE TABLE scrap_submissions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
    item_name VARCHAR(255) NOT NULL,
    image_url TEXT,
    video_url TEXT,
    comments TEXT,
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'completed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create messages table with TEXT sender_id to match users.id
CREATE TABLE messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    submission_id UUID REFERENCES scrap_submissions(id) ON DELETE CASCADE,
    sender_id TEXT REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    is_admin_message BOOLEAN DEFAULT FALSE,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create storage bucket for images and videos
INSERT INTO storage.buckets (id, name, public)
VALUES ('scrap-media', 'scrap-media', true)
ON CONFLICT (id) DO NOTHING;

-- Create storage policies for the bucket (drop existing ones first)
DROP POLICY IF EXISTS "Allow public uploads" ON storage.objects;
DROP POLICY IF EXISTS "Allow public downloads" ON storage.objects;
DROP POLICY IF EXISTS "Allow public updates" ON storage.objects;

CREATE POLICY "Allow public uploads" ON storage.objects
FOR INSERT WITH CHECK (bucket_id = 'scrap-media');

CREATE POLICY "Allow public downloads" ON storage.objects
FOR SELECT USING (bucket_id = 'scrap-media');

CREATE POLICY "Allow public updates" ON storage.objects
FOR UPDATE USING (bucket_id = 'scrap-media');

-- Enable Row Level Security on new tables
ALTER TABLE scrap_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for scrap_submissions table
CREATE POLICY "Allow public insert for scrap submissions" ON scrap_submissions
    FOR INSERT 
    WITH CHECK (true);

CREATE POLICY "Allow public read for scrap submissions" ON scrap_submissions
    FOR SELECT 
    USING (true);

CREATE POLICY "Allow public update for scrap submissions" ON scrap_submissions
    FOR UPDATE 
    USING (true);

-- Create RLS policies for messages table
CREATE POLICY "Allow public insert for messages" ON messages
    FOR INSERT 
    WITH CHECK (true);

CREATE POLICY "Allow public read for messages" ON messages
    FOR SELECT 
    USING (true);

CREATE POLICY "Allow public update for messages" ON messages
    FOR UPDATE 
    USING (true);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_scrap_submissions_user_id ON scrap_submissions(user_id);
CREATE INDEX IF NOT EXISTS idx_scrap_submissions_status ON scrap_submissions(status);
CREATE INDEX IF NOT EXISTS idx_messages_submission_id ON messages(submission_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON messages(sender_id);

-- Verify tables were created
SELECT 
    table_name, 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns 
WHERE table_name IN ('users', 'scrap_submissions', 'messages')
ORDER BY table_name, ordinal_position;

-- Verify policies were created
SELECT * FROM pg_policies WHERE tablename IN ('scrap_submissions', 'messages');

-- Verify storage bucket was created
SELECT * FROM storage.buckets WHERE id = 'scrap-media';
