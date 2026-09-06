# Deep Pulse News — Play Store Submission Checklist

App ID: `media.deeppulse.news`  
Current version: `1.0.0+1`  
Firebase project: `deeppulse-38f3a`

---

## 🔴 BLOCKERS — Must fix before building release

### 1. Package name mismatch in Firebase (CRITICAL)

**Problem:** `android/app/google-services.json` still has `com.example.deep_pulse_news` as the package name, but `build.gradle.kts` correctly uses `media.deeppulse.news`. In a release build, Firebase will reject the app — Google Sign-In will fail and FCM won't initialize.

**Fix:**
1. Go to [Firebase Console](https://console.firebase.google.com) → Project `deeppulse-38f3a` → Project Settings → Your apps
2. Delete the old Android app (`com.example.deep_pulse_news`)
3. Add a new Android app with package name `media.deeppulse.news`
4. Download the new `google-services.json` and replace `android/app/google-services.json`

---

### 2. Release signing — generate keystore (client's details)

No keystore exists yet. The release build currently signs with debug keys (see `build.gradle.kts` line: `signingConfig = signingConfigs.getByName("debug")`). You cannot upload a debug-signed APK/AAB to Play Store.

**Step A — Generate keystore** (run once, keep the file safe forever)

Open Command Prompt as Administrator and run:

```
"C:\Program Files\Java\jdk-17\bin\keytool.exe" -genkey -v -keystore deep_pulse_news.jks -keyalg RSA -keysize 2048 -validity 10000 -alias deep_pulse_news
```

When prompted, enter the **client's details** (these are permanent — they identify who owns the app on Play Store):

| Prompt | What to enter |
|---|---|
| Keystore password | Strong password (save it — you need it forever) |
| Key password | Same or different strong password |
| First and last name | Client's full name or organization name |
| Organizational unit | e.g. `Media` or leave blank |
| Organization | e.g. `Deep Pulse Media` |
| City | Client's city |
| State | Client's state (e.g. `Telangana`) |
| Country code | `IN` |

> ⚠️ Save `deep_pulse_news.jks` somewhere safe — if you lose it you can NEVER update the app on Play Store.  
> Move it to a secure location (NOT inside the project folder, NOT committed to Git).

**Step B — Create `android/key.properties`**

Create this file (it's already in `.gitignore` — never commit it):

```
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=deep_pulse_news
storeFile=/full/path/to/deep_pulse_news.jks
```

Use forward slashes even on Windows, e.g.:  
`storeFile=C:/Users/YourName/keys/deep_pulse_news.jks`

**Step C — Wire signing into `android/app/build.gradle.kts`**

Replace the current `android { }` block with:

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = java.util.Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(keyPropertiesFile.inputStream())
}

android {
    namespace = "media.deeppulse.news"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    signingConfigs {
        create("release") {
            keyAlias = keyProperties["keyAlias"] as String
            keyPassword = keyProperties["keyPassword"] as String
            storeFile = file(keyProperties["storeFile"] as String)
            storePassword = keyProperties["storePassword"] as String
        }
    }

    defaultConfig {
        applicationId = "media.deeppulse.news"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

---

### 3. Add release SHA-1 to Firebase

After generating the keystore, get the SHA-1 fingerprint:

```
"C:\Program Files\Java\jdk-17\bin\keytool.exe" -list -v -keystore deep_pulse_news.jks -alias deep_pulse_news
```

Copy the `SHA1:` value, then:
1. Firebase Console → Project `deeppulse-38f3a` → Project Settings → Your apps → Android app (`media.deeppulse.news`)
2. Click **Add fingerprint** → paste the SHA-1 → Save

> Without this, Google Sign-In will return error 10 in the release build.

---

### 4. Fix `WRITE_EXTERNAL_STORAGE` permission warning

In `AndroidManifest.xml`, the `WRITE_EXTERNAL_STORAGE` permission triggers a Play Store warning for Android 13+ users. Add a max SDK version so it only applies on older devices:

```xml
<uses-permission
    android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="28" />
<uses-permission
    android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />
```

---

## 🟡 Required for Play Store listing

### 5. App version bump

Currently `1.0.0+1` in `pubspec.yaml`. This is fine for a first release. For future updates you must increment the build number (`+2`, `+3`, etc.) — Play Store rejects a lower or equal build number.

Build command:
```
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

---

### 6. Privacy policy (MANDATORY)

Google requires a privacy policy URL for any app that:
- Uses location (✅ your app does — mandal/district selection)
- Uses camera (✅ your app does — media upload)
- Uses Google Sign-In (✅ your app does)
- Sends push notifications (✅ your app does)

The client **must** publish a privacy policy at a public URL (e.g. `https://deeppulse.media/privacy-policy`).

It must cover:
- What data is collected (location, photos/videos, name, email)
- How it is stored and used
- Third-party services used (Firebase, Google Sign-In)
- How users can delete their account/data

---

### 7. Play Store listing assets (prepare these)

| Asset | Size | Notes |
|---|---|---|
| App icon | 512 × 512 PNG | No alpha/transparency. Your current purple icon — export at 512px |
| Feature graphic | 1024 × 500 PNG/JPG | Banner shown at top of store listing — design needed |
| Phone screenshots | Min 2, max 8 — 16:9 or 9:16 | Take from a real device in release mode |
| Short description | Max 80 characters | e.g. "Local news from your district, state & beyond" |
| Full description | Max 4000 characters | Explain features: local news, videos, notifications, multi-language |

---

### 8. Play Console account setup

1. Go to [play.google.com/console](https://play.google.com/console)
2. Register with the **client's Google account** (one-time $25 fee)
3. Create new app → set name "Deep Pulse News" → Telugu/English
4. Complete all dashboard sections: Store listing, Content rating, Target audience, App access, Data safety

---

### 9. Data safety form (mandatory since 2022)

Play Store requires you to declare what data your app collects. For Deep Pulse News:

| Data type | Collected? | Shared? | Purpose |
|---|---|---|---|
| Name | Yes | No | Account display |
| Email address | Yes | No | Authentication |
| Phone number | Yes | No | OTP login |
| Precise location | No | No | User picks manually |
| Coarse location | No | No | — |
| Photos/videos | Yes | No | News media upload |
| Device identifiers (FCM token) | Yes | No | Push notifications |

---

## 🟢 Already done / looks good

- ✅ Application ID is `media.deeppulse.news` (not the default `com.example.*`)
- ✅ App name in manifest: `Deep Pulse News`
- ✅ Adaptive launcher icon configured with purple brand color (#2D1B69)
- ✅ ProGuard rules cover Flutter, Google Sign-In, smart_auth, Play Core
- ✅ `isMinifyEnabled = true` and `isShrinkResources = true` for release
- ✅ FCM background handler registered with `@pragma('vm:entry-point')`
- ✅ `multiDexEnabled = true` (required for flutter_local_notifications)
- ✅ Core library desugaring enabled (required for flutter_local_notifications on Android < 26)
- ✅ `android:label` and `android:icon` set correctly
- ✅ `.gitignore` already excludes `key.properties` and `*.jks` / `*.keystore`

---

## Build & upload steps (after all above are done)

```bash
# 1. Clean old build artifacts
flutter clean
flutter pub get

# 2. Build release AAB
flutter build appbundle --release

# 3. The file to upload to Play Store:
# build/app/outputs/bundle/release/app-release.aab
```

Upload path in Play Console: **Release → Production → Create new release → Upload AAB**

---

## Keep safe forever

| Item | Why |
|---|---|
| `deep_pulse_news.jks` keystore file | Needed for every future update — lose it = can never update |
| Keystore password + key password | Same reason |
| `key.properties` (locally, not in Git) | Contains the passwords |
| Play Console login (client's Google account) | Access to the developer account |
| Firebase project access | For FCM, Google Sign-In, crash reporting |
