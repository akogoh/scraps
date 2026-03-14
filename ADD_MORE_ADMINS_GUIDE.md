# Adding More Admins to Scraps App

## Overview
The admin system is designed to support multiple administrators. Each admin has the same permissions and can manage all scrap submissions and messages.

## Current Admin System
- **Default Admin**: username: `admin`, password: `admin123`
- **Database Table**: `admins` with fields: id, username, email, password_hash, is_active, created_at, last_login
- **Permissions**: All admins can view/edit all submissions, send messages, and update statuses

## Adding New Admins

### Method 1: Using Supabase Dashboard (Recommended)

1. **Go to Supabase Dashboard** → Your Project → Table Editor
2. **Select the `admins` table**
3. **Click "Insert" → "Insert row"**
4. **Fill in the fields**:
   ```
   id: admin-002 (or any unique ID)
   username: newadmin
   email: newadmin@scraps.com
   password_hash: [See password hashing below]
   is_active: true
   created_at: [auto-generated]
   last_login: [leave null]
   ```

### Method 2: Using SQL Editor

1. **Go to Supabase Dashboard** → Your Project → SQL Editor
2. **Run this SQL** (replace the values):

```sql
-- Add a new admin
INSERT INTO admins (id, username, email, password_hash, is_active) 
VALUES (
    'admin-002',
    'newadmin',
    'newadmin@scraps.com',
    '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', -- Hashed 'admin123'
    TRUE
);
```

## Password Hashing

### For Default Password (admin123)
Use this pre-hashed value:
```
$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi
```

### For Custom Passwords
You need to hash the password using bcrypt. Here are some options:

#### Option 1: Online Bcrypt Generator
- Go to: https://bcrypt-generator.com/
- Enter your password
- Copy the generated hash

#### Option 2: Using Node.js
```javascript
const bcrypt = require('bcrypt');
const password = 'your_password_here';
const hash = bcrypt.hashSync(password, 10);
console.log(hash);
```

#### Option 3: Using Python
```python
import bcrypt
password = 'your_password_here'
hash = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())
print(hash.decode('utf-8'))
```

## Admin Management

### View All Admins
```sql
SELECT id, username, email, is_active, created_at, last_login 
FROM admins 
ORDER BY created_at DESC;
```

### Deactivate an Admin
```sql
UPDATE admins 
SET is_active = FALSE 
WHERE username = 'admin_to_deactivate';
```

### Reactivate an Admin
```sql
UPDATE admins 
SET is_active = TRUE 
WHERE username = 'admin_to_reactivate';
```

### Change Admin Password
```sql
UPDATE admins 
SET password_hash = 'new_hashed_password_here' 
WHERE username = 'admin_username';
```

### Delete an Admin (Use with caution)
```sql
DELETE FROM admins 
WHERE username = 'admin_to_delete';
```

## Admin Login Process

1. **Admin opens the app**
2. **Long press on the app logo** (in drawer or app bar)
3. **Enters username and password**
4. **System authenticates against `admins` table**
5. **If valid, admin gets access to admin dashboard**

## Security Considerations

### Password Security
- Use strong passwords (minimum 8 characters, mix of letters, numbers, symbols)
- Hash passwords using bcrypt with salt rounds ≥ 10
- Never store plain text passwords

### Admin Access Control
- All admins have the same permissions
- Admins can see all submissions and messages
- No role-based access control (RBAC) implemented yet

### Session Management
- Admin sessions are not persistent (logout on app restart)
- No session timeout implemented
- Admin login is required each time

## Troubleshooting

### Admin Can't Login
1. **Check if admin exists**:
   ```sql
   SELECT * FROM admins WHERE username = 'admin_username';
   ```

2. **Check if admin is active**:
   ```sql
   SELECT is_active FROM admins WHERE username = 'admin_username';
   ```

3. **Verify password hash** (compare with known good hash)

### Database Connection Issues
1. **Check Supabase connection** in `lib/main.dart`
2. **Verify API URL and anon key**
3. **Check RLS policies** (should be disabled for testing)

### Admin Service Errors
1. **Check `AdminService.loginAdmin()`** method
2. **Verify table structure** matches expected schema
3. **Check for foreign key constraints**

## Example: Adding Multiple Admins

```sql
-- Add multiple admins at once
INSERT INTO admins (id, username, email, password_hash, is_active) VALUES 
('admin-001', 'admin', 'admin@scraps.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', TRUE),
('admin-002', 'manager', 'manager@scraps.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', TRUE),
('admin-003', 'supervisor', 'supervisor@scraps.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', TRUE);
```

## Future Enhancements

### Role-Based Access Control (RBAC)
- **Super Admin**: Full access, can manage other admins
- **Admin**: Can manage submissions and messages
- **Moderator**: Can view and respond to messages only

### Admin Management Interface
- Add admin management screen in the app
- Allow super admins to add/remove other admins
- Password reset functionality
- Admin activity logging

### Enhanced Security
- Session timeout
- Two-factor authentication
- Admin activity audit trail
- IP-based access restrictions

## Testing Admin System

### Test Admin Login
1. **Long press app logo** in user dashboard
2. **Enter admin credentials**
3. **Verify access to admin dashboard**

### Test Admin Functions
1. **View all submissions**
2. **Update submission status**
3. **Send messages to users**
4. **View submission statistics**

### Test Multiple Admins
1. **Add second admin** using SQL
2. **Login with second admin**
3. **Verify same permissions and access**

## Support

If you encounter issues:
1. **Check the database** using Supabase dashboard
2. **Verify admin credentials** in the `admins` table
3. **Check app logs** for error messages
4. **Test with default admin** first (admin/admin123)

---

**Note**: The current system uses a simple authentication method. For production use, consider implementing more robust security measures like JWT tokens, session management, and proper password policies.
