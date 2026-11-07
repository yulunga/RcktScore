# Android Workspace

**Naming:** HitnScore is the customer-facing application. `RcktScore` is the internal project and repository code name.

Native Android app for HitNScore. It is a separate Gradle project beside
`mobile/ios/`; it does not alter or wrap the iOS workspace.

## Current Status (M5 offline scoring, registration, settings editing and password links, November 2026)

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
- **Start New Match** button on Home and Matches, sport picker with the iOS
  ball artwork for squash, racketball, tennis and Padel
- **match setup** for squash and racketball: player and referee look-ups,
  court (busy court schedules the match), shirt colours, handicap bands and
  offsets, Golden Point, timed warm-up and game breaks, scheduling
- **live scorer**: warm-up, first server, tap a player panel to score, swipe
  down to undo (with confirmation), point rail, serve-side changes, stroke and
  let, undo, end early, game breaks, in-match Game Settings, start scheduled
  matches, completion card; the clock survives leaving the app
- **tennis and Padel**: singles or doubles setup (Padel is always doubles),
  Golden Point, final-set 10-point tiebreak, timed breaks; scorer with point
  labels (15/30/40/Ad, tiebreak counts), games and sets, opening server and
  receiver, serving/receiving line, point timeline with game dividers, Padel
  Golden Point receiver choice, 5-minute warm-up, 90 s changeovers and 120 s
  set breaks
- **offline scoring (M5)**: every scoring action (points, strokes, lets,
  serve side, first server, Golden Point receiver, undo, settings, end early)
  is queued on the phone with its projected score and shown at once, then sent
  to the backend in order with its own `client_action_id`. Offline, the queue
  waits (it survives the app closing) and is sent when the connection returns,
  even if the scorer is closed. Squash/racketball and tennis/Padel rules are
  ported from the iOS reducers; the server's response stays authoritative.
  Up to five recent matches are held, Home shows **Continue offline** when
  there is no connection, and a refused action offers Retry or Discard.
  Opening a match for the first time and starting a scheduled match need a
  connection; undo of an already-sent action needs a connection, as iOS
- **Want In** on the sign-in screen: create a free Personal account (the
  server emails a link to verify the address and set a password) or send a
  club enquiry, with the iOS human check
- **settings editing (M6, first part)**: Profile (name, email, phone, city,
  country; an email change signs out every device), password-reset email,
  Personal account deletion (two-step confirmation), Game Settings (Personal
  sport access and per-sport timer defaults), and for club admins:
  Organisation profile and location, Racket Sports access, Users (invite by
  email, edit name/email/role, send reset email, remove; no password field,
  as required by B17) and Courts (add, edit, remove, sport per court, new
  scoreboard display code)
- **password set-up and reset in the app**: the emailed link
  (`https://app.hitnscore.com/help?mode=reset&token=…`, or
  `mode=confirm-email&token=setup_…` for a new account) opens a Set password
  screen that checks the link, shows the password rules as you type (8+
  characters, uppercase, number, symbol, no common words, as the backend), and
  saves it. A reset signs every device out, including this one. If the email
  opened in a browser, paste the link under Need Help? → "I already have a
  link". Website Help links without a token are handed back to the browser.
  See [Password Links](#password-links)
- club roles `admin`, `scorer` and `read_only`: read-only members get no Start
  button and open matches in the read-only match view (B18)
- ongoing "match in progress" notification, screen kept on, phones held in
  portrait, haptics on points and games
- API layer: `{ success, data, error, meta }` envelope, bearer-token
  interceptor, typed errors, OkHttp + kotlinx.serialization
- release hardening: R8, optional upload-key signing, CI version codes,
  HTTPS-only, no cloud backup or device transfer of app data
- unit tests (login decoding, session repository, API parsing, navigation,
  match clock, squash point rail, tennis/Padel rules, offline reducers and
  queue, registration, password links and rules, set-password screen) and Compose sign-in and Want In smoke tests
- a GitHub Actions workflow template in `ci/`

Not yet built: scorer Match Details (scoreboard URL and codes), Help &
Feedback and Watch a Match (M6b), crash reporting and release hardening (M7),
Google Play Billing and passkeys (v1.1).

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

## Password Links

The app claims `https://app.hitnscore.com/help` as an Android App Link, so a
tap on the reset or set-up link in the email opens the app. Android only
trusts that claim once the website publishes
`https://app.hitnscore.com/.well-known/assetlinks.json` listing this app's
signing certificates. Until then, the link opens in the browser and the web
page works as before; the paste-a-link fallback works in every case.

Publishing that file is a website change, outside `mobile/android/`. The
template is `play-store/assetlinks.json.template`:

1. Fill in the SHA-256 fingerprints: the **app signing key** from Play
   Console → Test and release → App integrity (required for Play installs),
   and for local testing the debug key from `./gradlew signingReport`.
2. Add one entry per installed package name you want links to open:
   `com.hitnscore.mobile` (prod), and optionally `.dev.debug` /
   `.staging.debug` builds.
3. Serve it at the address above as `application/json`, over HTTPS, with no
   redirect.

Check: `adb shell pm verify-app-links --re-verify com.hitnscore.mobile`, then
`adb shell pm get-app-links com.hitnscore.mobile` should show
`app.hitnscore.com: verified`. To test the screen without verification:

```bash
adb shell am start -a android.intent.action.VIEW \
  -d "https://app.hitnscore.com/help?mode=reset\&token=TOKEN" com.hitnscore.mobile.dev.debug
```

A real token comes from Need Help? on the sign-in screen (it is single-use and
expires). A made-up token shows "This link can't be used".

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
    feature/newmatch/         sport picker, match setup, handicap table
    feature/scoring/          live scorer, clock, point rail, notification
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
