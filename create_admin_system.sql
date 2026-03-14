-- Admin System for Scraps App
-- Run these SQL commands in your Supabase SQL Editor

-- 1. Create admin table
CREATE TABLE IF NOT EXISTS admins (
    id TEXT PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login TIMESTAMP WITH TIME ZONE
);

-- 2. Update messages table to use proper structure
ALTER TABLE messages 
DROP COLUMN IF EXISTS phone_number,
DROP COLUMN IF EXISTS message,
DROP COLUMN IF EXISTS is_from_admin,
DROP COLUMN IF EXISTS sent_at;

-- Add new columns
ALTER TABLE messages 
ADD COLUMN IF NOT EXISTS sender_id TEXT NOT NULL,
ADD COLUMN IF NOT EXISTS content TEXT NOT NULL,
ADD COLUMN IF NOT EXISTS is_admin_message BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- 3. Add admin_id to scrap_submissions for tracking
ALTER TABLE scrap_submissions 
ADD COLUMN IF NOT EXISTS admin_notes TEXT,
ADD COLUMN IF NOT EXISTS reviewed_by TEXT REFERENCES admins(id),
ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMP WITH TIME ZONE;

-- 4. Create indexes for admin operations
CREATE INDEX IF NOT EXISTS idx_scrap_submissions_status ON scrap_submissions(status);
CREATE INDEX IF NOT EXISTS idx_scrap_submissions_submitted_at ON scrap_submissions(submitted_at);
CREATE INDEX IF NOT EXISTS idx_messages_submission_id ON messages(submission_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_is_admin_message ON messages(is_admin_message);

-- 5. Create RLS policies for admin access
-- Allow admins to see all submissions
CREATE POLICY "Admins can view all submissions" ON scrap_submissions
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM admins 
            WHERE admins.id = current_setting('app.current_admin_id', true)
            AND admins.is_active = TRUE
        )
    );

-- Allow admins to update submission status
CREATE POLICY "Admins can update submissions" ON scrap_submissions
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM admins 
            WHERE admins.id = current_setting('app.current_admin_id', true)
            AND admins.is_active = TRUE
        )
    );

-- Allow admins to send messages
CREATE POLICY "Admins can send messages" ON messages
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM admins 
            WHERE admins.id = current_setting('app.current_admin_id', true)
            AND admins.is_active = TRUE
        )
    );

-- Allow admins to view all messages
CREATE POLICY "Admins can view all messages" ON messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM admins 
            WHERE admins.id = current_setting('app.current_admin_id', true)
            AND admins.is_active = TRUE
        )
    );

-- 6. Insert default admin (password: admin123)
INSERT INTO admins (id, username, email, password_hash, is_active) 
VALUES (
    'admin-001',
    'admin',
    'admin@scraps.com',
    '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', -- admin123
    TRUE
) ON CONFLICT (id) DO NOTHING;

-- 7. Create admin dashboard view
CREATE OR REPLACE VIEW admin_dashboard AS
SELECT 
    ss.id,
    ss.item_name,
    ss.comments,
    ss.status,
    ss.submitted_at,
    ss.latitude,
    ss.longitude,
    ss.address,
    u.name as user_name,
    u.phone_number,
    ss.image_url,
    ss.video_url,
    ss.admin_notes,
    a.username as reviewed_by,
    ss.reviewed_at,
    COUNT(m.id) as message_count
FROM scrap_submissions ss
LEFT JOIN users u ON ss.user_id = u.id
LEFT JOIN admins a ON ss.reviewed_by = a.id
LEFT JOIN messages m ON ss.id = m.submission_id
GROUP BY ss.id, u.name, u.phone_number, a.username;

-- 8. Create function to get submission statistics
CREATE OR REPLACE FUNCTION get_submission_stats()
RETURNS TABLE (
    total_submissions BIGINT,
    pending_count BIGINT,
    reviewed_count BIGINT,
    approved_count BIGINT,
    rejected_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_submissions,
        COUNT(*) FILTER (WHERE status = 'pending') as pending_count,
        COUNT(*) FILTER (WHERE status = 'reviewed') as reviewed_count,
        COUNT(*) FILTER (WHERE status = 'approved') as approved_count,
        COUNT(*) FILTER (WHERE status = 'rejected') as rejected_count
    FROM scrap_submissions;
END;
$$ LANGUAGE plpgsql;

-- 9. Create function to get recent submissions
CREATE OR REPLACE FUNCTION get_recent_submissions(limit_count INTEGER DEFAULT 10)
RETURNS TABLE (
    id TEXT,
    item_name TEXT,
    user_name TEXT,
    phone_number TEXT,
    status TEXT,
    submitted_at TIMESTAMP WITH TIME ZONE,
    message_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ss.id,
        ss.item_name,
        u.name as user_name,
        u.phone_number,
        ss.status,
        ss.submitted_at,
        COUNT(m.id) as message_count
    FROM scrap_submissions ss
    LEFT JOIN users u ON ss.user_id = u.id
    LEFT JOIN messages m ON ss.id = m.submission_id
    GROUP BY ss.id, ss.item_name, u.name, u.phone_number, ss.status, ss.submitted_at
    ORDER BY ss.submitted_at DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;
