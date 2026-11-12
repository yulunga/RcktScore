# HitnScore Scoreboard — Android TV / Google TV app

A separate app from the phone/tablet app (`mobile/android`). It turns a Google TV
stick (Chromecast with Google TV, Google TV Streamer, any Android TV box or TV) into a
court scoreboard for clubs.

| | Phone/tablet app | TV scoreboard app |
|---|---|---|
| Folder | `mobile/android` | `mobile/android-tv-scoreboard` |
| Application ID | `com.hitnscore.mobile` | `com.hitnscore.tvscoreboard` |
| Play listing | HitnScore | HitnScore Scoreboard (TV only) |

## What it does

It shows the existing web scoreboard (`https://app.hitnscore.com/scoreboard`) full screen,
exactly as it works in a browser today: pair the screen by QR code from a club admin's
app, or type the court's 12-character display code with the TV remote. Layouts, live
scores and pairing all come from the web page, so scoreboard changes on the web appear
on TVs without an app update.

On top of the web page the app:

- appears in the Google TV launcher with its own banner, opens straight to the scoreboard
- keeps the screen awake (no dimming or screensaver)
- updates every second while a match is being scored (every 5 s when the court is idle)
- hides the web page's Refresh button (updates are automatic)
- compact header (smaller logo, name, buttons and Layout menu) with no top border line
- Layout menu names swapped on the TV: "Large Scores" (web value `large-scores`) shows as
  **Standard Scores**, "Standard" (`standard`) shows as **Large Scores**
- Standard Scores layout: small court name at the very top of the score card with the match
  details on the same line, bigger score numbers
- player names always on one line, shrunk to fit the card
- no point timeline between the two players' scores; in All Games, no "Playing" game row
  under the main score
- All Games layout: the court's own match keeps the main area; other courts are a narrow
  column of small cards on the right (about a fifth of the width), never over the score; the cards
  shrink as more courts are scored, and from five courts they use two columns
- fits the page to the screen with no scrolling: `assets/tv_scoreboard.js` scales the page
  down until it fits (never above 100%) and re-fits when the page changes (pairing → live
  scoreboard); the TV's font-size setting is ignored so the layout matches the web
- remembers the pairing after restarts and power cuts (web storage is kept)
- shows a "Can't reach HitnScore" screen and retries every 15 s, and reloads as soon as the
  network comes back
- restarts the page by itself if it crashes or the TV reclaims memory
- only loads `hitnscore.com` pages over HTTPS; other links are ignored
- Back goes back within the page; at the start, press Back twice to close

There is no sign-in and no account data in the app.

## Build and run

Open this folder (`mobile/android-tv-scoreboard`) in Android Studio as its own project.

- Emulator: Device Manager › Create device › **Television** (or Google TV) › 1080p, then Run.
- Real stick: on the stick, Settings › System › About › tap **Android TV OS build** 7 times,
  then Developer options › **USB/Network debugging** on. From the computer:
  `adb connect <stick-ip>:5555`, accept the prompt on the TV, then Run in Android Studio.
- Or build an APK (Build › Build APK(s)) and install with `adb install app-debug.apk`.

Debug builds install as `com.hitnscore.tvscoreboard.debug`, alongside a Play install.

Point it at another scoreboard address (e.g. staging):
`./gradlew assembleDebug -PHITNSCORE_SCOREBOARD_URL=https://staging.hitnscore.com/scoreboard`

## Publishing to Google Play (TV)

1. Create a **new app** in Play Console (it can't share the phone app's listing because it
   has its own application ID).
2. Release bundle: `./gradlew bundleRelease` with `keystore.properties` (same format as the
   phone app; can use the same upload key).
3. Store listing: add **Android TV** screenshots (1920×1080) and the TV banner
   (1280×720 promo graphic). Under Advanced settings › Form factors, add **Android TV**.
4. Google reviews TV apps against the TV quality guidelines (D-pad navigation, no touch
   needed, banner present, landscape). The app declares `android.software.leanback`
   (required), so Play only offers it to TV devices.
5. Clubs then search "HitnScore Scoreboard" in the Google TV Play Store on the stick.

## Code

- `app/src/main/java/com/hitnscore/tvscoreboard/ScoreboardActivity.kt`: the whole app
  (full-screen WebView, offline/retry screen, crash recovery, Back handling).
- `app/src/main/AndroidManifest.xml`: leanback launcher entry, banner, landscape, no touch.
- `app/src/main/res/drawable/tv_banner.xml`: launcher banner (brand gradient + mascot).

Note: the TV changes are applied by `assets/tv_scoreboard.js`, injected into the web page.
They depend on the web scoreboard's current markup (class names in
`frontend/src/pages/DisplayScreen.jsx`); if that page is redesigned, re-check them. Moving
them into the web scoreboard itself would be the long-term fix.
