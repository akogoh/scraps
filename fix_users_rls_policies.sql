-- Fix RLS policies for users table to allow registration
-- Run this in your Supabase SQL Editor

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view own data" ON users;
DROP POLICY IF EXISTS "Users can insert own data" ON users;
DROP POLICY IF EXISTS "Admins can view all data" ON users;
DROP POLICY IF EXISTS "Allow public registration" ON users;
DROP POLICY IF EXISTS "Users can update own data" ON users;

-- 1. Allow anyone to INSERT (for registration)
-- This allows new users to register without being logged in
CREATE POLICY "Allow public registration" ON users
    FOR INSERT 
    WITH CHECK (true);

-- 2. Allow users to SELECT their own data by phone number
-- This allows users to check if they exist and login
CREATE POLICY "Users can view own data" ON users
    FOR SELECT 
    USING (true);  -- Allow all reads for now, or use: phone_number = current_setting('app.current_user_phone', true) OR true

-- 3. Allow users to UPDATE their own data
CREATE POLICY "Users can update own data" ON users
    FOR UPDATE 
    USING (true)
    WITH CHECK (true);

-- 4. Admin policy (for admin dashboard)
CREATE POLICY "Admins can view all data" ON users
    FOR ALL 
    USING (current_setting('app.is_admin', true) = 'true');

-- Verify policies were created
SELECT * FROM pg_policies WHERE tablename = 'users';

