# Push Notifications — Frontend (Flutter)

> Companion doc for backend: `PUSH_NOTIFICATIONS_BACKEND.md`

---

## 1. Important rule for our app

Login is **optional** in our app. So we send push notifications to the **device**, not the user.

- Every install gets a `device_id` (a UUID we generate once, stored locally, never changes).
- Backend stores tokens against `device_id`.
- When user logs in → we tell backend to link the device to that user.
- When user logs out → we tell backend to unlink, but **device keeps getting pushes** based on selected location.

---

## 2. What we have now

| Item | Status |
|------|--------|
| Firebase project `deep-pulse-news` exists | ✅ |
| `android/app/google-services.json` | ✅ |
| Google Sign-In already using Firebase | ✅ |
| `firebase_core` package | ❌ not added |
| `firebase_messaging` package | ❌ not added |
| `firebase_options.dart` file | ❌ not generated |
| iOS `GoogleService-Info.plist` | ❌ missing |
| iOS push capability in Xcode | ❌ not added |
| `Firebase.initializeApp()` in main.dart | ❌ missing |
| Any notification handling code | ❌ none |

So Firebase is set up for sign-in only. **Messaging is not wired up at all.**

---

## 3. What we have to do (in order)

### Step 1 — Add packages
Add to `pubspec.yaml`:
```yaml
firebase_core: ^3.6.0
firebase_messaging: ^15.1.3
flutter_local_notifications: ^17.2.3
uuid: ^4.5.1
```
Then run `flutter pub get`.

### Step 2 — Run FlutterFire CLI (one-time)
```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=deep-pulse-news
```
This auto-creates `firebase_options.dart` and the iOS plist file.

### Step 3 — Initialize Firebase in `main.dart`
Add `await Firebase.initializeApp(...)` before `runApp(...)`.

### Step 4 — iOS setup (Xcode)
- Add **Push Notifications** capability.
- Add **Background Modes** → tick *Remote notifications*.
- Upload APNs key to Firebase Console (needs Apple Developer account).

### Step 5 — Create `lib/core/services/push_notification_service.dart`
This service does five things:
1. Generate / read the `device_id` from SharedPreferences.
2. Get the FCM token from Firebase.
3. Send `device_id + fcm_token + selected locations` to backend (`POST /api/device-tokens`).
4. Listen for token refresh and re-send.
5. Handle notification taps → read `data.deeplink` → navigate.

### Step 6 — Call the service after splash
Inside splash screen or right after `Firebase.initializeApp`, call `PushNotificationService().init()`.

### Step 7 — Hook into login/logout
- After login → call `POST /api/device-tokens/link` (backend ties device to user).
- On logout → call `POST /api/device-tokens/unlink` (clears user, keeps device).
- **Don't delete the local `device_id` ever.**

### Step 8 — Hook into location changes
Whenever user changes State / District / Mandal, call `POST /api/device-tokens` again so backend knows the new locations.

### Step 9 — Add deep-link routes in `app_router.dart`

The backend sends different deep-links based on who you are (reader / editor / admin):

| Deeplink | Goes to | Who receives this |
|----------|---------|-------------------|
| `deeppulse://news/{id}` | News detail screen | Readers (when news is published) |
| `deeppulse://news/{id}` | Same — news detail | Reporter (when their news is approved) |
| `deeppulse://comments/{news_id}` | Comments screen | News uploader / comment author |
| `deeppulse://admin/review/{news_id}` | Editor review screen | `subadmin` / `dist-reporter` (when reporter uploads) |
| `deeppulse://admin/news/{news_id}` | Admin overview screen | `admin` (when news is published) |
| `deeppulse://announcements` | Announcement detail | All users |

### Step 10 — Rework the notifications screen
The current `lib/features/notifications/notifications_view_model.dart` actually shows **admin pending news**, not push notifications. Either:
- Rename it to `pending_news_review` (admin), and
- Build a new `notifications_screen` that calls `GET /api/notifications`.

For anonymous users → show "Login to see your notifications" placeholder (decision: see §6).

---

## 4. What backend will send us (so we can plan UI)

When a push arrives, our app receives:

**`message.notification`** (auto-shown by OS):
```json
{ "title": "...", "body": "...", "image": "https://..." }
```

**`message.data`** (we read this for routing — all values are strings):
```json
{
  "type":        "news_published",
  "entity_id":   "1234",
  "entity_type": "news",
  "deeplink":    "deeppulse://news/1234",
  "image_url":   "https://..."
}
```

`type` will be one of: `news_published`, `news_approved`, `news_rejected`, `comment_on_news`, `comment_reply`, `admin_announcement`, `test`.

---

## 5. What we send to backend

### Register device (no login needed)
`POST /api/device-tokens`
```json
{
  "device_id":    "550e8400-e29b-41d4-a716-446655440000",
  "fcm_token":    "fGx...",
  "platform":     "android",
  "app_version":  "1.0.0+1",
  "state_ids":    [4, 7],
  "district_ids": [22, 31],
  "mandal_ids":   [101, 102]
}
```

### Link to user after login
`POST /api/device-tokens/link` with `{ "device_id": "..." }` and the auth header.

### Unlink on logout
`POST /api/device-tokens/unlink` with `{ "device_id": "..." }`.

### Get inbox (logged-in users)
`GET /api/notifications?page=1&per_page=20` → returns the list to show in the notifications screen.

---

## 6. Decisions we need to make

1. **Production app ID** — currently `com.example.deep_pulse_news`. Change before going live (will need new `google-services.json`).
2. **Apple Developer account** — needed for iOS push. Without it, iOS users get nothing.
3. **Anonymous inbox** — show "Login to see notifications" placeholder, or build it for anonymous too? (Simple option recommended.)

---

## 7. Where to start NOW (priority order)

Do these 6 first — they unblock everything and let backend test against a real device:

1. **Add packages** to `pubspec.yaml` and run `flutter pub get`.
2. **Run `flutterfire configure --project=deep-pulse-news`** — this is the single command that fixes most missing files (creates `firebase_options.dart`, downloads iOS plist, registers iOS app).
3. **Initialize Firebase** in `lib/main.dart` (one line: `await Firebase.initializeApp(...)`).
4. **Create `PushNotificationService`** with just these methods to start:
   - `getDeviceId()` — generate UUID once, save in SharedPreferences.
   - `init()` — request permission, get FCM token, call `registerWithBackend()`.
   - `registerWithBackend()` — POST to `/api/device-tokens`.
5. **Call `PushNotificationService().init()` after splash** so registration happens on every app open.
6. **Test:** install the app, open it, check that the backend received the token. Use a tool like Postman or backend logs to confirm.

Once this works, you have the **foundation**. Backend can then send a test push to your token using their `sendToDevice` method to verify end-to-end delivery — no other backend work needed yet.

After foundation:
7. iOS push capability + APNs key in Apple Developer (only blocks iOS users, not Android).
8. Login → link, logout → unlink.
9. Re-register on location change.
10. Deep-link routing.
11. Rework notifications screen.

## 8. Quick checklist

- [ ] Add 4 packages
- [ ] Run `flutterfire configure`
- [ ] iOS: add push capability + APNs key
- [ ] Init Firebase in `main.dart`
- [ ] Create `PushNotificationService`
- [ ] Call `init()` after splash
- [ ] Wire login → link, logout → unlink
- [ ] Re-register on location change
- [ ] Add deep-link routes (including admin/review and admin/news)
- [ ] Rework notifications screen
