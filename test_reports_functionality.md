# Reports Functionality Test Plan

## ✅ What Should Work:
1. **Reports Screen Loads** - Shows user's scrap submissions
2. **Location Display** - Shows GPS coordinates and address
3. **Message Notifications** - Red dots for unread admin messages
4. **Message Screen** - Can view and reply to messages
5. **Status Display** - Shows submission status (pending, reviewed, etc.)

## 🔧 Current Issues to Fix:
1. **getUserSubmissions** - Fixed to use phone_number instead of user_id
2. **Message Column Names** - Need to verify sent_at vs created_at
3. **Unread Messages** - Need to check is_from_admin vs is_admin_message

## 🧪 Test Steps:
1. Submit a scrap with location
2. Go to Reports page
3. Check if submission appears with location
4. Test message functionality
5. Verify notifications work

## 📋 Database Schema Check:
- scrap_submissions: id, user_id, phone_number, item_name, image_url, video_url, comments, submitted_at, status, latitude, longitude, address
- messages: id, submission_id, sender_id, content, is_admin_message, is_read, created_at
