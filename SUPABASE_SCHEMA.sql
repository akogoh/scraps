-- Supabase Database Schema for Scraps App
-- Run these SQL commands in your Supabase SQL Editor

-- Create users table
CREATE TABLE users (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    phone_number TEXT UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create scrap_submissions table
CREATE TABLE scrap_submissions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id),
    phone_number TEXT NOT NULL,
    item_name TEXT NOT NULL,
    image_url TEXT,
    video_url TEXT,
    comments TEXT NOT NULL,
    submitted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'approved', 'rejected'))
);

-- Create messages table
CREATE TABLE messages (
    id TEXT PRIMARY KEY,
    submission_id TEXT NOT NULL REFERENCES scrap_submissions(id),
    phone_number TEXT NOT NULL,
    message TEXT NOT NULL,
    is_from_admin BOOLEAN DEFAULT FALSE,
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX idx_scrap_submissions_phone ON scrap_submissions(phone_number);
CREATE INDEX idx_scrap_submissions_status ON scrap_submissions(status);
CREATE INDEX idx_messages_submission_id ON messages(submission_id);
CREATE INDEX idx_messages_phone ON messages(phone_number);

-- Enable Row Level Security (RLS)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE scrap_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
-- Users can only see their own data
CREATE POLICY "Users can view own data" ON users
    FOR SELECT USING (phone_number = current_setting('app.current_user_phone', true));

CREATE POLICY "Users can insert own data" ON users
    FOR INSERT WITH CHECK (phone_number = current_setting('app.current_user_phone', true));

-- Scrap submissions policies
CREATE POLICY "Users can view own submissions" ON scrap_submissions
    FOR SELECT USING (phone_number = current_setting('app.current_user_phone', true));

CREATE POLICY "Users can insert own submissions" ON scrap_submissions
    FOR INSERT WITH CHECK (phone_number = current_setting('app.current_user_phone', true));

-- Messages policies
CREATE POLICY "Users can view messages for own submissions" ON messages
    FOR SELECT USING (phone_number = current_setting('app.current_user_phone', true));

CREATE POLICY "Users can insert messages for own submissions" ON messages
    FOR INSERT WITH CHECK (phone_number = current_setting('app.current_user_phone', true));

-- Admin policies (for admin dashboard)
CREATE POLICY "Admins can view all data" ON users
    FOR ALL USING (current_setting('app.is_admin', true) = 'true');

CREATE POLICY "Admins can view all submissions" ON scrap_submissions
    FOR ALL USING (current_setting('app.is_admin', true) = 'true');

CREATE POLICY "Admins can view all messages" ON messages
    FOR ALL USING (current_setting('app.is_admin', true) = 'true');

-- Create storage bucket for images and videos
INSERT INTO storage.buckets (id, name, public) VALUES ('scrap-media', 'scrap-media', true);

-- Create storage policies
CREATE POLICY "Users can upload own media" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'scrap-media' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can view own media" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'scrap-media' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Public can view media" ON storage.objects
    FOR SELECT USING (bucket_id = 'scrap-media');
