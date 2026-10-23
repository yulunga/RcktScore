# Android Workspace

This directory contains the native Android foundation for HitNScore. It is a
separate Gradle project beside `mobile/ios/`; it does not alter or wrap the iOS
workspace.

## Current Status

The checked-in foundation provides:

- one Android application module
- Kotlin with Jetpack Compose and Material 3
- a single-activity navigation shell
- the same five top-level destinations as iOS: Home, Matches, Analytics,
  Settings, and Need Help
- shared light/dark brand colours
- build-time API environment configuration
- unit-test and Compose UI smoke-test source sets

It does **not** yet contain production authentication, API calls, persistence,
scoring, billing, or completed feature screens.

## Requirements

- Android Studio compatible with Android Gradle Plugin 9.4
- JDK 17
- Android SDK Platform 37
- Gradle 9.6 (provided through the wrapper)

This machine did not have Android Studio, a JDK, or an Android SDK available
when the foundation was created, so the first Gradle sync and build must be run
after those prerequisites are installed.

## Open And Build

1. Open `mobile/android/` in Android Studio.
2. Let Android Studio use its bundled JDK 17 and install SDK Platform 37 if
   prompted.
3. Configure a non-secret backend URL for a local build:

   ```bash
   ./gradlew assembleDebug \
     -PHITNSCORE_API_BASE_URL=https://your-api.example.com
   ```

4. Run unit tests:

   ```bash
   ./gradlew testDebugUnitTest
   ```

5. With an emulator or device connected, run the navigation smoke test:

   ```bash
   ./gradlew connectedDebugAndroidTest
   ```

If the API property is omitted, the app uses `https://example.invalid` and
clearly reports that its environment is not configured.

Do not store credentials or signing material in Gradle files. `local.properties`,
keystores, and `keystore.properties` are ignored by Git.

## Project Shape

```text
mobile/android/
  app/
    src/main/java/com/hitnscore/mobile/
      app/                  app root and navigation
      core/config/          environment configuration
      core/designsystem/    Compose theme
      feature/auth/         authentication entry point
      feature/shell/        signed-in navigation shell
    src/test/               local unit tests
  gradle/                   version catalog and wrapper configuration
```

Add repositories, API models, Room storage, security, billing, and individual
feature packages only when their first behaviour is implemented. The staged
roadmap is in `docs/mobile/android-parity-plan.md`.

## Provisional Identifiers

The namespace and application ID are currently `com.hitnscore.mobile`; debug
builds add `.debug`. Confirm the final Play Console application ID before the
first external release because a published application ID cannot be changed.
