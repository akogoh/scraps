# 🔧 Admin System Setup Guide

## 📋 Overview

The admin system allows administrators to:
- View all scrap submissions
- Update submission status (pending, reviewed, approved, rejected)
- Send messages to users
- View submission statistics
- Search and filter submissions

## 🗄️ Database Setup

### 1. Run the Admin SQL Script
Execute the `create_admin_system.sql` file in your Supabase SQL Editor:

```sql
-- This will create:
-- - admins table
-- - Updated messages table structure
-- - Admin dashboard view
-- - RLS policies for admin access
-- - Default admin user
```

### 2. Default Admin Credentials
- **Username**: `admin`
- **Password**: `admin123`
- **Email**: `admin@scraps.com`

## 🚀 Admin Access

### Method 1: Hidden Access (Recommended)
1. Open the main app
2. Go to Dashboard
3. Open the drawer (hamburger menu)
4. **Long press** on the user profile image
5. Admin portal will open

### Method 2: Direct Access
Navigate directly to `AdminMainScreen` in your app.

## 📱 Admin Features

### 1. **Admin Dashboard**
- View submission statistics
- Quick actions to view submissions and messages
- Recent submissions overview

### 2. **Submission Management**
- View all submissions with filtering
- Search by item name, user name, or phone number
- Filter by status (pending, reviewed, approved, rejected)
- View detailed submission information

### 3. **Status Updates**
- Update submission status
- Add admin notes
- Track who reviewed and when

### 4. **Messaging System**
- Send messages to users about their submissions
- View conversation history
- Real-time message updates

### 5. **Location Information**
- View GPS coordinates of submissions
- Display formatted addresses
- Location-based filtering

## 🔐 Security Features

### Row Level Security (RLS)
- Admins can only access data they're authorized to see
- Proper user isolation
- Secure message handling

### Admin Authentication
- Username/password based login
- Session management
- Secure admin operations

## 📊 Database Views

### Admin Dashboard View
```sql
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
```

## 🛠️ Admin Workflow

### 1. **Reviewing Submissions**
1. Login to admin portal
2. Go to "View All Submissions"
3. Click on a submission to view details
4. Update status and add notes
5. Send message to user if needed

### 2. **Managing Messages**
1. Go to "Messages" section
2. View all conversations
3. Click on a conversation to reply
4. Send messages to users

### 3. **Status Management**
- **Pending**: New submissions awaiting review
- **Reviewed**: Submissions under review
- **Approved**: Accepted submissions
- **Rejected**: Declined submissions

## 📱 User Experience

### For Users:
- Users can see status updates in their reports
- Receive messages from admins
- View admin responses in real-time

### For Admins:
- Comprehensive dashboard with statistics
- Easy submission management
- Efficient messaging system
- Search and filter capabilities

## 🔧 Customization

### Adding New Admin Users
```sql
INSERT INTO admins (id, username, email, password_hash, is_active) 
VALUES (
    'admin-002',
    'newadmin',
    'newadmin@scraps.com',
    '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi',
    TRUE
);
```

### Custom Status Values
Update the status check constraint:
```sql
ALTER TABLE scrap_submissions 
DROP CONSTRAINT IF EXISTS scrap_submissions_status_check;

ALTER TABLE scrap_submissions 
ADD CONSTRAINT scrap_submissions_status_check 
CHECK (status IN ('pending', 'reviewed', 'approved', 'rejected', 'custom_status'));
```

## 🐛 Troubleshooting

### Common Issues:

1. **Admin Login Fails**
   - Check if admin user exists in database
   - Verify password hash is correct
   - Ensure RLS policies are properly set

2. **Cannot View Submissions**
   - Check RLS policies for admin access
   - Verify admin user is active
   - Check database permissions

3. **Messages Not Sending**
   - Verify message table structure
   - Check sender_id is correct
   - Ensure proper admin authentication

### Debug Steps:
1. Check Supabase logs for errors
2. Verify database schema matches code
3. Test RLS policies
4. Check admin user permissions

## 📈 Analytics

### Available Statistics:
- Total submissions
- Pending submissions
- Reviewed submissions
- Approved submissions
- Rejected submissions
- Message counts per submission

### Custom Queries:
```sql
-- Get submissions by date range
SELECT * FROM admin_dashboard 
WHERE submitted_at BETWEEN '2024-01-01' AND '2024-12-31';

-- Get most active users
SELECT user_name, phone_number, COUNT(*) as submission_count
FROM admin_dashboard 
GROUP BY user_name, phone_number 
ORDER BY submission_count DESC;
```

## 🚀 Production Considerations

### Security:
- Change default admin password
- Use strong password hashing
- Implement proper authentication
- Regular security audits

### Performance:
- Add database indexes
- Optimize queries
- Implement caching
- Monitor database performance

### Monitoring:
- Track admin activities
- Monitor system performance
- Set up alerts for critical issues
- Regular backup procedures

---

**Need Help?** Check the console output for specific error messages and refer to the Supabase documentation for database-related issues.
