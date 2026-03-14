-- Complete database setup for Scraps App
-- Run this in your Supabase SQL Editor

-- 1. Create users table (if not exists)
CREATE TABLE IF NOT EXISTS users (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Create scrap_submissions table
CREATE TABLE IF NOT EXISTS scrap_submissions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    item_name VARCHAR(255) NOT NULL,
    image_url TEXT,
    video_url TEXT,
    comments TEXT,
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'completed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Create messages table
CREATE TABLE IF NOT EXISTS messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    submission_id UUID REFERENCES scrap_submissions(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    is_admin_message BOOLEAN DEFAULT FALSE,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Create storage bucket for images and videos
INSERT INTO storage.buckets (id, name, public)
VALUES ('scrap-media', 'scrap-media', true)
ON CONFLICT (id) DO NOTHING;

-- 5. Create storage policies for the bucket
CREATE POLICY "Allow public uploads" ON storage.objects
FOR INSERT WITH CHECK (bucket_id = 'scrap-media');

CREATE POLICY "Allow public downloads" ON storage.objects
FOR SELECT USING (bucket_id = 'scrap-media');

CREATE POLICY "Allow public updates" ON storage.objects
FOR UPDATE USING (bucket_id = 'scrap-media');

-- 6. Enable Row Level Security on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE scrap_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- 7. Create RLS policies for users table
DROP POLICY IF EXISTS "Allow public registration" ON users;
DROP POLICY IF EXISTS "Users can view own data" ON users;
DROP POLICY IF EXISTS "Users can update own data" ON users;

CREATE POLICY "Allow public registration" ON users
    FOR INSERT 
    WITH CHECK (true);

CREATE POLICY "Users can view own data" ON users
    FOR SELECT 
    USING (true);

CREATE POLICY "Users can update own data" ON users
    FOR UPDATE 
    USING (true);

-- 8. Create RLS policies for scrap_submissions table
DROP POLICY IF EXISTS "Allow public insert for scrap submissions" ON scrap_submissions;
DROP POLICY IF EXISTS "Allow public read for scrap submissions" ON scrap_submissions;
DROP POLICY IF EXISTS "Allow public update for scrap submissions" ON scrap_submissions;

CREATE POLICY "Allow public insert for scrap submissions" ON scrap_submissions
    FOR INSERT 
    WITH CHECK (true);

CREATE POLICY "Allow public read for scrap submissions" ON scrap_submissions
    FOR SELECT 
    USING (true);

CREATE POLICY "Allow public update for scrap submissions" ON scrap_submissions
    FOR UPDATE 
    USING (true);

-- 9. Create RLS policies for messages table
DROP POLICY IF EXISTS "Allow public insert for messages" ON messages;
DROP POLICY IF EXISTS "Allow public read for messages" ON messages;
DROP POLICY IF EXISTS "Allow public update for messages" ON messages;

CREATE POLICY "Allow public insert for messages" ON messages
    FOR INSERT 
    WITH CHECK (true);

CREATE POLICY "Allow public read for messages" ON messages
    FOR SELECT 
    USING (true);

CREATE POLICY "Allow public update for messages" ON messages
    FOR UPDATE 
    USING (true);

-- 10. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone_number);
CREATE INDEX IF NOT EXISTS idx_scrap_submissions_user_id ON scrap_submissions(user_id);
CREATE INDEX IF NOT EXISTS idx_scrap_submissions_status ON scrap_submissions(status);
CREATE INDEX IF NOT EXISTS idx_messages_submission_id ON messages(submission_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON messages(sender_id);

-- 11. Verify tables were created
SELECT 
    table_name, 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns 
WHERE table_name IN ('users', 'scrap_submissions', 'messages')
ORDER BY table_name, ordinal_position;

-- 12. Verify policies were created
SELECT * FROM pg_policies WHERE tablename IN ('users', 'scrap_submissions', 'messages');

-- 13. Verify storage bucket was created
SELECT * FROM storage.buckets WHERE id = 'scrap-media';
