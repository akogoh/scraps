-- Create storage bucket for scrap media (images and videos)
INSERT INTO storage.buckets (id, name, public) 
VALUES ('scrap-media', 'scrap-media', true);

-- Create storage policies for the scrap-media bucket

-- Users can upload their own media
CREATE POLICY "Users can upload own media" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'scrap-media' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

-- Users can view their own media
CREATE POLICY "Users can view own media" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'scrap-media' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

-- Public can view media (for displaying in app)
CREATE POLICY "Public can view media" ON storage.objects
    FOR SELECT USING (bucket_id = 'scrap-media');

-- Users can delete their own media
CREATE POLICY "Users can delete own media" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'scrap-media' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

-- Admins can manage all media
CREATE POLICY "Admins can manage all media" ON storage.objects
    FOR ALL USING (
        bucket_id = 'scrap-media' AND
        current_setting('app.is_admin', true) = 'true'
    );
