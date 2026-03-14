-- Test script for scrap_submissions table
-- Run these queries in Supabase SQL Editor to test your scrap_submissions table

-- 1. Insert a test submission (make sure you have a user with this phone number first)
INSERT INTO scrap_submissions (id, user_id, phone_number, item_name, comments, status) 
VALUES (
    'test_submission_1', 
    'test_user_1', 
    '9876543210', 
    'Broken Car Engine', 
    'This is a test submission for a broken car engine. It has been sitting in my garage for 2 years.',
    'pending'
);

-- 2. Insert another test submission
INSERT INTO scrap_submissions (id, user_id, phone_number, item_name, image_url, comments, status) 
VALUES (
    'test_submission_2', 
    'test_user_2', 
    '9876543211', 
    'Old Refrigerator', 
    'https://example.com/image.jpg',
    'Old refrigerator that stopped working. Still in good condition externally.',
    'reviewed'
);

-- 3. Query all submissions
SELECT * FROM scrap_submissions;

-- 4. Query submissions by phone number
SELECT * FROM scrap_submissions WHERE phone_number = '9876543210';

-- 5. Query submissions by status
SELECT * FROM scrap_submissions WHERE status = 'pending';

-- 6. Count submissions by status
SELECT status, COUNT(*) as count FROM scrap_submissions GROUP BY status;

-- 7. Update submission status
UPDATE scrap_submissions 
SET status = 'approved' 
WHERE id = 'test_submission_1';

-- 8. Query updated submission
SELECT * FROM scrap_submissions WHERE id = 'test_submission_1';

-- 9. Clean up test data (run this after testing)
-- DELETE FROM scrap_submissions WHERE id IN ('test_submission_1', 'test_submission_2');
