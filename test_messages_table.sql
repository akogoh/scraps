-- Test script for messages table
-- Run these queries in Supabase SQL Editor to test your messages table

-- 1. Insert a test message from user
INSERT INTO messages (id, submission_id, phone_number, message, is_from_admin) 
VALUES (
    'test_message_1', 
    'test_submission_1', 
    '9876543210', 
    'Hello, I would like to know more about the valuation of my car engine.',
    FALSE
);

-- 2. Insert a test message from admin
INSERT INTO messages (id, submission_id, phone_number, message, is_from_admin) 
VALUES (
    'test_message_2', 
    'test_submission_1', 
    '9876543210', 
    'Thank you for your submission. We will review your car engine and get back to you within 24 hours.',
    TRUE
);

-- 3. Insert another user message
INSERT INTO messages (id, submission_id, phone_number, message, is_from_admin) 
VALUES (
    'test_message_3', 
    'test_submission_1', 
    '9876543210', 
    'Thank you for the quick response. I look forward to hearing from you.',
    FALSE
);

-- 4. Query all messages
SELECT * FROM messages ORDER BY sent_at;

-- 5. Query messages for a specific submission
SELECT * FROM messages WHERE submission_id = 'test_submission_1' ORDER BY sent_at;

-- 6. Query messages by phone number
SELECT * FROM messages WHERE phone_number = '9876543210' ORDER BY sent_at;

-- 7. Query admin messages only
SELECT * FROM messages WHERE is_from_admin = TRUE;

-- 8. Query user messages only
SELECT * FROM messages WHERE is_from_admin = FALSE;

-- 9. Count messages by submission
SELECT submission_id, COUNT(*) as message_count FROM messages GROUP BY submission_id;

-- 10. Clean up test data (run this after testing)
-- DELETE FROM messages WHERE id IN ('test_message_1', 'test_message_2', 'test_message_3');
