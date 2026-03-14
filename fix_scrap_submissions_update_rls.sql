-- Fix: Allow updates to scrap_submissions so both admins and field officers can reject/mark completed.
-- Run this in Supabase SQL Editor if you get "Failed to reject" or "Failed to update".
-- If your app uses the anon key and does NOT set app.current_admin_id, the "Admins can update"
-- policy will block all updates. This adds a permissive policy so updates work.

-- Option A: Add a policy that allows any authenticated or anon client to update (simplest)
DROP POLICY IF EXISTS "Allow public update for scrap submissions" ON scrap_submissions;
CREATE POLICY "Allow public update for scrap submissions" ON scrap_submissions
    FOR UPDATE
    USING (true)
    WITH CHECK (true);

-- If you had "Admins can update submissions" only, you can keep it and add the above;
-- then both policies apply (either can allow the update). If you want only one policy, drop the admin one:
-- DROP POLICY IF EXISTS "Admins can update submissions" ON scrap_submissions;
