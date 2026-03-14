# Announcements / Broadcast Feature

## Overview

Announcements allow you to broadcast special deals, updates, or notices to all app users. Created from the web dashboard, they appear in the app with a notification icon and optional popup.

## Database Setup

Run the SQL migration in Supabase SQL Editor:

```sql
-- From create_announcements_table.sql
```

## Web Dashboard: Creating Announcements

Insert announcements from Supabase SQL Editor or build a web UI that uses the Supabase client with **service role key** (bypasses RLS):

```sql
-- Example: Special deal (shows as popup - priority >= 10)
INSERT INTO announcements (title, body, type, priority, is_active, image_url, link_url) 
VALUES (
  'Limited Time Offer',
  'Get 25% extra on copper and aluminum this month!',
  'deal',
  10,
  true,
  NULL,
  'https://yoursite.com/offers'
);

-- Example: General announcement (no popup)
INSERT INTO announcements (title, body, type, priority, is_active) 
VALUES (
  'Service Update',
  'We now offer pickup in 3 new areas. Check our coverage map.',
  'announcement',
  0,
  true
);
```

### Fields

| Column       | Type    | Description                                                  |
|-------------|---------|--------------------------------------------------------------|
| title       | TEXT    | Short headline                                               |
| body        | TEXT    | Full message                                                 |
| type        | TEXT    | `announcement`, `deal`, `info`, `urgent`                     |
| image_url   | TEXT    | Optional image URL                                          |
| link_url    | TEXT    | Optional "Learn more" link                                  |
| priority    | INTEGER | 0 = normal; 10+ = shows popup on app launch (once per announcement) |
| is_active   | BOOLEAN | If false, hidden from app                                   |
| expires_at  | TIMESTAMPTZ | Optional expiry date                                    |

## App Behavior

1. **Notification bell** – Top-right of Home and Reports; shows orange badge with unread count
2. **Tap bell** – Opens full announcements list; marks all as read and clears badge
3. **Drawer** – "Announcements" menu item
4. **Popup** – Announcements with `priority >= 10` show a dialog on first dashboard visit (once per announcement)

## Types & Styling

- **deal** – Green accent, special offer styling
- **urgent** – Orange accent, prominent border
- **info** – Blue accent
- **announcement** – Default grey
