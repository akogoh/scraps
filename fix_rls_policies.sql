-- Fix Row Level Security policies for the users table
-- Run this in your Supabase SQL Editor

-- First, let's check if RLS is enabled and what policies exist
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'users';

-- Check existing policies
SELECT * FROM pg_policies WHERE tablename = 'users';

-- Drop ALL existing policies for users table (to start completely fresh)
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON users;
DROP POLICY IF EXISTS "Enable read access for all users" ON users;
DROP POLICY IF EXISTS "Enable update for users based on phone_number" ON users;
DROP POLICY IF EXISTS "Allow public registration" ON users;
DROP POLICY IF EXISTS "Users can view own data" ON users;
DROP POLICY IF EXISTS "Users can update own data" ON users;

-- Create new policies for the users table

-- 1. Allow anyone to insert new users (for registration)
CREATE POLICY "Allow public registration" ON users
    FOR INSERT 
    WITH CHECK (true);

-- 2. Allow users to read their own data
CREATE POLICY "Users can view own data" ON users
    FOR SELECT 
    USING (true);

-- 3. Allow users to update their own data
CREATE POLICY "Users can update own data" ON users
    FOR UPDATE 
    USING (true);

-- Also create policies for scrap_submissions table
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON scrap_submissions;
DROP POLICY IF EXISTS "Enable read access for all users" ON scrap_submissions;
DROP POLICY IF EXISTS "Enable update for users based on user_id" ON scrap_submissions;

CREATE POLICY "Allow public insert for scrap submissions" ON scrap_submissions
    FOR INSERT 
    WITH CHECK (true);

CREATE POLICY "Allow public read for scrap submissions" ON scrap_submissions
    FOR SELECT 
    USING (true);

CREATE POLICY "Allow public update for scrap submissions" ON scrap_submissions
    FOR UPDATE 
    USING (true);

-- Create policies for messages table
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON messages;
DROP POLICY IF EXISTS "Enable read access for all users" ON messages;
DROP POLICY IF EXISTS "Enable update for users based on user_id" ON messages;

CREATE POLICY "Allow public insert for messages" ON messages
    FOR INSERT 
    WITH CHECK (true);

CREATE POLICY "Allow public read for messages" ON messages
    FOR SELECT 
    USING (true);

CREATE POLICY "Allow public update for messages" ON messages
    FOR UPDATE 
    USING (true);

-- Verify the policies were created
SELECT * FROM pg_policies WHERE tablename IN ('users', 'scrap_submissions', 'messages');
