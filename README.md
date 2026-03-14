# Scraps - Scrap Collection App

A Flutter application for collecting and managing scrap materials like broken cars, engines, and other recyclable items.

## Features

### 🚀 Onboarding
- Beautiful 3-screen onboarding with storyboards
- Smooth page transitions with indicators
- Get Started button to begin registration

### 📱 User Registration
- Phone number validation (exactly 10 digits)
- Name validation (minimum 2 characters)
- Automatic user registration in Supabase
- Seamless navigation to dashboard

### 🏠 Dashboard
- Beautiful gradient design with user information
- Navigation drawer with user details
- Quick action cards for easy access
- Statistics display (submissions, earnings)
- Main "Sell Scrap" button

### 📝 Scrap Submission
- Item name input with validation
- Camera integration for photos
- Video recording capability
- Comments field for detailed descriptions
- Form validation and error handling
- Success confirmation dialog

### 📊 Reports & Messaging
- List of all user submissions with status
- Real-time message system with admin
- Message notifications and unread indicators
- Chat interface with message history
- Status tracking (pending, reviewed, approved, rejected)

## Tech Stack

- **Frontend**: Flutter
- **Backend**: Supabase
- **Database**: PostgreSQL
- **Storage**: Supabase Storage
- **Real-time**: Supabase Realtime

## Setup Instructions

### 1. Supabase Setup
1. Create a new Supabase project
2. Run the SQL schema from `SUPABASE_SCHEMA.sql` in your Supabase SQL Editor
3. Get your project URL and anon key from Supabase settings

### 2. Flutter Setup
1. Update `lib/main.dart` with your Supabase credentials:
   ```dart
   await Supabase.initialize(
     url: 'YOUR_SUPABASE_URL',
     anonKey: 'YOUR_SUPABASE_ANON_KEY',
   );
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

### 3. Play Store (Android)
- **Package name:** `com.greenhaul.scraps`.
- **Firebase:** Use the existing Android app in [Firebase Console](https://console.firebase.google.com) whose package name is `com.greenhaul.scraps`, and keep its `google-services.json` in `android/app/google-services.json`.
- **Build AAB:** `flutter build appbundle` → upload `build/app/outputs/bundle/release/app-release.aab` to Play Console.

### 4. Web deployment (Firebase Hosting)
1. Install [Firebase CLI](https://firebase.google.com/docs/cli) and sign in:
   ```bash
   npm install -g firebase-tools
   firebase login
   ```
2. Build the web app and deploy:
   ```bash
   flutter build web
   firebase deploy
   ```
   Your app will be live at `https://greenhaul-488aa.web.app` (and `https://greenhaul-488aa.firebaseapp.com`). The project uses the existing Firebase project **greenhaul-488aa**; config is in `firebase.json` and `.firebaserc`.

## Database Schema

### Users Table
- `id`: Unique identifier
- `name`: User's full name
- `phone_number`: 10-digit phone number (unique)
- `created_at`: Registration timestamp

### Scrap Submissions Table
- `id`: Unique identifier
- `user_id`: Reference to users table
- `phone_number`: User's phone number
- `item_name`: Name of the scrap item
- `image_url`: URL to uploaded image
- `video_url`: URL to uploaded video
- `comments`: Detailed description
- `submitted_at`: Submission timestamp
- `status`: Current status (pending, reviewed, approved, rejected)

### Messages Table
- `id`: Unique identifier
- `submission_id`: Reference to scrap_submissions table
- `phone_number`: User's phone number
- `message`: Message content
- `is_from_admin`: Boolean flag for admin messages
- `sent_at`: Message timestamp

## File Structure

```
lib/
├── main.dart                          # App entry point
├── models/                           # Data models
│   ├── user_model.dart
│   ├── scrap_submission_model.dart
│   └── message_model.dart
├── services/                         # API services
│   └── supabase_service.dart
└── screens/                          # UI screens
    ├── onboarding/
    │   ├── onboarding_screen.dart
    │   └── registration_screen.dart
    ├── dashboard/
    │   └── dashboard_screen.dart
    ├── scrap_submission/
    │   └── scrap_submission_screen.dart
    └── reports/
        ├── reports_screen.dart
        └── message_screen.dart
```

## Key Features Implementation

### Phone Number Validation
- Exactly 10 digits required
- Only numeric characters allowed
- Real-time validation feedback

### Image/Video Capture
- Camera integration using image_picker
- Image compression and optimization
- Video recording with duration limits
- File management and cleanup

### Real-time Messaging
- Supabase Realtime for instant updates
- Message threading by submission ID
- Admin and user message differentiation
- Unread message indicators

### Status Management
- Visual status indicators with colors
- Status-based UI updates
- Admin workflow integration

## Admin Dashboard Integration

The app is designed to work with an admin dashboard where:
- Admins can view all submissions
- Admins can update submission status
- Admins can send messages to users
- Real-time updates for both users and admins

## Security

- Row Level Security (RLS) enabled
- User data isolation
- Secure file upload policies
- Phone number-based authentication

## Future Enhancements

- Push notifications
- GPS location tracking
- Payment integration
- Advanced filtering and search
- Offline support
- Multi-language support

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License.