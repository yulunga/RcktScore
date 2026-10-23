# Android Workspace

Native Android app for HitNScore. It is a separate Gradle project beside
`mobile/ios/`; it does not alter or wrap the iOS workspace.

## Current Status (M2 read-only screens, October 2026)

In place:

- one Android application module: Kotlin, Jetpack Compose, Material 3
- `dev`, `staging` and `prod` build flavours, each with its own API address,
  app name and application ID suffix
- brand splash screen (held until the stored session is read), adaptive and
  themed (monochrome) launcher icon made from the iOS brand artwork
- **sign-in against the v2 backend** as the `mobile_app` client, like iOS:
  identity-first memberships, the legacy organisation chooser, the
  "already signed in on another device" question with force sign-out, and
  password-reset requests
- **session** kept AES-256-GCM encrypted with an Android Keystore key, checked
  against the server expiry on launch and on return to the app, and cleared
  when the backend reports `SESSION_EXPIRED`, `SESSION_REPLACED`,
  `SESSION_INVALID` or `SESSION_REQUIRED`
- optional **quick unlock** (fingerprint, face or screen lock, Android 9+),
  turned on in Settings; re-locks after 5 minutes in the background, as iOS
- account-context switching between the user's real memberships, persisted
- one `Scaffold` and bottom bar for the signed-in session, with the five iOS
  tabs and the iOS brand header (logo, wordmark, notifications bell or offline
  indicator, account-context switcher)
- **Home**: up to three active, scheduled (clubs) and recent matches, with
  pull-to-refresh and loading placeholders
- **Matches**: Current / Scheduled / History; History has search, sport filter
  and date-range filter, and shows Personal Free locked-history cards
- **match view** (read-only): result card, Match Information, Match Time with
  per-game durations, and the point timeline for squash/racketball and
  tennis/Padel
- **notifications** inbox with read state shared with iOS
- **Analytics**: Personal Plus performance report, basic stats otherwise
- **Settings** (read-only): About, Profile, Subscription, Association, Racket
  Sports, and for club admins Organisation, Users and Courts; quick unlock;
  sign out
- switching account context clears every screen before loading the new
  organisation, so data from one account never appears under another
- API layer: `{ success, data, error, meta }` envelope, bearer-token
  interceptor, typed errors, OkHttp + kotlinx.serialization
- release hardening: R8, optional upload-key signing, CI version codes,
  HTTPS-only, no cloud backup or device transfer of app data
- unit tests (login decoding, session repository, API parsing, navigation)
  and a Compose sign-in screen smoke test
- a GitHub Actions workflow template in `ci/`

Not yet built: match setup and live scoring (M3/M4), offline queue (M5),
settings editing, help/feedback flows and "Want In" registration (M6),
Watch a Match, billing.

Sign-in is tested manually until a staging backend exists, because the dev
build talks to the production API. Use the agreed test accounts (personal,
club user, club admin); never commit their passwords.

## Requirements

- Android Studio compatible with Android Gradle Plugin 9.4
- JDK 17 or newer (Android Studio's bundled JDK is fine)
- Android SDK Platform 37
- Gradle 9.6 (provided through the wrapper)
- Devices: Android 8.0 (API 26) or newer

## Build Variants

| Variant | Application ID | API address |
| --- | --- | --- |
| `devDebug` (default) | `com.hitnscore.mobile.dev.debug` | `HITNSCORE_API_BASE_URL_DEV`, else production (as iOS dev builds do) |
| `stagingDebug` | `com.hitnscore.mobile.staging.debug` | `HITNSCORE_API_BASE_URL_STAGING`, else not configured |
| `prodRelease` | `com.hitnscore.mobile` | `HITNSCORE_API_BASE_URL_PROD`, else production |

The variants install side by side. Choose one in Android Studio with
**Build → Select Build Variant…**.

`com.hitnscore.mobile` is the confirmed Play application ID. It can never
change once the app is uploaded.

## Configuration

Put local settings in `~/.gradle/gradle.properties`, never in this repository:

```properties
# Optional: point a flavour at another backend
HITNSCORE_API_BASE_URL_STAGING=https://staging-api.example.com
# Optional: legacy organisation chooser
HITNSCORE_IDENTITY_FIRST_LOGIN_ENABLED=true
```

CI passes `-PHITNSCORE_VERSION_CODE=<run number>` and, for releases,
`-PHITNSCORE_VERSION_NAME=<x.y.z>`.

## Open And Build

1. Open `mobile/android/` in Android Studio and let Gradle sync.
2. **Build → Assemble Project** builds the selected variant.
3. Pick an emulator or device and press **Run**.

Command line, from `mobile/android/`:

```bash
./gradlew assembleDevDebug          # debug APK
./gradlew testDevDebugUnitTest      # unit tests
./gradlew connectedDevDebugAndroidTest   # Compose smoke test, needs a device
./gradlew bundleProdRelease         # Play bundle (signed if keystore.properties exists)
```

## Release Signing

Use Play App Signing. Google holds the app signing key; we hold only an upload
key. For a local signed build, create `mobile/android/keystore.properties`
(git-ignored):

```properties
storeFile=upload.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

Never commit keystores or passwords. In CI they come from repository secrets
(see `ci/android-ci.yml`).

## Continuous Integration

`ci/android-ci.yml` runs lint, unit tests and a debug build on every change to
`mobile/android/`, and uploads the APK and reports. A repository owner enables
it by copying it to `.github/workflows/android-ci.yml`.

## Project Shape

```text
mobile/android/
  app/src/main/java/com/hitnscore/mobile/
    HitNScoreApplication.kt   owns the AppContainer
    MainActivity.kt           splash + Compose entry point
    app/                      AppContainer, AppViewModel, root composable, navigation
    core/config/              build environment
    core/designsystem/        colours, type scale, theme
    core/auth/                login models, auth service, encrypted session store
    core/connectivity/        online / offline monitor
    core/designsystem/components/  shared cards, empty / offline / error states
    data/model/               dashboard, match, notification, organisation models
    data/remote/              read-only API service
    core/network/             API envelope, client, errors, auth header
    core/session/             session state, repository, context switcher
    feature/auth/             sign-in, lock screen, biometric prompt
    feature/home/             Home tab
    feature/matches/          Matches tab, history filters, match view, timeline
    feature/notifications/    notification inbox
    feature/analytics/        Analytics tab
    feature/settings/         Settings tab and pages, quick unlock
    feature/help/             Need Help tab (placeholder until M6)
    feature/shell/            signed-in shell, header, shared shell state
  app/src/test/               JVM unit tests
  app/src/androidTest/        Compose UI tests
  ci/                         CI workflow template
  play-store/                 Play listing assets (512 px icon)
  gradle/                     version catalog and wrapper
```

Dependencies are wired by hand in `AppContainer`, mirroring iOS
`AppContainer.swift`. Add Room, DataStore, WorkManager and billing
only when their first feature is implemented.
