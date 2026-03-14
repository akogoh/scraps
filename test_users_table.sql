-- Test script for users table
-- Run these queries in Supabase SQL Editor to test your users table

-- 1. Insert a test user
INSERT INTO users (id, name, phone_number) 
VALUES ('test_user_1', 'John Doe', '9876543210');

-- 2. Insert another test user
INSERT INTO users (id, name, phone_number) 
VALUES ('test_user_2', 'Jane Smith', '9876543211');

-- 3. Query all users
SELECT * FROM users;

-- 4. Query user by phone number
SELECT * FROM users WHERE phone_number = '9876543210';

-- 5. Count total users
SELECT COUNT(*) as total_users FROM users;

-- 6. Test unique constraint (this should fail)
-- INSERT INTO users (id, name, phone_number) 
-- VALUES ('test_user_3', 'Duplicate Phone', '9876543210');

-- 7. Clean up test data (run this after testing)
-- DELETE FROM users WHERE id IN ('test_user_1', 'test_user_2');
