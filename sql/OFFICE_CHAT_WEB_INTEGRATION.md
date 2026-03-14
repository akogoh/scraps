# Office chat: same for web app and mobile (field officer)

So that **field officers on the mobile app** and **admins/officers on the web app** see the **same** office chat, both must use the same Supabase table and rules below.

## Table: `office_messages`

| Column          | Type    | Notes |
|-----------------|---------|--------|
| id              | UUID    | PK, default gen_random_uuid() |
| sender_id       | TEXT    | Admin id (from `admins.id`) or field officer id (from `field_officers.id`) |
| sender_type     | TEXT    | `'admin'` or `'field_officer'` |
| recipient_id    | TEXT    | Same as above |
| recipient_type  | TEXT    | `'admin'` or `'field_officer'` |
| content         | TEXT    | Message text (use `'[Image]'` if only image_url) |
| image_url       | TEXT    | Optional |
| is_read         | BOOLEAN | Default false |
| created_at      | TIMESTAMPTZ | Default now() |

- IDs must match: **admins.id** and **field_officers.id** (UUIDs as text are fine).

## Web app: how to use it

1. **List conversations (inbox)**  
   For current user `(myId, myType)` where `myType` is `'admin'` or `'field_officer'`:
   - Query `office_messages` where  
     `(sender_id = myId AND sender_type = myType) OR (recipient_id = myId AND recipient_type = myType)`  
   - Order by `created_at DESC`.  
   - For each distinct other participant `(other_id, other_type)`, take the latest message as the “thread” row.  
   - Resolve names: `other_type = 'admin'` → `admins.username` by `admins.id = other_id`; `other_type = 'field_officer'` → `field_officers.name` by `field_officers.id = other_id`.

2. **Open a thread (messages with one person)**  
   Between `(myId, myType)` and `(otherId, otherType)`:
   - Query `office_messages` where  
     `(sender_id = myId AND recipient_id = otherId AND sender_type = myType AND recipient_type = otherType) OR (sender_id = otherId AND recipient_id = myId AND sender_type = otherType AND recipient_type = myType)`  
   - Order by `created_at ASC`.

3. **Send a message**  
   Insert one row:
   - `sender_id` = current user id (admin or field_officer id)
   - `sender_type` = `'admin'` or `'field_officer'`
   - `recipient_id` = other person id
   - `recipient_type` = other person type
   - `content` = text (or `'[Image]'` if only image)
   - `image_url` = optional
   - `is_read` = false
   - `created_at` = now (or default)

## Result

- **Web:** Admins and officers use the same `office_messages` with the rules above.  
- **Mobile:** Field officer uses the same table via the app (Office chat → pick person → send).  
- Everyone sees the **same** conversations: field officer on mobile chats with “web app people” (admins/officers) in one shared office chat.

Run `sql/create_office_messages_table.sql` in Supabase if the table does not exist yet.
