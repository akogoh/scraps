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

-- Create indexes for better performance
CREATE INDEX idx_scrap_submissions_phone ON scrap_submissions(phone_number);
CREATE INDEX idx_scrap_submissions_status ON scrap_submissions(status);
CREATE INDEX idx_scrap_submissions_user_id ON scrap_submissions(user_id);

-- Enable Row Level Security (RLS)
ALTER TABLE scrap_submissions ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
-- Users can view their own submissions
CREATE POLICY "Users can view own submissions" ON scrap_submissions
    FOR SELECT USING (phone_number = current_setting('app.current_user_phone', true));

-- Users can insert their own submissions
CREATE POLICY "Users can insert own submissions" ON scrap_submissions
    FOR INSERT WITH CHECK (phone_number = current_setting('app.current_user_phone', true));

-- Users can update their own submissions (for status changes)
CREATE POLICY "Users can update own submissions" ON scrap_submissions
    FOR UPDATE USING (phone_number = current_setting('app.current_user_phone', true));

-- Admin policies (for admin dashboard)
CREATE POLICY "Admins can view all submissions" ON scrap_submissions
    FOR ALL USING (current_setting('app.is_admin', true) = 'true');
