# Android Workspace

Native Android app for HitNScore. It is a separate Gradle project beside
`mobile/ios/`; it does not alter or wrap the iOS workspace.

## Current Status (M0 foundation, October 2026)

In place:

- one Android application module: Kotlin, Jetpack Compose, Material 3
- `dev`, `staging` and `prod` build flavours, each with its own API address,
  app name and application ID suffix
- brand splash screen (held until the stored session is read), adaptive and
  themed (monochrome) launcher icon made from the iOS brand artwork
- auth-gated app root, like iOS `ContentView`: splash, sign-in placeholder, or
  the signed-in shell
- one `Scaffold` and bottom bar for the whole signed-in session, with the five
  iOS tabs (Home, Matches, Analytics, Settings, Need Help) and Material icons
- account-context switcher backed by a `SessionRepository` `StateFlow`
- API layer for the v2 backend: `{ success, data, error, meta }` envelope,
  bearer-token interceptor, typed errors (including the iOS session-invalidation
  codes), OkHttp + kotlinx.serialization
- HitNScore colour tokens and type scale, including tabular score numerals
- release hardening: R8 shrinking, optional upload-key signing, CI-supplied
  version codes, HTTPS-only network security config, no cloud backup or
  device transfer of app data
- unit tests (navigation, API parsing, session state) and a Compose smoke test
- a GitHub Actions workflow template in `ci/`

Not yet built: real sign-in, persistence, dashboard data, scoring, offline
queue, settings, billing. See the milestone plan in the Android review doc and
`docs/mobile/android-parity-plan.md`.

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
    core/network/             API envelope, client, errors, auth header
    core/session/             session state, repository, context switcher
    feature/auth/             sign-in (placeholder until M1)
    feature/shell/            signed-in shell and tab placeholders
  app/src/test/               JVM unit tests
  app/src/androidTest/        Compose UI tests
  ci/                         CI workflow template
  play-store/                 Play listing assets (512 px icon)
  gradle/                     version catalog and wrapper
```

Dependencies are wired by hand in `AppContainer`, mirroring iOS
`AppContainer.swift`. Add Room, DataStore, WorkManager, biometrics and billing
only when their first feature is implemented.
