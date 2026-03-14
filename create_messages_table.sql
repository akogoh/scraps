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
CREATE INDEX idx_messages_submission_id ON messages(submission_id);
CREATE INDEX idx_messages_phone ON messages(phone_number);
CREATE INDEX idx_messages_sent_at ON messages(sent_at);

-- Enable Row Level Security (RLS)
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
-- Users can view messages for their own submissions
CREATE POLICY "Users can view messages for own submissions" ON messages
    FOR SELECT USING (phone_number = current_setting('app.current_user_phone', true));

-- Users can insert messages for their own submissions
CREATE POLICY "Users can insert messages for own submissions" ON messages
    FOR INSERT WITH CHECK (phone_number = current_setting('app.current_user_phone', true));

-- Admin policies (for admin dashboard)
CREATE POLICY "Admins can view all messages" ON messages
    FOR ALL USING (current_setting('app.is_admin', true) = 'true');
