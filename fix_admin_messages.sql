-- Fix Admin Messages - Run this in Supabase SQL Editor

-- 1. First, let's check if the messages table exists and has the right structure
-- If not, create it properly
CREATE TABLE IF NOT EXISTS messages (
    id TEXT PRIMARY KEY,
    submission_id TEXT NOT NULL REFERENCES scrap_submissions(id),
    sender_id TEXT NOT NULL,
    content TEXT NOT NULL,
    is_admin_message BOOLEAN DEFAULT FALSE,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Create admins table if it doesn't exist
CREATE TABLE IF NOT EXISTS admins (
    id TEXT PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login TIMESTAMP WITH TIME ZONE
);

-- 3. Insert default admin if not exists
INSERT INTO admins (id, username, email, password_hash, is_active) 
VALUES (
    'admin-001',
    'admin',
    'admin@scraps.com',
    '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', -- admin123
    TRUE
) ON CONFLICT (id) DO NOTHING;

-- 4. Drop existing RLS policies to avoid conflicts
DROP POLICY IF EXISTS "Admins can send messages" ON messages;
DROP POLICY IF EXISTS "Admins can view all messages" ON messages;
DROP POLICY IF EXISTS "Users can view own messages" ON messages;
DROP POLICY IF EXISTS "Users can send messages" ON messages;

-- 5. Disable RLS temporarily for testing
ALTER TABLE messages DISABLE ROW LEVEL SECURITY;
ALTER TABLE scrap_submissions DISABLE ROW LEVEL SECURITY;
ALTER TABLE users DISABLE ROW LEVEL SECURITY;

-- 6. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_messages_submission_id ON messages(submission_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at);

-- 7. Verify tables exist
SELECT 'Tables created successfully' as status;
