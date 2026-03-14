# WhatsApp-style push notifications (FCM)

Users and field officers get **status bar notifications** (like WhatsApp) when:
- **User:** A message is sent to them by the team (admin/officer).
- **Field officer:** They are assigned a new job.

## 1. Firebase project

1. Go to [Firebase Console](https://console.firebase.google.com/) and create or select a project.
2. Add an **Android app** with package name: `com.example.scraps` (or your `applicationId` from `android/app/build.gradle`).
3. Download **google-services.json** and put it in `android/app/google-services.json`.
4. Get **Firebase options** for Flutter:
   - Run: `dart run flutterfire_cli:flutterfire configure`  
     (install with `dart pub global activate flutterfire_cli` if needed)  
   - This overwrites `lib/firebase_options.dart` with your project values.
   - Or copy `apiKey`, `appId`, `messagingSenderId`, `projectId`, `storageBucket` from Firebase Console → Project settings → Your apps → Android into `lib/firebase_options.dart`.

## 2. Supabase: FCM tokens table

Run in Supabase SQL Editor:

```bash
# From project root, the SQL file is at:
sql/create_fcm_tokens_table.sql
```

Paste and run its contents so the `fcm_tokens` table and RLS exist.

## 3. Supabase Edge Function (send FCM)

1. **Install Supabase CLI** (if needed):  
   https://supabase.com/docs/guides/cli

2. **Login and link project:**
   ```bash
   npx supabase login
   npx supabase link --project-ref YOUR_PROJECT_REF
   ```

3. **Set secrets** (Firebase service account for FCM):
   - Firebase Console → Project settings → Service accounts → Generate new private key.  
     Download the JSON file.
   - Set Edge Function secrets:
     ```bash
     npx supabase secrets set FIREBASE_PROJECT_ID=your-firebase-project-id
     npx supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON="$(cat path/to/service-account.json)"
     ```
     (Use the project ID from the JSON and the **entire** JSON as the second value.)

4. **Deploy the function:**
   ```bash
   npx supabase functions deploy send-push
   ```

5. **Database Webhooks** (Supabase Dashboard → Database → Webhooks):
   - **Webhook 1 – new message to user**
     - Table: `messages`
     - Events: Insert
     - Type: HTTP Request
     - URL: `https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-push`
     - HTTP method: POST
     - (Optional) Add header: `Authorization: Bearer YOUR_ANON_OR_SERVICE_ROLE_KEY` if your function checks it.
   - **Webhook 2 – job assigned to officer**
     - Table: `scrap_submissions`
     - Events: Update
     - URL: same `.../functions/v1/send-push`
     - Method: POST

The Edge Function reads the webhook payload and sends FCM to the right device(s) using `fcm_tokens`.

## 4. App side

- **Android:** Already added: `firebase_core`, `firebase_messaging`, `google-services` plugin, `POST_NOTIFICATIONS`, and FCM channel.
- **Token registration:** When a user opens the dashboard or a field officer opens the admin dashboard, the app registers the FCM token to `fcm_tokens` (user_id or field_officer_id).

## 5. Testing

1. Install the app and log in as a **user**. Open the dashboard (token is registered).
2. From admin/web, send a message to that user’s submission.  
   → User should get a **status bar** notification: “New message” / “Message from team”.
3. Log in as a **field officer**, open the dashboard (token is registered).
4. From admin, assign a job to that officer.  
   → Officer should get a notification: “Job assigned” / “You have been assigned a new job”.

If notifications don’t appear, check:
- Firebase: Cloud Messaging is enabled; google-services.json and `firebase_options.dart` match the same project.
- Supabase: `fcm_tokens` has a row for that user/officer; Edge Function logs for `send-push`; webhooks are enabled and point to the correct URL.
