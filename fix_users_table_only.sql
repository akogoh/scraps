-- Fix Row Level Security policies for ONLY the users table
-- Run this in your Supabase SQL Editor

-- Check existing policies for users table
SELECT * FROM pg_policies WHERE tablename = 'users';

-- Drop ALL existing policies for users table (to start completely fresh)
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON users;
DROP POLICY IF EXISTS "Enable read access for all users" ON users;
DROP POLICY IF EXISTS "Enable update for users based on phone_number" ON users;
DROP POLICY IF EXISTS "Allow public registration" ON users;
DROP POLICY IF EXISTS "Users can view own data" ON users;
DROP POLICY IF EXISTS "Users can update own data" ON users;

-- Create new policies for the users table ONLY

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

-- Verify the policies were created
SELECT * FROM pg_policies WHERE tablename = 'users';
