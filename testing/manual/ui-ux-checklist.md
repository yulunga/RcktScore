# UI / UX Manual Testing Checklist

**Naming:** HitnScore is the customer-facing application. `RcktScore` is the internal project and repository code name.

Use this checklist after UI changes and before releases.

## Authentication

- Open `/login`
- Confirm username and password fields are clear
- Confirm sign-in error messages are understandable
- Confirm help and reset-password paths are easy to find

## Central profile image

- Upload JPEG, PNG and WebP source images from web, iOS and Android; each must be no larger than 5 MB and at least 256 × 256 pixels
- Confirm the saved photograph is square, correctly oriented and visibly compressed without looking blurred
- Sign in on the other two clients and confirm the same image appears from the central profile
- Attempt an oversized, undersized and unsupported file and confirm the existing image remains unchanged
- Replace the image and confirm the previous version disappears across clients; then remove it and confirm initials return everywhere
- Inspect the Club and public surfaces and confirm the photograph is not exposed where the user has not explicitly been told it will appear

## Navigation

- Open `/dashboard`, `/matches`, `/history`, `/settings`, and `/display`
- Confirm the user can always tell where they are
- Confirm important actions are visible without hunting

## Match flow

- Create a match
- In a club context on web and iOS, select Referee → Me and confirm the signed-in profile name is filled; then enter that same person as any singles/doubles player and confirm Me clears and becomes unavailable
- Start the match
- Score several points
- Use undo
- End the match
- Confirm the history/result feels correct to a real scorer

## Club match scorer lock

- On web, iOS and Android, sign in as club Scorer A, start a club match and confirm normal scoring, timer, settings, Undo and end actions work
- Open the same match as club Scorer B and confirm the score remains visible but point, timer, settings, Undo and end controls cannot mutate it
- Attempt a direct scoring request as Scorer B and confirm the backend returns `409 MATCH_SCORER_LOCKED`; confirm a stale or older client also cannot bypass the lock
- Sign in as a club admin, open the match and confirm scoring remains disabled until Take Over Scoring is explicitly selected and confirmed
- Complete the takeover, confirm the admin can score immediately, and confirm Scorer A becomes read-only on its next refresh or rejected mutation
- Confirm an ordinary scorer never sees a takeover action and cannot call the takeover endpoint successfully
- Create a scheduled club match, activate it as Scorer A and repeat the ownership checks; also confirm Personal Free and Personal Plus matches remain unaffected
- Test an active club match created before migration 060 and confirm the first authorised post-deployment mutation claims it once without duplicate audit rows
- On iOS and Android, open a match while online, then lose connectivity; confirm a non-owner device cannot queue new local points after it has received the locked state and that server reconciliation rejects any stale queued mutation

## Club admin flow

- Check court management
- Check user management
- Confirm admin-only actions are visible only to the right user

## Analytics and reporting

- On web and native iOS, confirm Analytics uses Personal and Club sections with the same 7-day, 30-day, 90-day, 12-month and All-time reporting periods
- Confirm Personal Free shows limited app-usage and match-setup analytics without an export action
- Confirm Personal Plus adds game/player analytics and can prepare and share or download a CSV report
- In a club context, confirm Admin, Scorer and Read only members can see aggregate Club analytics regardless of club tier
- Confirm the Club CSV contains court and match-use aggregates but no player names, member names, usernames, email addresses or member directory data
- Start and abandon one setup, then complete another on both web and iOS; confirm the setup figures update without blocking match creation if analytics recording fails

## Scoreboard QR pairing

- Open `/scoreboard`; confirm Scan QR is selected, a QR and expiry countdown appear, and Enter Code remains available
- As a club admin on iOS, open Club Settings → Courts, tap Scan Scoreboard QR beside the intended court, scan it, and confirm the scoreboard opens that court automatically
- Repeat on Android and confirm the Google scanner completes pairing without requesting direct app camera permission
- Confirm scorer and read-only memberships cannot pair a court
- Confirm an admin cannot pair a court belonging to another club
- Let a QR expire, confirm it does not pair, refresh it, and confirm the replacement works
- Confirm an already-used QR cannot create a second display session
- Deny iOS camera permission and confirm the app gives an actionable Settings message
- Enter the permanent 12-character display code and confirm the fallback still works
- Start, score, end and replace a court match; confirm the paired display continues polling the selected court throughout

## Responsive checks

- iPhone portrait
- iPhone landscape
- Android portrait
- iPad landscape
- Desktop Chrome

For each device:

- No horizontal scroll unless intentionally designed
- Buttons remain tappable
- Text does not overlap
- Tables and cards stay readable

## Accessibility quick pass

- Keyboard navigation works
- Focus state is visible
- Color contrast is readable
- Labels and headings are descriptive

## Release notes

- What changed:
- What was tested:
- What passed:
- What failed:
- Follow-up actions:

