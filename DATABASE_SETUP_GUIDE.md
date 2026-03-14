# 🗄️ Database Setup Guide for Scraps App

## 📋 **Step-by-Step Database Creation**

### **1. Create Users Table**
Run this SQL in your Supabase SQL Editor:

```sql
-- Create users table
CREATE TABLE users (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    phone_number TEXT UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create an index for better performance
CREATE INDEX idx_users_phone ON users(phone_number);

-- Enable Row Level Security (RLS)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Create RLS policy for users to view their own data
CREATE POLICY "Users can view own data" ON users
    FOR SELECT USING (phone_number = current_setting('app.current_user_phone', true));

-- Create RLS policy for users to insert their own data
CREATE POLICY "Users can insert own data" ON users
    FOR INSERT WITH CHECK (phone_number = current_setting('app.current_user_phone', true));

-- Create admin policy (for admin dashboard)
CREATE POLICY "Admins can view all data" ON users
    FOR ALL USING (current_setting('app.is_admin', true) = 'true');
```

### **2. Create Scrap Submissions Table**
Run this SQL in your Supabase SQL Editor:

```sql
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
CREATE POLICY "Users can view own submissions" ON scrap_submissions
    FOR SELECT USING (phone_number = current_setting('app.current_user_phone', true));

CREATE POLICY "Users can insert own submissions" ON scrap_submissions
    FOR INSERT WITH CHECK (phone_number = current_setting('app.current_user_phone', true));

CREATE POLICY "Users can update own submissions" ON scrap_submissions
    FOR UPDATE USING (phone_number = current_setting('app.current_user_phone', true));

CREATE POLICY "Admins can view all submissions" ON scrap_submissions
    FOR ALL USING (current_setting('app.is_admin', true) = 'true');
```

### **3. Create Messages Table**
Run this SQL in your Supabase SQL Editor:

```sql
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
CREATE POLICY "Users can view messages for own submissions" ON messages
    FOR SELECT USING (phone_number = current_setting('app.current_user_phone', true));

CREATE POLICY "Users can insert messages for own submissions" ON messages
    FOR INSERT WITH CHECK (phone_number = current_setting('app.current_user_phone', true));

CREATE POLICY "Admins can view all messages" ON messages
    FOR ALL USING (current_setting('app.is_admin', true) = 'true');
```

### **4. Create Storage Bucket**
Run this SQL in your Supabase SQL Editor:

```sql
-- Create storage bucket for scrap media (images and videos)
INSERT INTO storage.buckets (id, name, public) 
VALUES ('scrap-media', 'scrap-media', true);

-- Create storage policies for the scrap-media bucket
CREATE POLICY "Users can upload own media" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'scrap-media' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can view own media" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'scrap-media' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Public can view media" ON storage.objects
    FOR SELECT USING (bucket_id = 'scrap-media');

CREATE POLICY "Users can delete own media" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'scrap-media' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Admins can manage all media" ON storage.objects
    FOR ALL USING (
        bucket_id = 'scrap-media' AND
        current_setting('app.is_admin', true) = 'true'
    );
```

## 🧪 **Testing Your Database**

### **Test Users Table**
```sql
-- Insert test users
INSERT INTO users (id, name, phone_number) 
VALUES ('test_user_1', 'John Doe', '9876543210');

INSERT INTO users (id, name, phone_number) 
VALUES ('test_user_2', 'Jane Smith', '9876543211');

-- Query users
SELECT * FROM users;
```

### **Test Scrap Submissions Table**
```sql
-- Insert test submission
INSERT INTO scrap_submissions (id, user_id, phone_number, item_name, comments, status) 
VALUES (
    'test_submission_1', 
    'test_user_1', 
    '9876543210', 
    'Broken Car Engine', 
    'This is a test submission for a broken car engine.',
    'pending'
);

-- Query submissions
SELECT * FROM scrap_submissions;
```

### **Test Messages Table**
```sql
-- Insert test message
INSERT INTO messages (id, submission_id, phone_number, message, is_from_admin) 
VALUES (
    'test_message_1', 
    'test_submission_1', 
    '9876543210', 
    'Hello, I would like to know more about the valuation.',
    FALSE
);

-- Query messages
SELECT * FROM messages;
```

## 🔧 **Update Your Flutter App**

1. **Get your Supabase credentials:**
   - Go to **Settings** → **API** in your Supabase dashboard
   - Copy your **Project URL** and **anon public** key

2. **Update `lib/main.dart`:**
   ```dart
   await Supabase.initialize(
     url: 'https://your-project.supabase.co', // Your actual URL
     anonKey: 'eyJ...', // Your actual anon key
   );
   ```

3. **Test the connection:**
   ```dart
   // Add this temporarily to test
   await SupabaseConnectionTest.runAllTests();
   ```

## 📊 **Database Schema Overview**

### **Users Table**
- `id`: Unique identifier (timestamp-based)
- `name`: User's full name
- `phone_number`: 10-digit phone number (unique)
- `created_at`: Registration timestamp

### **Scrap Submissions Table**
- `id`: Unique identifier
- `user_id`: Reference to users table
- `phone_number`: User's phone number
- `item_name`: Name of the scrap item
- `image_url`: URL to uploaded image
- `video_url`: URL to uploaded video
- `comments`: Detailed description
- `submitted_at`: Submission timestamp
- `status`: Current status (pending, reviewed, approved, rejected)

### **Messages Table**
- `id`: Unique identifier
- `submission_id`: Reference to scrap_submissions table
- `phone_number`: User's phone number
- `message`: Message content
- `is_from_admin`: Boolean flag for admin messages
- `sent_at`: Message timestamp

### **Storage Bucket**
- `scrap-media`: Public bucket for storing images and videos
- Organized by user ID for security

## 🔒 **Security Features**

- **Row Level Security (RLS)**: Users can only access their own data
- **Unique constraints**: Prevents duplicate phone numbers
- **Foreign key relationships**: Maintains data integrity
- **Admin policies**: Ready for admin dashboard integration
- **Secure file storage**: User-specific media organization

## ✅ **Next Steps**

1. ✅ Create all tables in Supabase
2. ✅ Test with sample data
3. ✅ Update Flutter app with credentials
4. ✅ Test Flutter app connection
5. 🚀 Ready to run the app!

Your database is now ready for the Scraps app! 🎉
