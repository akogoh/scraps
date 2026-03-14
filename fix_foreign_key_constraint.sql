-- Fix Foreign Key Constraint for Admin Messages
-- Run this in Supabase SQL Editor

-- 1. First, let's check the current foreign key constraints
SELECT 
    tc.constraint_name, 
    tc.table_name, 
    kcu.column_name, 
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name 
FROM 
    information_schema.table_constraints AS tc 
    JOIN information_schema.key_column_usage AS kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    JOIN information_schema.constraint_column_usage AS ccu
      ON ccu.constraint_name = tc.constraint_name
      AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
AND tc.table_name='messages';

-- 2. Drop the existing foreign key constraint
ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_sender_id_fkey;

-- 3. Create a new constraint that allows both users and admins
-- We'll make it more flexible by not enforcing the foreign key for now
-- Or we can create a union approach

-- 4. Alternative: Create a function to check if sender exists in either users or admins
CREATE OR REPLACE FUNCTION check_sender_exists(sender_id TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM users WHERE id = sender_id
    ) OR EXISTS (
        SELECT 1 FROM admins WHERE id = sender_id
    );
END;
$$ LANGUAGE plpgsql;

-- 5. Add a check constraint instead of foreign key
ALTER TABLE messages 
ADD CONSTRAINT check_sender_exists_constraint 
CHECK (check_sender_exists(sender_id));

-- 6. Verify the fix
SELECT 'Foreign key constraint fixed!' as status;
