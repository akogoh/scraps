# Where the submitter's phone number is saved

This traces how the submitter’s phone gets into **users** and **scrap_submissions** so "Registered number (submitter)" shows in the Payment Number dialog.

---

## 1. Registration / login → **users.phone_number**

| Step | File | What happens |
|------|------|----------------|
| User enters phone + OTP | `lib/screens/onboarding/registration_screen.dart` | `_phoneNumber` from `_phoneController.text` |
| New user | Same | `SupabaseService.createOrGetUser(name, _phoneNumber!)` |
| createOrGetUser | `lib/services/supabase_service.dart` | If user doesn’t exist: `users` insert with `user.toJson()` |
| User.toJson() | `lib/models/user_model.dart` | `'phone_number': phoneNumber` → **users.phone_number** is set |
| Existing user | registration_screen | `getUserByPhone(_phoneNumber!)` – no insert; user already has **users.phone_number** |
| Session saved | registration_screen | `SessionManager.saveUserSession(phoneNumber: user.phoneNumber, ...)` |

So after login, **users.phone_number** is set (new user) or already set (existing), and the app session has `user_phone` = that number.

---

## 2. Scrap submit → **scrap_submissions.phone_number**

| Step | File | What happens |
|------|------|----------------|
| Submit scrap | `lib/screens/scrap_submission/scrap_submission_screen.dart` | `sessionData = await SessionManager.getUserSession()` |
| Phone for submit | Same | `phoneNumber = sessionData['phone']` (from `user_phone`) |
| Guard | Same | `if (userId == null \|\| phoneNumber == null)` → "User session not found" and no submit |
| createScrapSubmission | `lib/services/supabase_service.dart` | Called with `phoneNumber: phoneNumber` |
| ScrapSubmission.toJson() | `lib/models/scrap_submission_model.dart` | `'phone_number': phoneNumber` in the insert payload |
| Insert | supabase_service | `scrap_submissions` insert → **scrap_submissions.phone_number** is set |

So for normal app flow, **scrap_submissions.phone_number** is set from the session phone when the user submits.

---

## 3. Field officer Payment dialog → where the number is read

| Step | Source | What is used |
|------|--------|--------------|
| Job list | `AdminService.getAssignedJobs()` | Reads from view **field_officer_jobs** |
| View | SQL `field_officer_jobs` | `COALESCE(s.phone_number, u.phone_number) as phone_number` |
| Detail screen | `widget.submission.phoneNumber` | From that view (or **admin_dashboard** when loading by ID) |
| Dialog | `admin_submission_detail_screen.dart` | "Registered number (submitter):" = `widget.submission.phoneNumber` |

So the dialog shows a number only if either **scrap_submissions.phone_number** or **users.phone_number** (for the submitter) is set.

---

## Why "Not provided" appears

- **Both** `scrap_submissions.phone_number` and `users.phone_number` are null for that submission.
- Common causes:
  - Submission created before app stored phone on submissions or user.
  - Submission (or user) created by another tool/API that didn’t set phone.
  - Session was never saved correctly (e.g. old build), so submit used a path that didn’t pass phone.

---

## Checklist for new submissions

1. **Registration**  
   - New user: `createOrGetUser(name, phone)` is called with the OTP phone → **users.phone_number** set.  
   - Existing user: already has **users.phone_number**; session is updated from `existingUser.phoneNumber`.

2. **Session**  
   - After login, `saveUserSession(phoneNumber: user.phoneNumber, ...)` is called so `user_phone` is set.

3. **Scrap submit**  
   - `getUserSession()` returns `phone`; if null, submit is blocked.  
   - `createScrapSubmission(..., phoneNumber: phoneNumber, ...)` is called → **scrap_submissions.phone_number** set.

4. **DB**  
   - View uses `COALESCE(s.phone_number, u.phone_number)`; at least one must be non-null for the dialog to show a number.

**Fallback added:** When creating a scrap submission, if the session phone is empty, the app now fetches the user by `userId` and uses **users.phone_number** so **scrap_submissions.phone_number** is still set when possible (`SupabaseService.createScrapSubmission` + `getUserById`).
