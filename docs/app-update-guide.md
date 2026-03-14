# App Update (OTA) Guide

Instead of manually sharing APK files, the app checks Supabase for new versions and prompts users to update.

## 1. Run the SQL migration

In Supabase SQL Editor, run:

```sql
-- From create_app_versions_table.sql
```

## 2. Create storage bucket for APKs (optional)

If you'll host APKs on Supabase:

1. Go to Supabase Dashboard → Storage
2. Create bucket `app-releases` (set to **Public**)
3. Add policy: Allow public read
4. Upload your `app-release.apk`
5. Right-click file → Copy URL (public URL)

## 3. Releasing a new version

### Step A: Update app version

1. In **pubspec.yaml**: `version: 1.0.1+2`
2. In **lib/utils/app_version.dart**: set `appVersionName = '1.0.1'` and `appBuildNumber = 2`

Build the release APK:

```bash
flutter build apk
```

### Step B: Add version to Supabase

**Option 1: Upload APK to Supabase Storage**

1. Upload `build/app/outputs/flutter-apk/app-release.apk` to `app-releases` bucket
2. Rename to e.g. `scraps-1.0.1.apk`
3. Get the public URL

**Option 2: Host APK elsewhere**

Upload to your own server, Google Drive (shareable link), or any public URL.

### Step C: Insert into app_versions table

```sql
INSERT INTO app_versions (version_name, build_number, download_url, release_notes)
VALUES (
  '1.0.1',
  2,
  'https://your-url-to-the.apk',  -- Replace with actual URL
  'Bug fixes and performance improvements'
);
```

### Force update (optional)

To make the update mandatory (user can't skip):

```sql
INSERT INTO app_versions (version_name, build_number, download_url, force_update, release_notes)
VALUES ('1.0.1', 2, 'https://...', true, 'Critical security update');
```

## 4. Flow

- **Splash screen** → Checks for update
- **New version?** → Shows dialog with "Update" and "Later" (or only "Update" if force)
- **Tap Update** → Opens download URL in browser (user downloads & installs APK)
- **Tap Later** → Continues to app (unless force_update)

## 5. Alternative: Google Play Store

When you publish on Play Store, change `download_url` to your Play Store link:

```
https://play.google.com/store/apps/details?id=com.your.app
```

The app will open Play Store when user taps Update.
